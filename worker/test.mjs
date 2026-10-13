import worker from "./src/index.js";

const store = new Map();
const env = { DAYFORGE: {
  get: async (k) => store.get(k) ?? null,
  put: async (k, v) => { store.set(k, v); },
  delete: async (k) => { store.delete(k); },
} };
const call = async (method, path, body, token) => {
  const res = await worker.fetch(new Request("https://x.test" + path, {
    method, body: body ? JSON.stringify(body) : undefined,
    headers: token ? { authorization: "Bearer " + token } : {},
  }), env);
  return [res.status, await res.json()];
};
const eq = (label, got, want) => { if (got !== want) { console.error("FAIL", label, got, want); process.exit(1); } console.log("ok  ", label); };
const ok = (label, condition) => { if (!condition) { console.error("FAIL", label); process.exit(1); } console.log("ok  ", label); };

let [s, r] = await call("POST", "/auth/register", { email: "A@b.co", password: "short" }); eq("short password rejected", s, 400);
[s, r] = await call("POST", "/auth/register", { email: "nope", password: "longenough1" }); eq("bad email rejected", s, 400);
[s, r] = await call("POST", "/auth/register", { email: "A@b.co", password: "longenough1", name: "Sam" }); eq("register", s, 201);
const token = r.token;
[s] = await call("POST", "/auth/register", { email: "a@B.co", password: "longenough1" }); eq("duplicate email (case-insensitive)", s, 409);
[s] = await call("POST", "/auth/login", { email: "a@b.co", password: "wrongwrong" }); eq("wrong password", s, 401);
[s] = await call("POST", "/auth/login", { email: "ghost@b.co", password: "longenough1" }); eq("unknown email", s, 401);
[s, r] = await call("POST", "/auth/login", { email: "a@b.co", password: "longenough1" }); eq("login", s, 200); eq("login name", r.user.name, "Sam");
[s] = await call("GET", "/data"); eq("data needs token", s, 401);
[s, r] = await call("GET", "/data", null, token); eq("empty data", r.data, null);
[s, r] = await call("PUT", "/data", { data: { habits: [1, 2] } }, token); eq("put data", s, 200);
[s, r] = await call("GET", "/data", null, token); eq("get data", r.data.habits.length, 2);
[s, r] = await call("GET", "/pair", null, token); eq("empty pair summary has history", r.summary.history.length, 0);
[s] = await call("DELETE", "/account", { email: "someone@else.co" }, token); eq("cannot delete other account", s, 403);
[s, r] = await call("POST", "/auth/register", { email: "b@b.co", password: "longenough2", name: "Alex" }); eq("register second user", s, 201);
const token2 = r.token;
[s, r] = await call("POST", "/pair/invite", {}, token); eq("create pair invite", s, 200);
const inviteCode = r.pair.code;
const pairId = r.pair.id;
ok("invite code is short uppercase", /^[ACDEFGHJKMNPQRTUVWXYZ23479]{6}$/.test(inviteCode));
eq("invite is waiting", r.pair.status, "waiting");
eq("waiting invite has no partner", r.pair.partnerUserId, null);
eq("invite summary belongs to Sam", r.summary.name, "Sam");
[s, r] = await call("GET", "/pair", null, token); eq("get waiting pair", s, 200);
eq("waiting GET has no partner summaries", r.summaries.length, 0);
eq("waiting GET has no nudge", r.latestNudge, null);
[s] = await call("POST", "/pair/join", { code: "BAD" }, token2); eq("invalid invite rejected", s, 400);
[s] = await call("POST", "/pair/join", { code: inviteCode }, token); eq("self invite rejected", s, 400);
[s, r] = await call("POST", "/pair/join", { code: inviteCode }, token2); eq("join pair", s, 200);
eq("joined pair is connected", r.pair.status, "connected");
eq("joined pair partner name", r.pair.partnerName, "Sam");
[s] = await call("POST", "/pair/join", { code: inviteCode }, token); eq("full invite rejected", s, 409);
[s, r] = await call("POST", "/pair/invite", {}, token); eq("connected invite returns current pair", s, 200); eq("connected invite has no join code", r.pair.code, null);
[s, r] = await call("GET", "/pair", null, token); eq("empty partner summary has history", r.summaries[0].history.length, 0);
const history = Array.from({ length: 31 }, (_, index) => ({
  date: `2026-10-${String(index + 1).padStart(2, "0")}`,
  pulse: index,
  habitsDone: index % 5,
  habitsTotal: 5,
  focusMinutes: index,
  focusStreakDays: index,
}));
history.push({
  date: "2026-10-31",
  pulse: 99,
  habitsDone: 4,
  habitsTotal: 4,
  focusMinutes: 1440,
  focusStreakDays: 10000,
  habitName: "Secret habit should not persist",
});
[s, r] = await call("PUT", "/pair/motivation", {
  pulse: 86, habitsDone: 3, habitsTotal: 5, focusMinutes: 42, focusStreakDays: 7, checkedInDate: "2026-10-13",
  history,
}, token); eq("put motivation", s, 200); eq("motivation write acknowledged", r.ok, true);
[s] = await call("PUT", "/pair/motivation", {
  pulse: 86, habitsDone: 3, habitsTotal: 5, focusMinutes: 42, focusStreakDays: 7, checkedInDate: "2026-10-13",
}, token); eq("motivation update without history", s, 200);
[s] = await call("PUT", "/pair/motivation", {
  pulse: 120, habitsDone: 4, habitsTotal: 2, focusMinutes: 10, focusStreakDays: 1, checkedInDate: "2026-10-13",
}, token2); eq("invalid motivation rejected", s, 400);
[s] = await call("PUT", "/pair/motivation", {
  pulse: 72, habitsDone: 2, habitsTotal: 4, focusMinutes: 18, focusStreakDays: 3, checkedInDate: null,
  history: [{ date: "2026-02-30", pulse: 50, habitsDone: 1, habitsTotal: 2, focusMinutes: 10, focusStreakDays: 1 }],
}, token2); eq("invalid history rejected", s, 400);
[s, r] = await call("PUT", "/pair/motivation", {
  pulse: 72, habitsDone: 2, habitsTotal: 4, focusMinutes: 18, focusStreakDays: 3, checkedInDate: null,
  history: [{
    date: "2026-10-12", pulse: 72, habitsDone: 2, habitsTotal: 4, focusMinutes: 18, focusStreakDays: 3,
    habitName: "Private habit name", habitId: "private-id", notes: "private note",
  }],
}, token2); eq("put partner motivation", s, 200);
[s, r] = await call("GET", "/pair", null, token); eq("get connected pair", s, 200);
eq("motivation pulse round trips", r.summary.pulse, 86);
eq("motivation habits round trip", r.summary.habitsDone, 3);
eq("history is capped at 30 entries", r.summary.history.length, 30);
eq("history is sorted oldest first", r.summary.history[0].date, "2026-10-02");
eq("history keeps latest date", r.summary.history[29].date, "2026-10-31");
eq("duplicate date keeps latest entry", r.summary.history[29].pulse, 99);
eq("partner summary is returned", r.summaries.length, 1);
eq("partner motivation round trips", r.summaries[0].focusMinutes, 18);
eq("partner history round trips", r.summaries[0].history[0].date, "2026-10-12");
eq("partner history fields are allowlisted", Object.keys(r.summaries[0].history[0]).sort().join(","), "date,focusMinutes,focusStreakDays,habitsDone,habitsTotal,pulse");
ok("partner summary has no habit-name fields", !JSON.stringify(r.summaries[0]).includes("Private habit name"));
ok("private habit data is not persisted", !String(store.get(`pair:motivation:${pairId}:${r.summaries[0].userId}`)).includes("Private habit name"));
[s, r] = await call("POST", "/pair/nudge", { message: "You have got this!" }, token); eq("send nudge", s, 200); eq("nudge acknowledged", r.ok, true);
[s, r] = await call("GET", "/pair", null, token); eq("sender sees latest nudge", r.latestNudge.message, "You have got this!");
[s, r] = await call("GET", "/pair", null, token2); eq("partner gets nudge", s, 200);
eq("nudge sender name", r.latestNudge.fromName, "Sam");
eq("nudge message", r.latestNudge.message, "You have got this!");
[s] = await call("POST", "/pair/nudge", { message: "Again" }, token); eq("nudge rate limit", s, 429);
[s, r] = await call("POST", "/pair/leave", null, token2); eq("leave pair", s, 200); eq("leave acknowledged", r.ok, true);
ok("pair record cleaned on leave", !store.has(`pair:${pairId}`));
ok("invite record cleaned on leave", !store.has(`pair:invite:${inviteCode}`));
ok("motivation records cleaned on leave", ![...store.keys()].some((key) => key.startsWith(`pair:motivation:${pairId}:`)));
ok("nudge record cleaned on leave", !store.has(`pair:nudge:${pairId}`));
[s, r] = await call("GET", "/pair", null, token); eq("owner is unpaired after leave", r.pair, null); eq("owner has no partner summaries", r.summaries.length, 0);
[s, r] = await call("GET", "/pair", null, token2); eq("partner is unpaired after leave", r.pair, null);
[s, r] = await call("GET", "/data", null, token); eq("cloud data survives pairing", r.data.habits.length, 2);
[s] = await call("POST", "/auth/logout", null, token); eq("logout", s, 200);
[s] = await call("GET", "/data", null, token); eq("token dead after logout", s, 401);
console.log("all passed");
