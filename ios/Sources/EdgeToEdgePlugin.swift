import SwiftRs
import Tauri
import UIKit
import WebKit

// MARK: - Edge-to-Edge Plugin
// 为 iOS 提供全屏沉浸式体验支持
// 完美复制 Capacitor 版本的实现逻辑

class EdgeToEdgePlugin: Plugin {
    private var isSetup = false
    private weak var webviewRef: WKWebView?
    private var keyboardHeight: CGFloat = 0
    private var isKeyboardVisible = false
    
    // MARK: - Lifecycle
    
    @objc public override func load(webview: WKWebView) {
        guard !isSetup else { return }
        isSetup = true
        webviewRef = webview
        
        // 设置 Edge-to-Edge
        setupEdgeToEdge(webview: webview)
        
        // 注册键盘监听
        registerKeyboardObservers(webview: webview)
        
        // 周期性注入安全区域（覆盖页面加载过程）
        startPeriodicInjection(webview: webview)
        
        NSLog("[EdgeToEdge] Plugin loaded successfully (Capacitor style)")
    }
    
    // MARK: - Setup
    
    private func setupEdgeToEdge(webview: WKWebView) {
        // 1. 设置 WebView 背景透明
        webview.isOpaque = false
        webview.backgroundColor = .clear
        webview.scrollView.backgroundColor = .clear
        
        // 2. 关键设置：使用 .never 禁用系统自动调整
        // 这样可以防止键盘隐藏后系统重置 Edge-to-Edge 设置
        if #available(iOS 11.0, *) {
            webview.scrollView.contentInsetAdjustmentBehavior = .never
        }
        
        // 3. 禁用滚动视图的自动 inset 调整
        webview.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        
        // 4. 设置窗口背景色（支持深色模式）
        DispatchQueue.main.async {
            self.setupWindowBackground(webview: webview)
        }
        
        NSLog("[EdgeToEdge] Edge-to-edge mode enabled")
    }
    
    /// 设置窗口背景色
    private func setupWindowBackground(webview: WKWebView) {
        guard let window = webview.window else { return }
        
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
    
    // MARK: - Keyboard Observers (Capacitor Keyboard style)
    
    private func registerKeyboardObservers(webview: WKWebView) {
        // keyboardWillShow
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak webview] notification in
            guard let self = self, let wv = webview else { return }
            self.handleKeyboardWillShow(webview: wv, notification: notification)
        }
        
        // keyboardDidShow
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak webview] notification in
            guard let self = self, let wv = webview else { return }
            self.handleKeyboardDidShow(webview: wv, notification: notification)
        }
        
        // keyboardWillHide
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak webview] notification in
            guard let self = self, let wv = webview else { return }
            self.handleKeyboardWillHide(webview: wv, notification: notification)
        }
        
        // keyboardDidHide
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidHideNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak webview] notification in
            guard let self = self, let wv = webview else { return }
            self.handleKeyboardDidHide(webview: wv, notification: notification)
        }
        
        NSLog("[EdgeToEdge] Keyboard observers registered (Capacitor Keyboard style)")
    }
    
    /// 键盘将要显示
    private func handleKeyboardWillShow(webview: WKWebView, notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        keyboardHeight = keyboardFrame.height
        isKeyboardVisible = true
        
        NSLog("[EdgeToEdge] Keyboard will show - Height: \(keyboardHeight)")
        injectSafeAreaInsets(webview: webview, keyboardHeight: keyboardHeight, keyboardVisible: true)
    }
    
    /// 键盘已经显示
    private func handleKeyboardDidShow(webview: WKWebView, notification: Notification) {
        NSLog("[EdgeToEdge] Keyboard did show")
        // 再次注入确保状态正确
        injectSafeAreaInsets(webview: webview, keyboardHeight: keyboardHeight, keyboardVisible: true)
    }
    
    /// 键盘将要隐藏
    private func handleKeyboardWillHide(webview: WKWebView, notification: Notification) {
        keyboardHeight = 0
        isKeyboardVisible = false
        
        NSLog("[EdgeToEdge] Keyboard will hide")
        injectSafeAreaInsets(webview: webview, keyboardHeight: 0, keyboardVisible: false)
    }
    
    /// 键盘已经隐藏 - 关键：重新恢复 Edge-to-Edge 设置
    private func handleKeyboardDidHide(webview: WKWebView, notification: Notification) {
        NSLog("[EdgeToEdge] Keyboard did hide - Restoring Edge-to-Edge")
        
        // 重新应用 Edge-to-Edge 设置，防止系统重置
        restoreEdgeToEdge(webview: webview)
        
        // 注入安全区域
        injectSafeAreaInsets(webview: webview, keyboardHeight: 0, keyboardVisible: false)
        
        // 延迟再次注入，确保状态完全恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak webview] in
            guard let self = self, let wv = webview else { return }
            self.injectSafeAreaInsets(webview: wv, keyboardHeight: 0, keyboardVisible: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self, weak webview] in
            guard let self = self, let wv = webview else { return }
            self.injectSafeAreaInsets(webview: wv, keyboardHeight: 0, keyboardVisible: false)
        }
    }
    
    /// 重新恢复 Edge-to-Edge 设置
    private func restoreEdgeToEdge(webview: WKWebView) {
        // 重新设置关键属性
        if #available(iOS 11.0, *) {
            webview.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webview.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        
        // 重置 scrollView 的 contentInset
        webview.scrollView.contentInset = .zero
        webview.scrollView.scrollIndicatorInsets = .zero
        
        NSLog("[EdgeToEdge] Edge-to-Edge settings restored")
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
    
    @objc public func getKeyboardInfo(_ invoke: Invoke) throws {
        invoke.resolve([
            "keyboardHeight": self.keyboardHeight,
            "isVisible": self.isKeyboardVisible
        ])
    }
    
    @objc public func enable(_ invoke: Invoke) throws {
        if let wv = webviewRef {
            setupEdgeToEdge(webview: wv)
        }
        invoke.resolve()
    }
    
    @objc public func disable(_ invoke: Invoke) throws {
        invoke.resolve()
    }
    
    @objc public func showKeyboard(_ invoke: Invoke) throws {
        // iOS 不支持编程方式显示键盘
        invoke.resolve()
    }
    
    @objc public func hideKeyboard(_ invoke: Invoke) throws {
        DispatchQueue.main.async { [weak self] in
            self?.webviewRef?.endEditing(true)
        }
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
