//
//  InAppBrowserView.swift
//  CalendarNotes
//

import SwiftUI
import WebKit

struct InAppBrowserView: View {
    let url: URL
    let bookmark: Bookmark?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var isLoading = false
    @State private var pageTitle: String = ""
    @State private var tintColor: Color = .cnAccent
    @State private var showingHighlightManager = false
    @State private var showingAddBookmark = false
    @State private var selectedText: String = ""
    @State private var showingHighlightMenu = false
    @State private var selectedColor: String = HighlightColor.yellow.rawValue
    @StateObject private var highlightViewModel: HighlightAnnotationViewModel

    init(url: URL, bookmark: Bookmark?) {
        self.url = url
        self.bookmark = bookmark
        _highlightViewModel = StateObject(wrappedValue: HighlightAnnotationViewModel(context: CoreDataManager.shared.viewContext, bookmark: bookmark))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                BrowserRepresentable(
                    url: url,
                    bookmark: bookmark,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    isLoading: $isLoading,
                    pageTitle: $pageTitle,
                    selectedText: $selectedText,
                    showingHighlightMenu: $showingHighlightMenu,
                    highlightViewModel: highlightViewModel,
                    onTextSelected: { text in
                        selectedText = text
                    },
                    onRequestShowHighlightMenu: {
                        showingHighlightMenu = true
                    }
                )
                // Bottom action bar for macOS and iOS
                HStack {
                    Button("Update Metadata") { Task { await refreshMetadata() } }
                    Divider().frame(height: 16)
                    Button("Add Bookmark") { showingAddBookmark = true }
                    Button("Article") { NotificationCenter.default.post(name: .init("BrowserJSArticle"), object: nil) }
                    Button("Screenshot") { NotificationCenter.default.post(name: .init("BrowserScreenshot"), object: nil) }
                    if bookmark != nil {
                        Button("Highlights") {
                            showingHighlightManager = true
                        }
                    }
                    Spacer()
                    Menu("More") {
                        Button("Create Note from Page") { NotificationCenter.default.post(name: .init("CreateNoteFromPage"), object: nil) }
                        Button("Add to Calendar") { NotificationCenter.default.post(name: .init("AddPageToCalendar"), object: nil) }
                    }
                }
                .padding(8)
                .background(Color.cnSecondaryBackground)
            }
                .toolbar {
                    ToolbarItemGroup(placement: .automatic) {
                        Button(action: { NotificationCenter.default.post(name: .init("BrowserGoBack"), object: nil) }) { Image(systemName: "chevron.left") }.disabled(!canGoBack)
                        Button(action: { NotificationCenter.default.post(name: .init("BrowserGoForward"), object: nil) }) { Image(systemName: "chevron.right") }.disabled(!canGoForward)
                    }
                    ToolbarItemGroup(placement: .automatic) {
                        Button(action: { showingAddBookmark = true }) { Image(systemName: "plus") }
                        Button(action: { NotificationCenter.default.post(name: .init("BrowserReload"), object: nil) }) { Image(systemName: isLoading ? "xmark" : "arrow.clockwise") }
                        Button(action: { shareCurrent() }) { Image(systemName: "square.and.arrow.up") }
                        Button("Open in Safari") { openInSafari() }
                        Button("Done") { dismiss() }
                    }
                }
                .navigationTitle(pageTitle.isEmpty ? url.host ?? "Browser" : pageTitle)
        }
        .accentColor(tintColor)
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkSheetView(
                url: url,
                initialTitle: pageTitle,
                onSaved: { showingAddBookmark = false }
            )
        }
        .sheet(isPresented: $showingHighlightManager) {
            if let bookmark = bookmark {
                HighlightManagerView(context: context, bookmark: bookmark)
                    .onDisappear {
                        // Reload highlights in web view
                        NotificationCenter.default.post(name: .init("BrowserReloadHighlights"), object: nil)
                    }
            }
        }
        .sheet(isPresented: $showingHighlightMenu) {
            HighlightMenuView(
                selectedText: selectedText,
                selectedColor: $selectedColor,
                onHighlight: { color in
                    createHighlight(color: color)
                },
                onDismiss: {
                    showingHighlightMenu = false
                    selectedText = ""
                }
            )
        }
    }
    
    private func createHighlight(color: String) {
        guard let bookmark = bookmark else { return }
        do {
            _ = try highlightViewModel.createHighlight(
                bookmark: bookmark,
                selectedText: selectedText,
                color: color
            )
            // Apply highlight to web view
            NotificationCenter.default.post(name: .init("BrowserApplyHighlight"), object: ["color": color, "text": selectedText])
            showingHighlightMenu = false
            selectedText = ""
        } catch {
            print("Error creating highlight: \(error)")
        }
    }

    private func openInSafari() {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func shareCurrent() {
        #if os(macOS)
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApplication.shared.keyWindow, let view = window.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
        #endif
    }

    private func refreshMetadata() async {
        guard let bookmark = bookmark else { return }
        do {
            let meta = try await BookmarkService.shared.fetchMetadata(for: url)
            try CoreDataManager.shared.update(bookmark) { b in
                if let t = meta.title, !t.isEmpty { b.title = t }
                if let d = meta.description, !d.isEmpty { b.bookmarkDescription = d }
            }
            try CoreDataManager.shared.save()
        } catch { }
    }
}

// MARK: - Representable with WKWebView

#if os(macOS)
private struct BrowserRepresentable: NSViewRepresentable {
    typealias NSViewType = WKWebView

    let url: URL
    let bookmark: Bookmark?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var selectedText: String
    @Binding var showingHighlightMenu: Bool
    @ObservedObject var highlightViewModel: HighlightAnnotationViewModel
    let onTextSelected: (String) -> Void
    let onRequestShowHighlightMenu: () -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // share cookies
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "CalendarNotesBrowser"
        // Observe loading
        webView.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)

        // Notifications
        context.coordinator.bind(webView: webView, parent: self)

        // Inject highlight detection script
        injectHighlightScripts(webView: webView)
        // Register script message handler
        webView.configuration.userContentController.add(context.coordinator, name: "textSelected")
        
        webView.load(URLRequest(url: url))
        return webView
    }
    
    private func injectHighlightScripts(webView: WKWebView) {
        let highlightScript = """
        (function() {
            // Highlight detection
            document.addEventListener('mouseup', function(e) {
                var selection = window.getSelection();
                if (selection.toString().trim().length > 0) {
                    var text = selection.toString();
                    window.webkit.messageHandlers.textSelected.postMessage({
                        text: text,
                        rangeStart: selection.rangeCount > 0 ? selection.getRangeAt(0).startOffset : 0,
                        rangeEnd: selection.rangeCount > 0 ? selection.getRangeAt(0).endOffset : 0
                    });
                }
            });
            
            // Apply highlights from stored data
            function applyHighlights(highlights) {
                // Remove existing highlight markers
                document.querySelectorAll('.cn-highlight').forEach(function(el) {
                    var parent = el.parentNode;
                    parent.replaceChild(document.createTextNode(el.textContent), el);
                    parent.normalize();
                });
                
                // Apply new highlights
                highlights.forEach(function(hl) {
                    walkTextNodes(document.body, function(node) {
                        if (node.nodeType === 3) { // Text node
                            var text = node.textContent;
                            var index = text.indexOf(hl.text);
                            if (index !== -1) {
                                var range = document.createRange();
                                range.setStart(node, index);
                                range.setEnd(node, index + hl.text.length);
                                var span = document.createElement('span');
                                span.className = 'cn-highlight';
                                span.style.backgroundColor = hl.color;
                                span.style.borderRadius = '2px';
                                span.setAttribute('data-highlight-id', hl.id);
                                try {
                                    range.surroundContents(span);
                                } catch(e) {
                                    // Fallback if surroundContents fails
                                    var wrapper = document.createElement('span');
                                    wrapper.className = 'cn-highlight';
                                    wrapper.style.backgroundColor = hl.color;
                                    wrapper.style.borderRadius = '2px';
                                    wrapper.setAttribute('data-highlight-id', hl.id);
                                    range.extractContents();
                                    wrapper.appendChild(range.extractContents());
                                    range.insertNode(wrapper);
                                }
                            }
                        }
                    });
                });
            }
            
            function walkTextNodes(node, callback) {
                if (node.nodeType === 3) {
                    callback(node);
                } else {
                    for (var i = 0; i < node.childNodes.length; i++) {
                        walkTextNodes(node.childNodes[i], callback);
                    }
                }
            }
            
            window.applyHighlights = applyHighlights;
        })();
        """
        
        let script = WKUserScript(source: highlightScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: BrowserRepresentable
        weak var webView: WKWebView?

        init(parent: BrowserRepresentable) {
            self.parent = parent
        }

        func bind(webView: WKWebView, parent: BrowserRepresentable) {
            self.webView = webView
            NotificationCenter.default.addObserver(self, selector: #selector(goBack), name: .init("BrowserGoBack"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(goForward), name: .init("BrowserGoForward"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadOrStop), name: .init("BrowserReload"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(jsArticle), name: .init("BrowserJSArticle"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(screenshot), name: .init("BrowserScreenshot"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(reloadHighlights), name: .init("BrowserReloadHighlights"), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(applyHighlight), name: .init("BrowserApplyHighlight"), object: nil)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "textSelected" {
                if let body = message.body as? [String: Any],
                   let text = body["text"] as? String, !text.isEmpty {
                    DispatchQueue.main.async {
                        self.parent.onTextSelected(text)
                        self.parent.onRequestShowHighlightMenu()
                    }
                }
            }
        }
        
        @objc private func reloadHighlights() {
            guard let webView = webView else { return }
            let highlights = parent.highlightViewModel.highlights
            let highlightsJSON = highlights.compactMap { highlight -> [String: Any]? in
                guard let text = highlight.selectedText,
                      let color = highlight.color,
                      let id = highlight.id?.uuidString else { return nil }
                return [
                    "id": id,
                    "text": text,
                    "color": color
                ]
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: highlightsJSON),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                let script = "if (window.applyHighlights) { window.applyHighlights(\(jsonString)); }"
                webView.evaluateJavaScript(script)
            }
        }
        
        @objc private func applyHighlight(_ notification: Notification) {
            guard let webView = webView,
                  let info = notification.object as? [String: Any],
                  let color = info["color"] as? String else { return }
            
            let hexColor = color.replacingOccurrences(of: "#", with: "")
            let script = """
            (function() {
                var selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    var range = selection.getRangeAt(0);
                    var span = document.createElement('span');
                    span.className = 'cn-highlight';
                    span.style.backgroundColor = '#\(hexColor)';
                    span.style.borderRadius = '2px';
                    try {
                        range.surroundContents(span);
                    } catch(e) {
                        var contents = range.extractContents();
                        span.appendChild(contents);
                        range.insertNode(span);
                    }
                    selection.removeAllRanges();
                }
            })();
            """
            webView.evaluateJavaScript(script)
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            switch keyPath {
            case "canGoBack": parent.canGoBack = webView.canGoBack
            case "canGoForward": parent.canGoForward = webView.canGoForward
            case "title": parent.pageTitle = webView.title ?? ""
            default: break
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            // Reload highlights after page loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.reloadHighlights()
            }
        }

        @objc private func goBack() { webView?.goBack() }
        @objc private func goForward() { webView?.goForward() }
        @objc private func reloadOrStop() {
            if webView?.isLoading == true {
                webView?.stopLoading()
            } else {
                webView?.reload()
            }
        }

        @objc private func jsArticle() {
            let script = "(function(){var a=document.querySelector('article');if(a){document.body.innerHTML='';document.body.appendChild(a.cloneNode(true));document.body.style.maxWidth='720px';document.body.style.margin='auto';document.body.style.fontSize='18px';}})();"
            webView?.evaluateJavaScript(script)
        }

        @objc private func screenshot() {
            guard let webView = webView else { return }
            let config = WKSnapshotConfiguration()
            webView.takeSnapshot(with: config) { image, _ in
                #if os(macOS)
                if let img = image, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "page.png"
                    if panel.runModal() == .OK, let url = panel.url { try? png.write(to: url) }
                }
                #endif
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            webView?.removeObserver(self, forKeyPath: "canGoBack")
            webView?.removeObserver(self, forKeyPath: "canGoForward")
            webView?.removeObserver(self, forKeyPath: "title")
        }
    }
}
#else // iOS
import UIKit

private struct BrowserRepresentable: UIViewRepresentable {
    typealias UIViewType = WKWebView
    
    let url: URL
    let bookmark: Bookmark?
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var selectedText: String
    @Binding var showingHighlightMenu: Bool
    @ObservedObject var highlightViewModel: HighlightAnnotationViewModel
    let onTextSelected: (String) -> Void
    let onRequestShowHighlightMenu: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = "CalendarNotesBrowser"
        webView.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: "title", options: .new, context: nil)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.goBack), name: .init("BrowserGoBack"), object: nil)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.goForward), name: .init("BrowserGoForward"), object: nil)
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.reloadOrStop), name: .init("BrowserReload"), object: nil)
        context.coordinator.bind(webView: webView, parent: self)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: BrowserRepresentable
        weak var webView: WKWebView?
        
        init(parent: BrowserRepresentable) {
            self.parent = parent
        }
        
        func bind(webView: WKWebView, parent: BrowserRepresentable) {
            self.webView = webView
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = webView else { return }
            if keyPath == "canGoBack" { parent.canGoBack = webView.canGoBack }
            if keyPath == "canGoForward" { parent.canGoForward = webView.canGoForward }
            if keyPath == "title" { parent.pageTitle = webView.title ?? "" }
        }
        
        @objc func goBack() { webView?.goBack() }
        @objc func goForward() { webView?.goForward() }
        @objc func reloadOrStop() { webView?.reload() }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "textSelected", let text = message.body as? String {
                parent.onTextSelected(text)
                parent.onRequestShowHighlightMenu()
            }
        }
    }
}
#endif


