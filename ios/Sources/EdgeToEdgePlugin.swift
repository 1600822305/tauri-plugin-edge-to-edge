import SwiftRs
import Tauri
import UIKit
import WebKit

// MARK: - Edge-to-Edge Plugin
// 为 iOS 提供全屏沉浸式体验支持

class EdgeToEdgePlugin: Plugin {
    private var isSetup = false
    
    // MARK: - Lifecycle
    
    @objc public override func load(webview: WKWebView) {
        guard !isSetup else { return }
        isSetup = true
        
        // 设置 Edge-to-Edge
        setupEdgeToEdge(webview: webview)
        
        // 注册键盘监听
        registerKeyboardObservers(webview: webview)
        
        // 周期性注入安全区域（覆盖页面加载过程）
        startPeriodicInjection(webview: webview)
        
        NSLog("[EdgeToEdge] Plugin loaded successfully")
    }
    
    // MARK: - Setup
    
    private func setupEdgeToEdge(webview: WKWebView) {
        // 1. 设置 WebView 背景透明
        webview.isOpaque = false
        webview.backgroundColor = .clear
        webview.scrollView.backgroundColor = .clear
        
        // 2. 禁用 ScrollView 自动安全区域调整
        if #available(iOS 11.0, *) {
            webview.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        // 3. 设置窗口背景色（支持深色模式）
        DispatchQueue.main.async {
            if let window = webview.window {
                if #available(iOS 13.0, *) {
                    window.backgroundColor = UIColor { traitCollection in
                        return traitCollection.userInterfaceStyle == .dark
                            ? UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
                            : UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
                    }
                } else {
                    window.backgroundColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
                }
                window.rootViewController?.view.backgroundColor = window.backgroundColor
            }
        }
    }
    
    // MARK: - Keyboard Observers
    
    private func registerKeyboardObservers(webview: WKWebView) {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak webview] notification in
            guard let wv = webview,
                  let userInfo = notification.userInfo,
                  let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            self.injectSafeAreaInsets(webview: wv, keyboardHeight: keyboardFrame.height, keyboardVisible: true)
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak webview] _ in
            guard let wv = webview else { return }
            self.injectSafeAreaInsets(webview: wv, keyboardHeight: 0, keyboardVisible: false)
        }
    }
    
    // MARK: - Periodic Injection
    
    private func startPeriodicInjection(webview: WKWebView) {
        for i in 1...10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) { [weak self, weak webview] in
                guard let self = self, let wv = webview else { return }
                self.injectSafeAreaInsets(webview: wv, keyboardHeight: 0, keyboardVisible: false)
            }
        }
    }
    
    // MARK: - Safe Area Injection
    
    private func injectSafeAreaInsets(webview: WKWebView, keyboardHeight: CGFloat, keyboardVisible: Bool) {
        guard #available(iOS 11.0, *) else { return }
        
        let safeArea = webview.window?.safeAreaInsets ?? .zero
        let top = safeArea.top
        let right = safeArea.right
        let bottom = safeArea.bottom
        let left = safeArea.left
        let computedBottom = max(bottom, 34.0)
        
        let jsCode = """
        (function() {
            var style = document.documentElement.style;
            style.setProperty('--safe-area-inset-top', '\(top)px');
            style.setProperty('--safe-area-inset-right', '\(right)px');
            style.setProperty('--safe-area-inset-bottom', '\(bottom)px');
            style.setProperty('--safe-area-inset-left', '\(left)px');
            style.setProperty('--safe-area-top', '\(top)px');
            style.setProperty('--safe-area-right', '\(right)px');
            style.setProperty('--safe-area-bottom', '\(bottom)px');
            style.setProperty('--safe-area-left', '\(left)px');
            style.setProperty('--safe-area-bottom-computed', '\(computedBottom)px');
            style.setProperty('--safe-area-bottom-min', '34px');
            style.setProperty('--content-bottom-padding', '\(computedBottom + 16)px');
            style.setProperty('--keyboard-height', '\(keyboardHeight)px');
            style.setProperty('--keyboard-visible', '\(keyboardVisible ? "1" : "0")');
            window.dispatchEvent(new CustomEvent('safeAreaChanged', {
                detail: { top: \(top), right: \(right), bottom: \(bottom), left: \(left), keyboardHeight: \(keyboardHeight), keyboardVisible: \(keyboardVisible) }
            }));
        })();
        """
        
        webview.evaluateJavaScript(jsCode, completionHandler: nil)
    }
    
    // MARK: - Commands
    
    @objc public func getSafeAreaInsets(_ invoke: Invoke) throws {
        guard #available(iOS 11.0, *) else {
            invoke.resolve(["top": 0, "right": 0, "bottom": 0, "left": 0])
            return
        }
        
        DispatchQueue.main.async {
            let safeArea = UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
            invoke.resolve([
                "top": safeArea.top,
                "right": safeArea.right,
                "bottom": safeArea.bottom,
                "left": safeArea.left
            ])
        }
    }
    
    @objc public func enable(_ invoke: Invoke) throws {
        invoke.resolve()
    }
    
    @objc public func disable(_ invoke: Invoke) throws {
        invoke.resolve()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@_cdecl("init_plugin_edge_to_edge")
func initPlugin() -> Plugin {
    return EdgeToEdgePlugin()
}
