import SwiftUI
import WebKit

/// What the in-app browser opens.
struct BrowserTarget: Identifiable, Hashable {
    let url: URL
    /// When set, the page you end up on is remembered for that series so it opens there next time.
    var seriesID: String? = nil
    var id: String { url.absoluteString }
}

/// Turns what you typed into a page: a full URL, a bare domain, or a web search.
func browserURL(from text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
        return URL(string: trimmed)
    }
    if !trimmed.contains(" "), trimmed.contains("."), let url = URL(string: "https://" + trimmed) {
        return url
    }
    let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
    return URL(string: "https://duckduckgo.com/?q=" + query)
}

/// Hosts that only serve ads, popups and trackers. Blocked before they load.
private let blockedAdHosts = [
    "doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com", "adnxs.com",
    "taboola.com", "outbrain.com", "popads.net", "popcash.net", "propellerads.com", "exoclick.com", "juicyads.com",
    "adsterra.com", "trafficjunky.com", "onclickads.net", "a-ads.com", "clickadu.com", "hilltopads.net", "mgid.com",
    "revcontent.com", "amazon-adsystem.com", "admaven.com", "pubmatic.com", "rubiconproject.com", "criteo.com",
    "moatads.com", "scorecardresearch.com", "adform.net", "smartadserver.com", "casalemedia.com", "openx.net",
    "yieldmo.com", "bidswitch.net", "adskeeper.com", "richpush.co", "pushame.com", "profitableratecpm.com",
    "highperformanceformat.com", "effectivegatecpm.com", "ad-maven.com", "tsyndicate.com", "adcash.com"
]

/// Rules for WebKit's content blocker, built from the host list.
private func adRuleList() -> String {
    let rules = blockedAdHosts.map { host in
        "{\"trigger\":{\"url-filter\":\"^https?://([^/]+\\\\.)?\(host.replacingOccurrences(of: ".", with: "\\\\."))\"},\"action\":{\"type\":\"block\"}}"
    }
    return "[" + rules.joined(separator: ",") + "]"
}

/// Hides leftover ad slots and app-install banners on pages.
private let adHidingScript = """
var s = document.createElement('style');
s.textContent = '[id^="google_ads"],ins.adsbygoogle,[class*="adsbygoogle"],[id^="div-gpt-ad"],[class*="ad-banner"],[class*="ad-container"],[class*="adsbox"],[id*="banner-ad"],[data-ad],[data-ad-slot],iframe[src*="doubleclick"],iframe[src*="googlesyndication"],.smartbanner,.smart-banner,[class*="app-banner"],[class*="AppBanner"],[class*="download-app"]{display:none!important}';
(document.head || document.documentElement).appendChild(s);
"""

/// A page worth coming back to: a series page or chapter, not a home, search or listing page.
func isRememberablePage(_ url: URL?) -> Bool {
    guard let url, let host = url.host, !host.contains("duckduckgo") else { return false }
    let path = url.path.lowercased()
    if path.isEmpty || path == "/" { return false }
    return !["filter", "search", "browse", "updates", "genre", "login", "sign"].contains { path.contains($0) }
}

/// True for pages that are a chapter reader, where the browser bars should get out of the way.
func isChapterURL(_ url: URL?) -> Bool {
    guard let url else { return false }
    let path = url.path.lowercased()
    let markers = ["/viewer", "/chapter", "/read/", "/reader", "/ch-", "/ch/", "/episode"]
    return markers.contains { path.contains($0) } || url.absoluteString.lowercased().contains("/chapter-")
}

final class BrowserModel: NSObject, ObservableObject, WKUIDelegate {
    let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.allowsBackForwardNavigationGestures = true
        return view
    }()
    @Published var address = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress = 0.0
    private var observers: [NSKeyValueObservation] = []

    override init() {
        super.init()
        webView.uiDelegate = self
        let script = WKUserScript(source: adHidingScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
        observers = [
            webView.observe(\.url) { [weak self] view, _ in
                DispatchQueue.main.async { if let url = view.url { self?.address = url.absoluteString } }
            },
            webView.observe(\.canGoBack) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoBack = view.canGoBack } },
            webView.observe(\.canGoForward) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoForward = view.canGoForward } },
            webView.observe(\.isLoading) { [weak self] view, _ in DispatchQueue.main.async { self?.isLoading = view.isLoading } },
            webView.observe(\.estimatedProgress) { [weak self] view, _ in DispatchQueue.main.async { self?.progress = view.estimatedProgress } }
        ]
    }

    /// Compiles the ad blocker (cached after the first run). Call before the first load.
    func installBlocker() async {
        let controller = webView.configuration.userContentController
        if let list = try? await WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "dayforge-ads-v1", encodedContentRuleList: adRuleList()) {
            controller.add(list)
        }
    }

    /// Popups: only same-site links open (in this view). Anything else is dropped.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let target = navigationAction.request.url, target.host == webView.url?.host {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func load(_ url: URL) {
        address = url.absoluteString
        webView.load(URLRequest(url: url))
    }
}

private struct WebViewHost: UIViewRepresentable {
    var model: BrowserModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

/// A small full-screen browser so any site can be read without leaving Dayforge.
struct WebBrowserView: View {
    var start: URL
    var seriesID: String? = nil
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BrowserModel()
    @FocusState private var addressFocused: Bool
    /// Full screen: bars hidden while a chapter is open. Resets whenever the page changes.
    @State private var immersive = false

    var body: some View {
        VStack(spacing: 0) {
            if !immersive { topBar }
            ZStack(alignment: .top) {
                WebViewHost(model: model)
                    .ignoresSafeArea(edges: immersive ? .all : [])
                if model.isLoading && !immersive {
                    ProgressView(value: model.progress).tint(Theme.clay)
                }
                if immersive { floatingControls }
            }
            if !immersive { bottomBar }
        }
        .background((immersive ? Color.black : Theme.background).ignoresSafeArea())
        .statusBarHidden(immersive)
        .animation(.snappy, value: immersive)
        .task {
            await model.installBlocker()
            model.load(start)
        }
        .onChange(of: model.address) { _, _ in
            immersive = isChapterURL(model.webView.url)
        }
        // Remember the page only once it has finished loading, so a redirect never leaves a wrong link behind.
        .onChange(of: model.isLoading) { _, loading in
            if !loading, let seriesID, let current = model.webView.url, isRememberablePage(current) {
                app.saveSourceLink(current, for: seriesID)
            }
        }
    }

    private var floatingControls: some View {
        HStack(spacing: 10) {
            Button { immersive = false } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Show browser bars")
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .accessibilityLabel("Close browser")
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 54)
    }

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Theme.ink.opacity(0.07), in: Circle())
                }
                .accessibilityLabel("Close browser")

                TextField("Search or enter a site", text: $model.address)
                    .focused($addressFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.webSearch)
                    .submitLabel(.go)
                    .font(.system(size: 14, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
                    .onSubmit {
                        if let url = browserURL(from: model.address) { model.load(url) }
                    }
                    .accessibilityLabel("Address")

                Button {
                    if model.isLoading { model.webView.stopLoading() } else { model.webView.reload() }
                } label: {
                    Image(systemName: model.isLoading ? "xmark.circle" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(model.isLoading ? "Stop loading" : "Reload")
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.background)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button { model.webView.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!model.canGoBack)
                    .accessibilityLabel("Back")
                Spacer()
                Button { model.webView.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!model.canGoForward)
                    .accessibilityLabel("Forward")
                Spacer()
                Button { immersive = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .accessibilityLabel("Full screen")
                Spacer()
                ShareLink(item: URL(string: model.address) ?? start) { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share page")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Theme.background)
        }
    }
}
