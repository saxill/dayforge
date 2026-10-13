// Dayforge sync API: email/password accounts, one JSON document per user, and two-player motivation pairing, stored in Workers KV.
//   POST /auth/register {email, password, name}  -> {token, user}
//   POST /auth/login    {email, password}        -> {token, user}
//   POST /auth/logout                            -> {ok}
//   GET  /data                                   -> {data, updatedAt}
//   PUT  /data          {data}                   -> {updatedAt}
//   POST /pair/invite                            -> {pair, summary}
//   POST /pair/join      {code}                  -> {pair, summary}
//   GET  /pair                                   -> {pair, summary, summaries, latestNudge}
//   PUT  /pair/motivation {motivation fields, optional history} -> {ok}
//   POST /pair/nudge     {message}               -> {ok}
//   POST /pair/leave                             -> {ok}
//   DELETE /account                              -> {ok}
// Every route except register/login needs "Authorization: Bearer <token>".

const SESSION_TTL = 60 * 60 * 24 * 90; // 90 days
const INVITE_TTL = 60 * 60 * 24 * 7; // 7 days
const INVITE_TTL_MS = INVITE_TTL * 1000;
const NUDGE_INTERVAL_MS = 60 * 1000;
const CODE_LENGTH = 6;
// Avoid characters that are easy to confuse when read aloud or typed.
const CODE_ALPHABET = "ACDEFGHJKMNPQRTUVWXYZ23479";
const MAX_BODY = 5 * 1024 * 1024;
const ITERATIONS = 100000;

const json = (body, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "access-control-allow-origin": "*" },
  });

const b64 = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes)));
const unb64 = (text) => Uint8Array.from(atob(text), (c) => c.charCodeAt(0));

async function hash(password, salt) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt, iterations: ITERATIONS }, key, 256);
  return b64(bits);
}

function sameText(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const normalise = (email) => String(email || "").trim().toLowerCase();
const validEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;

async function readJSON(request) {
  const text = await request.text();
  if (text.length > MAX_BODY) throw new HttpError(413, "That is too large to store.");
  try {
    return JSON.parse(text || "{}");
  } catch {
    throw new HttpError(400, "That request was not valid JSON.");
  }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

async function startSession(env, user) {
  const token = b64(crypto.getRandomValues(new Uint8Array(32))).replace(/[+/=]/g, "");
  await env.DAYFORGE.put(`sess:${token}`, user.id, { expirationTtl: SESSION_TTL });
  return { token, user: { email: user.email, name: user.name } };
}

async function authed(request, env) {
  const header = request.headers.get("authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) throw new HttpError(401, "Please sign in.");
  const id = await env.DAYFORGE.get(`sess:${token}`);
  if (!id) throw new HttpError(401, "Your session expired. Please sign in again.");
  return { id, token };
}

function parseStored(value) {
  if (!value) return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

async function userProfile(env, id) {
  const indexed = parseStored(await env.DAYFORGE.get(`user:profile:${id}`));
  if (indexed && indexed.id === id) return { id, name: String(indexed.name || "").slice(0, 40) };

  // Profiles are indexed for new accounts. The list fallback lets pairing also
  // work for accounts created before that index existed.
  if (typeof env.DAYFORGE.list === "function") {
    let cursor;
    do {
      const page = await env.DAYFORGE.list({ prefix: "user:", ...(cursor ? { cursor } : {}) });
      for (const key of page.keys || []) {
        if (key.name.startsWith("user:profile:")) continue;
        const user = parseStored(await env.DAYFORGE.get(key.name));
        if (user && user.id === id) return { id, name: String(user.name || "").slice(0, 40) };
      }
      if (page.list_complete) break;
      cursor = page.cursor;
    } while (cursor);
  }

  return { id, name: "" };
}

async function getPair(env, pairId) {
  return parseStored(await env.DAYFORGE.get(`pair:${pairId}`));
}

async function getMembership(env, userId) {
  return env.DAYFORGE.get(`pair:user:${userId}`);
}

function pairParticipant(pair, userId) {
  if (pair.ownerUserId === userId) return { userId, name: pair.ownerName || "" };
  if (pair.partnerUserId === userId) return { userId, name: pair.partnerName || "" };
  return null;
}

function otherParticipant(pair, userId) {
  if (pair.ownerUserId === userId && pair.partnerUserId) {
    return { userId: pair.partnerUserId, name: pair.partnerName || "" };
  }
  if (pair.partnerUserId === userId) {
    return { userId: pair.ownerUserId, name: pair.ownerName || "" };
  }
  return null;
}

function pairPayload(pair, userId) {
  const partner = otherParticipant(pair, userId);
  return {
    id: pair.id,
    status: pair.status,
    code: pair.status === "waiting" ? pair.code : null,
    partnerName: partner ? partner.name : null,
    partnerUserId: partner ? partner.userId : null,
    createdAt: pair.createdAt,
  };
}

function emptySummary(userId, name) {
  return {
    userId,
    name,
    pulse: 0,
    habitsDone: 0,
    habitsTotal: 0,
    focusMinutes: 0,
    focusStreakDays: 0,
    checkedInDate: null,
    updatedAt: 0,
    history: [],
  };
}

function validDateString(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function historyInput(raw) {
  if (!Array.isArray(raw)) throw new HttpError(400, "history must be an array.");

  const byDate = new Map();
  for (const entry of raw) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw new HttpError(400, "Each history entry must be an object.");
    }
    if (!validDateString(entry.date)) throw new HttpError(400, "history dates must be valid YYYY-MM-DD dates.");

    const pulse = requiredNumber(entry, "pulse", 0, 100);
    const habitsDone = requiredNumber(entry, "habitsDone", 0, 1000);
    const habitsTotal = requiredNumber(entry, "habitsTotal", 0, 1000);
    if (habitsDone > habitsTotal) throw new HttpError(400, "history habitsDone cannot exceed habitsTotal.");
    const focusMinutes = requiredNumber(entry, "focusMinutes", 0, 24 * 60);
    const focusStreakDays = requiredNumber(entry, "focusStreakDays", 0, 10000);

    // Repeated dates use the last supplied entry. Only the allowlisted fields
    // are copied so private habit metadata can never enter pairing storage.
    byDate.set(entry.date, {
      date: entry.date,
      pulse,
      habitsDone,
      habitsTotal,
      focusMinutes,
      focusStreakDays,
    });
  }

  return [...byDate.values()].sort((a, b) => a.date.localeCompare(b.date)).slice(-30);
}

function storedHistory(raw) {
  if (!Array.isArray(raw)) return [];
  try {
    return historyInput(raw);
  } catch {
    return [];
  }
}

async function motivationSummary(env, pairId, userId, name) {
  const data = parseStored(await env.DAYFORGE.get(`pair:motivation:${pairId}:${userId}`));
  if (!data) return emptySummary(userId, name);
  return {
    userId,
    name,
    pulse: data.pulse,
    habitsDone: data.habitsDone,
    habitsTotal: data.habitsTotal,
    focusMinutes: data.focusMinutes,
    focusStreakDays: data.focusStreakDays,
    checkedInDate: data.checkedInDate,
    updatedAt: data.updatedAt,
    history: storedHistory(data.history),
  };
}

async function latestNudge(env, pairId) {
  const nudge = parseStored(await env.DAYFORGE.get(`pair:nudge:${pairId}`));
  if (!nudge) return null;
  return { fromName: nudge.fromName, message: nudge.message, createdAt: nudge.createdAt };
}

async function pairResponse(env, pair, userId, name, includeNudge = false, includeSummaries = false) {
  const summary = await motivationSummary(env, pair.id, userId, name);
  const partner = pair.status === "connected" ? otherParticipant(pair, userId) : null;
  const response = {
    pair: pairPayload(pair, userId),
    summary,
  };
  if (includeSummaries) response.summaries = partner ? [await motivationSummary(env, pair.id, partner.userId, partner.name)] : [];
  if (includeNudge) response.latestNudge = await latestNudge(env, pair.id);
  return response;
}

function validCode(code) {
  return code.length === CODE_LENGTH && [...code].every((character) => CODE_ALPHABET.includes(character));
}

function newInviteCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return [...bytes].map((byte) => CODE_ALPHABET[byte % CODE_ALPHABET.length]).join("");
}

async function uniqueInviteCode(env) {
  for (let attempt = 0; attempt < 10; attempt++) {
    const code = newInviteCode();
    if (!(await env.DAYFORGE.get(`pair:invite:${code}`))) return code;
  }
  throw new HttpError(503, "Could not create an invite right now. Please try again.");
}

async function cleanupPair(env, pair) {
  const keys = new Set([
    `pair:${pair.id}`,
    `pair:nudge:${pair.id}`,
  ]);
  if (pair.code) keys.add(`pair:invite:${pair.code}`);

  const participantIds = [pair.ownerUserId, pair.partnerUserId].filter(Boolean);
  for (const userId of participantIds) {
    keys.add(`pair:motivation:${pair.id}:${userId}`);
    if (await getMembership(env, userId) === pair.id) keys.add(`pair:user:${userId}`);
  }
  await Promise.all([...keys].map((key) => env.DAYFORGE.delete(key)));
}

async function activePairForUser(env, userId) {
  const membership = await getMembership(env, userId);
  if (!membership) return null;
  const pair = await getPair(env, membership);
  if (!pair || !pairParticipant(pair, userId)) {
    if (!pair) await env.DAYFORGE.delete(`pair:user:${userId}`);
    return null;
  }
  if (pair.status === "waiting" && Date.now() - pair.createdAt >= INVITE_TTL_MS) {
    await cleanupPair(env, pair);
    return null;
  }
  return pair;
}

function requiredNumber(body, key, minimum, maximum) {
  const value = body[key];
  if (typeof value !== "number" || !Number.isFinite(value) || !Number.isInteger(value)) {
    throw new HttpError(400, `${key} must be a whole number.`);
  }
  if (value < minimum || value > maximum) {
    throw new HttpError(400, `${key} must be between ${minimum} and ${maximum}.`);
  }
  return value;
}

function motivationInput(body) {
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new HttpError(400, "Motivation data is required.");

  const rawPulse = body.pulse;
  if (typeof rawPulse !== "number" || !Number.isFinite(rawPulse)) throw new HttpError(400, "pulse must be a number.");
  if (Math.abs(rawPulse) > 1000) throw new HttpError(400, "pulse is unreasonable.");
  const pulse = Math.max(0, Math.min(100, Math.round(rawPulse)));
  const habitsDone = requiredNumber(body, "habitsDone", 0, 1000);
  const habitsTotal = requiredNumber(body, "habitsTotal", 0, 1000);
  if (habitsDone > habitsTotal) throw new HttpError(400, "habitsDone cannot exceed habitsTotal.");
  const focusMinutes = requiredNumber(body, "focusMinutes", 0, 24 * 60);
  const focusStreakDays = requiredNumber(body, "focusStreakDays", 0, 10000);

  const checkedInDate = body.checkedInDate;
  if (checkedInDate !== null && typeof checkedInDate !== "string") {
    throw new HttpError(400, "checkedInDate must be a YYYY-MM-DD date or null.");
  }
  if (typeof checkedInDate === "string" && !validDateString(checkedInDate)) {
    throw new HttpError(400, "checkedInDate must be a YYYY-MM-DD date or null.");
  }

  const motivation = { pulse, habitsDone, habitsTotal, focusMinutes, focusStreakDays, checkedInDate };
  if (Object.prototype.hasOwnProperty.call(body, "history")) motivation.history = historyInput(body.history);
  return motivation;
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "access-control-allow-origin": "*",
          "access-control-allow-headers": "authorization, content-type",
          "access-control-allow-methods": "GET, PUT, POST, DELETE",
        },
      });
    }
    const url = new URL(request.url);
    try {
      if (url.pathname === "/" && request.method === "GET") return json({ ok: true, service: "dayforge-sync" });

      if (url.pathname === "/auth/register" && request.method === "POST") {
        const body = await readJSON(request);
        const email = normalise(body.email);
        const password = String(body.password || "");
        if (!validEmail(email)) throw new HttpError(400, "Enter a valid email address.");
        if (password.length < 8) throw new HttpError(400, "Use a password of at least 8 characters.");
        if (await env.DAYFORGE.get(`user:${email}`)) throw new HttpError(409, "An account with that email already exists.");
        const salt = crypto.getRandomValues(new Uint8Array(16));
        const user = {
          id: crypto.randomUUID(),
          email,
          name: String(body.name || "").trim().slice(0, 40),
          salt: b64(salt),
          hash: await hash(password, salt),
          createdAt: Date.now(),
        };
        await env.DAYFORGE.put(`user:${email}`, JSON.stringify(user));
        await env.DAYFORGE.put(`user:profile:${user.id}`, JSON.stringify({ id: user.id, name: user.name }));
        return json(await startSession(env, user), 201);
      }

      if (url.pathname === "/auth/login" && request.method === "POST") {
        const body = await readJSON(request);
        const email = normalise(body.email);
        const stored = await env.DAYFORGE.get(`user:${email}`);
        const user = stored ? JSON.parse(stored) : null;
        // Same work for unknown emails so response time does not reveal which accounts exist.
        const salt = user ? unb64(user.salt) : crypto.getRandomValues(new Uint8Array(16));
        const attempt = await hash(String(body.password || ""), salt);
        if (!user || !sameText(attempt, user.hash)) throw new HttpError(401, "Email or password is wrong.");
        return json(await startSession(env, user));
      }

      if (url.pathname === "/auth/logout" && request.method === "POST") {
        const { token } = await authed(request, env);
        await env.DAYFORGE.delete(`sess:${token}`);
        return json({ ok: true });
      }

      if (url.pathname === "/data" && request.method === "GET") {
        const { id } = await authed(request, env);
        const stored = await env.DAYFORGE.get(`data:${id}`);
        if (!stored) return json({ data: null, updatedAt: 0 });
        const { data, updatedAt } = JSON.parse(stored);
        return json({ data, updatedAt });
      }

      if (url.pathname === "/data" && request.method === "PUT") {
        const { id } = await authed(request, env);
        const body = await readJSON(request);
        if (typeof body.data !== "object" || body.data === null) throw new HttpError(400, "Missing data.");
        const updatedAt = Date.now();
        await env.DAYFORGE.put(`data:${id}`, JSON.stringify({ data: body.data, updatedAt }));
        return json({ updatedAt });
      }

      if (url.pathname === "/pair/invite" && request.method === "POST") {
        const { id } = await authed(request, env);
        const profile = await userProfile(env, id);
        let pair = await activePairForUser(env, id);

        if (!pair) {
          const code = await uniqueInviteCode(env);
          pair = {
            id: crypto.randomUUID(),
            status: "waiting",
            code,
            ownerUserId: id,
            ownerName: profile.name,
            partnerUserId: null,
            partnerName: null,
            createdAt: Date.now(),
          };
          await env.DAYFORGE.put(`pair:${pair.id}`, JSON.stringify(pair), { expirationTtl: INVITE_TTL });
          await env.DAYFORGE.put(`pair:invite:${pair.code}`, pair.id, { expirationTtl: INVITE_TTL });
          await env.DAYFORGE.put(`pair:user:${id}`, pair.id, { expirationTtl: INVITE_TTL });
        } else if (pair.status === "waiting" && await env.DAYFORGE.get(`pair:invite:${pair.code}`) !== pair.id) {
          const code = await uniqueInviteCode(env);
          pair = { ...pair, code, createdAt: Date.now() };
          await env.DAYFORGE.put(`pair:${pair.id}`, JSON.stringify(pair), { expirationTtl: INVITE_TTL });
          await env.DAYFORGE.put(`pair:invite:${pair.code}`, pair.id, { expirationTtl: INVITE_TTL });
          await env.DAYFORGE.put(`pair:user:${id}`, pair.id, { expirationTtl: INVITE_TTL });
        }

        const name = profile.name || pairParticipant(pair, id).name;
        return json(await pairResponse(env, pair, id, name));
      }

      if (url.pathname === "/pair/join" && request.method === "POST") {
        const { id } = await authed(request, env);
        const body = await readJSON(request);
        const code = typeof body.code === "string" ? body.code.trim().toUpperCase() : "";
        if (!validCode(code)) throw new HttpError(400, "Enter a valid invite code.");

        const pairId = await env.DAYFORGE.get(`pair:invite:${code}`);
        if (!pairId) throw new HttpError(404, "That invite code is invalid or expired.");
        const pair = await getPair(env, pairId);
        if (!pair) throw new HttpError(404, "That invite code is invalid or expired.");
        if (pair.status === "connected") throw new HttpError(409, "That pair is already full.");
        if (pair.status !== "waiting") throw new HttpError(409, "That invite is no longer available.");
        if (pair.ownerUserId === id) throw new HttpError(400, "You cannot join your own invite.");
        if (Date.now() - pair.createdAt >= INVITE_TTL_MS) {
          await cleanupPair(env, pair);
          throw new HttpError(410, "That invite has expired.");
        }
        if (await getMembership(env, pair.ownerUserId) !== pair.id) {
          await cleanupPair(env, pair);
          throw new HttpError(410, "That invite is no longer available.");
        }
        if (await activePairForUser(env, id)) throw new HttpError(409, "You are already in a pair.");

        const profile = await userProfile(env, id);
        const connected = {
          ...pair,
          status: "connected",
          partnerUserId: id,
          partnerName: profile.name,
        };
        await env.DAYFORGE.put(`pair:${connected.id}`, JSON.stringify(connected));
        // Remove the invite TTL from both memberships now that the pair is permanent.
        await env.DAYFORGE.put(`pair:user:${connected.ownerUserId}`, connected.id);
        await env.DAYFORGE.put(`pair:user:${id}`, connected.id);
        return json(await pairResponse(env, connected, id, profile.name));
      }

      if (url.pathname === "/pair" && request.method === "GET") {
        const { id } = await authed(request, env);
        const profile = await userProfile(env, id);
        const pair = await activePairForUser(env, id);
        if (!pair) {
          return json({ pair: null, summary: emptySummary(id, profile.name), summaries: [], latestNudge: null });
        }
        const name = profile.name || pairParticipant(pair, id).name;
        return json(await pairResponse(env, pair, id, name, true, true));
      }

      if (url.pathname === "/pair/motivation" && request.method === "PUT") {
        const { id } = await authed(request, env);
        const pair = await activePairForUser(env, id);
        if (!pair) throw new HttpError(409, "Join a pair before updating motivation.");
        const body = await readJSON(request);
        const motivation = motivationInput(body);
        const motivationKey = `pair:motivation:${pair.id}:${id}`;
        const existing = parseStored(await env.DAYFORGE.get(motivationKey));
        const history = Object.prototype.hasOwnProperty.call(motivation, "history")
          ? motivation.history
          : storedHistory(existing && existing.history);
        await env.DAYFORGE.put(
          motivationKey,
          JSON.stringify({ ...motivation, history, updatedAt: Date.now() }),
        );
        return json({ ok: true });
      }

      if (url.pathname === "/pair/nudge" && request.method === "POST") {
        const { id } = await authed(request, env);
        const pair = await activePairForUser(env, id);
        if (!pair || pair.status !== "connected") throw new HttpError(409, "Connect with a partner before sending a nudge.");
        const body = await readJSON(request);
        if (!body || typeof body.message !== "string") throw new HttpError(400, "A nudge message is required.");
        const message = body.message.trim();
        if (!message) throw new HttpError(400, "A nudge message is required.");
        if (message.length > 120) throw new HttpError(400, "Nudge messages must be 120 characters or fewer.");

        const existing = parseStored(await env.DAYFORGE.get(`pair:nudge:${pair.id}`));
        const lastSentAt = existing && existing.sentAtBy ? existing.sentAtBy[id] : null;
        if (typeof lastSentAt === "number" && Date.now() - lastSentAt < NUDGE_INTERVAL_MS) {
          throw new HttpError(429, "You can send one nudge per minute.");
        }
        const partner = otherParticipant(pair, id);
        const sender = pairParticipant(pair, id);
        const sentAtBy = existing && existing.sentAtBy && typeof existing.sentAtBy === "object" ? { ...existing.sentAtBy } : {};
        const createdAt = Date.now();
        sentAtBy[id] = createdAt;
        await env.DAYFORGE.put(`pair:nudge:${pair.id}`, JSON.stringify({
          fromUserId: id,
          toUserId: partner.userId,
          fromName: sender.name,
          message,
          createdAt,
          sentAtBy,
        }));
        return json({ ok: true });
      }

      if (url.pathname === "/pair/leave" && request.method === "POST") {
        const { id } = await authed(request, env);
        const pair = await activePairForUser(env, id);
        if (pair) await cleanupPair(env, pair);
        else await env.DAYFORGE.delete(`pair:user:${id}`);
        return json({ ok: true });
      }

      if (url.pathname === "/account" && request.method === "DELETE") {
        const { id, token } = await authed(request, env);
        const body = await readJSON(request);
        const email = normalise(body.email);
        const stored = await env.DAYFORGE.get(`user:${email}`);
        if (!stored || JSON.parse(stored).id !== id) throw new HttpError(403, "That is not your account.");
        await env.DAYFORGE.delete(`user:${email}`);
        await env.DAYFORGE.delete(`user:profile:${id}`);
        await env.DAYFORGE.delete(`data:${id}`);
        await env.DAYFORGE.delete(`sess:${token}`);
        return json({ ok: true });
      }

      throw new HttpError(404, "Not found.");
    } catch (error) {
      if (error instanceof HttpError) return json({ error: error.message }, error.status);
      return json({ error: "Something went wrong on the server." }, 500);
    }
  },
};
