//
//  WebViewContainer.swift
//  CalendarNotes
//
//  Wraps WKWebView for use in SwiftUI with advanced controls.
//

#if canImport(UIKit)
import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    typealias UIViewType = WKWebView

    @ObservedObject var viewModel: BookmarkBrowserViewModel
    let tab: BrowserTab
    let linkHoverHandler: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Use WKWebpagePreferences for JavaScript control instead of deprecated javaScriptEnabled
        configuration.defaultWebpagePreferences.allowsContentJavaScript = tab.javaScriptEnabled
        configuration.websiteDataStore = tab.isPrivate ? .nonPersistent() : .default()
        configuration.userContentController.add(context.coordinator, name: "scrollHandler")
        configuration.userContentController.add(context.coordinator, name: "linkHover")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = userAgent(for: tab.userAgent)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.delegate = context.coordinator
        context.coordinator.installScrollObserver(on: webView)
        if let url = tab.url {
            webView.load(URLRequest(url: url))
        }
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if uiView.customUserAgent != userAgent(for: tab.userAgent) {
            uiView.customUserAgent = userAgent(for: tab.userAgent)
        }
        // Use WKWebpagePreferences for JavaScript control instead of deprecated javaScriptEnabled
        uiView.configuration.defaultWebpagePreferences.allowsContentJavaScript = tab.javaScriptEnabled

        if let url = tab.url, uiView.url != url, !tab.isLoading {
            uiView.load(URLRequest(url: url))
        }

        if tab.contentBlockingEnabled != context.coordinator.contentBlockingEnabled {
            context.coordinator.contentBlockingEnabled = tab.contentBlockingEnabled
            context.coordinator.ensureContentBlocking(for: uiView)
        }
    }

    private func userAgent(for agent: BrowserUserAgent) -> String? {
        switch agent {
        case .automatic: return nil
        case .desktop:
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
        case .mobile:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate, WKScriptMessageHandler {
        var parent: WebViewContainer
        var contentBlockingEnabled: Bool
        private var notificationTokens: [NSObjectProtocol] = []
        private weak var webView: WKWebView?
        static var cachedRuleList: WKContentRuleList?
        static let blockerIdentifier = "CalendarNotesBasicBlocker"
        static var isCompilingRuleList = false

        init(_ parent: WebViewContainer) {
            self.parent = parent
            self.contentBlockingEnabled = parent.tab.contentBlockingEnabled
            super.init()
            registerNotifications()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "scrollHandler")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "linkHover")
        }

        func registerNotifications() {
            let center = NotificationCenter.default
            let tabID = parent.tab.id
            notificationTokens.append(
                center.addObserver(forName: .browserGoBack, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.webView?.goBack()
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserGoForward, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.webView?.goForward()
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserReload, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.webView?.reload()
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserFindInPage, object: nil, queue: .main) { [weak self] notification in
                    guard let self,
                          let id = notification.object as? UUID,
                          id == tabID,
                          let query = notification.userInfo?["query"] as? String else { return }
                    self.findInPage(query)
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserClearFind, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.webView?.evaluateJavaScript("window.getSelection().removeAllRanges();", completionHandler: nil)
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserCaptureSnapshot, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.captureSnapshot()
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserGeneratePDF, object: nil, queue: .main) { [weak self] notification in
                    guard let self, let id = notification.object as? UUID, id == tabID else { return }
                    self.generatePDF()
                }
            )
            notificationTokens.append(
                center.addObserver(forName: .browserScrollToOffset, object: nil, queue: .main) { [weak self] notification in
                    guard let self,
                          let id = notification.object as? UUID,
                          id == tabID,
                          let offset = notification.userInfo?["offset"] as? Double else { return }
                    self.scrollTo(offset: offset)
                }
            )
        }

        func installScrollObserver(on webView: WKWebView) {
            self.webView = webView
            ensureContentBlocking(for: webView)
            let script = """
                window.addEventListener('scroll', function() {
                    window.webkit.messageHandlers.scrollHandler.postMessage(window.scrollY || document.documentElement.scrollTop);
                });
                document.addEventListener('mouseover', function(event) {
                    const link = event.target.closest('a');
                    window.webkit.messageHandlers.linkHover.postMessage(link ? link.href : '');
                });
                document.addEventListener('mouseout', function(event) {
                    if (event.target.closest('a')) {
                        window.webkit.messageHandlers.linkHover.postMessage('');
                    }
                });
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func findInPage(_ query: String) {
            guard let webView = webView else { return }
            let escaped = query.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
                window.find("\(escaped)", false, false, true, false, false, false);
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func captureSnapshot() {
            guard let webView = webView else { return }
            webView.takeSnapshot(with: nil) { image, error in
                guard let image = image, error == nil else { return }
                self.parent.presentShare(items: [image])
            }
        }
        
        func generatePDF() {
            guard let webView = webView else { return }
            if #available(iOS 14.0, *) {
                webView.createPDF { result in
                    guard case .success(let data) = result else { return }
                    self.parent.presentPDFShare(data: data)
                }
            }
        }
        
        func scrollTo(offset: Double) {
            guard let webView = webView else { return }
            let script = "window.scrollTo(0, \(offset));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        func ensureContentBlocking(for webView: WKWebView) {
            let controller = webView.configuration.userContentController
            if parent.tab.contentBlockingEnabled {
                if let ruleList = Coordinator.cachedRuleList {
                    controller.add(ruleList)
                } else if !Coordinator.isCompilingRuleList {
                    Coordinator.isCompilingRuleList = true
                    let source = """
                    [
                      {
                        "trigger": { "url-filter": ".*", "resource-type": ["image", "script"] },
                        "action": { "type": "css-display-none", "selector": ".ads,.advertisement,[id*='ad'],[class*='ad']" }
                      }
                    ]
                    """
                    WKContentRuleListStore.default()?.compileContentRuleList(forIdentifier: Coordinator.blockerIdentifier, encodedContentRuleList: source) { ruleList, error in
                        Coordinator.isCompilingRuleList = false
                        guard let ruleList = ruleList else { return }
                        Coordinator.cachedRuleList = ruleList
                        controller.add(ruleList)
                    }
                }
            } else {
                if let ruleList = Coordinator.cachedRuleList {
                    controller.remove(ruleList)
                }
            }
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            parent.viewModel.updateZoom(for: parent.tab, delta: Double(scale) - parent.tab.zoomScale)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            installScrollObserver(on: webView)
            parent.viewModel.updateLoadingState(
                tabID: parent.tab.id,
                isLoading: false,
                title: webView.title,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
            if let url = webView.url {
                webView.evaluateJavaScript("window.scrollTo(0, \(parent.viewModel.restoreScrollPosition(for: url)));", completionHandler: nil)
                parent.viewModel.recordVisit(url: url, title: webView.title ?? url.absoluteString)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.viewModel.updateLoadingState(
                tabID: parent.tab.id,
                isLoading: true,
                title: webView.title,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.viewModel.updateLoadingState(
                tabID: parent.tab.id,
                isLoading: false,
                title: webView.title,
                canGoBack: webView.canGoBack,
                canGoForward: webView.canGoForward
            )
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "scrollHandler", let offset = message.body as? Double {
                parent.viewModel.updateScrollPosition(tabID: parent.tab.id, offset: offset)
            } else if message.name == "linkHover" {
                if let href = message.body as? String, !href.isEmpty, let url = URL(string: href) {
                    parent.linkHoverHandler(url)
                } else {
                    parent.linkHoverHandler(nil)
                }
            }
        }

        // MARK: Context Menu for link inspector
        func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
            guard let linkURL = elementInfo.linkURL else {
                completionHandler(nil)
                return
            }
            let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
                let openAction = UIAction(title: "Open Link") { _ in
                    self.parent.viewModel.load(url: linkURL)
                }
                let newTabAction = UIAction(title: "Open in New Tab") { _ in
                    self.parent.viewModel.addNewTab(privateMode: self.parent.tab.isPrivate)
                    self.parent.viewModel.load(url: linkURL)
                }
                let copyAction = UIAction(title: "Copy Link") { _ in
                    UIPasteboard.general.url = linkURL
                }
                return UIMenu(title: linkURL.absoluteString, children: [openAction, newTabAction, copyAction])
            }
            completionHandler(configuration)
        }
    }

    func presentShare(items: [Any]) {
        guard let topController = topMostController() else { return }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        topController.present(activity, animated: true)
    }

    func presentPDFShare(data: Data) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Bookmark-\(UUID().uuidString.prefix(6)).pdf")
        do {
            try data.write(to: tempURL, options: [.atomic])
            presentShare(items: [tempURL])
        } catch {
            // ignore
        }
    }

    private func topMostController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#endif


