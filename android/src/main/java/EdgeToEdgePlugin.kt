package com.plugin.edgetoedge

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsAnimationCompat
import app.tauri.annotation.Command
import app.tauri.annotation.TauriPlugin
import app.tauri.plugin.JSObject
import app.tauri.plugin.Plugin
import app.tauri.plugin.Invoke

/**
 * Edge-to-Edge 插件 - Android 实现
 * 为 Android 提供全屏沉浸式体验支持
 */
@TauriPlugin
class EdgeToEdgePlugin(private val activity: Activity): Plugin(activity) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var cachedInsets = SafeAreaInsets(0, 0, 0, 0)
    private var lastKeyboardVisible = false
    
    data class SafeAreaInsets(val top: Int, val right: Int, val bottom: Int, val left: Int)
    
    override fun load(webView: WebView) {
        super.load(webView)
        this.webView = webView
        
        // 监听 WebView 页面加载事件
        setupWebViewCallbacks(webView)
        
        mainHandler.post {
            setupEdgeToEdge()
            setupWindowInsets()
            setupKeyboardAnimationListener()  // 使用 Capacitor 风格的精确键盘监听
        }
        
        println("[EdgeToEdge] Plugin loaded successfully")
    }
    
    private fun setupWebViewCallbacks(webView: WebView) {
        webView.webViewClient = object : android.webkit.WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                // 页面加载完成时重新注入安全区域
                mainHandler.postDelayed({
                    if (cachedInsets.top > 0 || cachedInsets.bottom > 0) {
                        injectSafeAreaToWebView(cachedInsets)
                        println("[EdgeToEdge] Re-injected safe area after page loaded: $url")
                    }
                }, 100)
            }
        }
    }
    
    /**
     * 设置键盘动画监听器 (借鉴 Capacitor Keyboard 官方插件)
     * 使用 WindowInsetsAnimationCompat.Callback 实现精确的键盘动画追踪
     */
    private fun setupKeyboardAnimationListener() {
        val content = activity.window.decorView.findViewById<FrameLayout>(android.R.id.content)
        val rootView = content.rootView
        
        ViewCompat.setWindowInsetsAnimationCallback(
            rootView,
            object : WindowInsetsAnimationCompat.Callback(DISPATCH_MODE_STOP) {
                override fun onProgress(
                    insets: WindowInsetsCompat,
                    runningAnimations: MutableList<WindowInsetsAnimationCompat>
                ): WindowInsetsCompat {
                    return insets
                }
                
                override fun onStart(
                    animation: WindowInsetsAnimationCompat,
                    bounds: WindowInsetsAnimationCompat.BoundsCompat
                ): WindowInsetsAnimationCompat.BoundsCompat {
                    val windowInsets = ViewCompat.getRootWindowInsets(rootView)
                    val isKeyboardVisible = windowInsets?.isVisible(WindowInsetsCompat.Type.ime()) ?: false
                    val imeHeight = windowInsets?.getInsets(WindowInsetsCompat.Type.ime())?.bottom ?: 0
                    
                    println("[EdgeToEdge] Keyboard animation start - Visible:$isKeyboardVisible, Height:$imeHeight")
                    
                    // 键盘将要显示/隐藏时注入
                    injectSafeAreaToWebView(cachedInsets, isKeyboardVisible, imeHeight)
                    
                    return super.onStart(animation, bounds)
                }
                
                override fun onEnd(animation: WindowInsetsAnimationCompat) {
                    super.onEnd(animation)
                    val windowInsets = ViewCompat.getRootWindowInsets(rootView)
                    val isKeyboardVisible = windowInsets?.isVisible(WindowInsetsCompat.Type.ime()) ?: false
                    val imeHeight = windowInsets?.getInsets(WindowInsetsCompat.Type.ime())?.bottom ?: 0
                    
                    lastKeyboardVisible = isKeyboardVisible
                    
                    println("[EdgeToEdge] Keyboard animation end - Visible:$isKeyboardVisible, Height:$imeHeight")
                    
                    // 键盘动画结束后再次注入确保状态正确
                    injectSafeAreaToWebView(cachedInsets, isKeyboardVisible, imeHeight)
                }
            }
        )
        
        println("[EdgeToEdge] Keyboard animation listener setup complete (Capacitor style)")
    }
    
    private fun setupEdgeToEdge() {
        val window = activity.window
        
        // 启用 Edge-to-Edge
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Android 10+ 禁用导航栏对比度保护
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
        
        // 设置透明系统栏
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        
        // 设置系统栏图标颜色
        val isDarkTheme = (activity.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        
        WindowCompat.getInsetsController(window, window.decorView)?.apply {
            isAppearanceLightStatusBars = !isDarkTheme
            isAppearanceLightNavigationBars = !isDarkTheme
        }
    }
    
    private fun setupWindowInsets() {
        ViewCompat.setOnApplyWindowInsetsListener(activity.window.decorView) { view, windowInsets ->
            val systemBarsInsets = windowInsets.getInsets(WindowInsetsCompat.Type.systemBars())
            val imeInsets = windowInsets.getInsets(WindowInsetsCompat.Type.ime())
            val imeHeight = imeInsets.bottom
            val isKeyboardVisible = imeHeight > 0
            
            val newInsets = SafeAreaInsets(
                systemBarsInsets.top,
                systemBarsInsets.right,
                systemBarsInsets.bottom,
                systemBarsInsets.left
            )
            
            // 只有当 insets 真正变化时才更新
            if (newInsets != cachedInsets || isKeyboardVisible != lastKeyboardVisible) {
                cachedInsets = newInsets
                lastKeyboardVisible = isKeyboardVisible
                
                println("[EdgeToEdge] WindowInsets changed - Top:${newInsets.top}, Bottom:${newInsets.bottom}, Keyboard:$isKeyboardVisible($imeHeight)")
                
                // 立即注入新的安全区域
                injectSafeAreaToWebView(cachedInsets, isKeyboardVisible, imeHeight)
            }
            
            val bottomPadding = if (isKeyboardVisible) maxOf(0, imeHeight - systemBarsInsets.bottom) else 0
            view.setPadding(0, 0, 0, bottomPadding)
            
            windowInsets
        }
    }
    
    
    private fun injectSafeAreaToWebView(
        insets: SafeAreaInsets,
        isKeyboardVisible: Boolean = false,
        keyboardHeight: Int = 0
    ) {
        webView?.let { wv ->
            val density = activity.resources.displayMetrics.density
            val topPx = insets.top / density
            val rightPx = insets.right / density
            val bottomPx = insets.bottom / density
            val leftPx = insets.left / density
            val keyboardPx = keyboardHeight / density
            val computedBottom = maxOf(bottomPx, 48f)
            
            val jsCode = """
                (function() {
                    var style = document.documentElement.style;
                    style.setProperty('--safe-area-inset-top', '${topPx}px');
                    style.setProperty('--safe-area-inset-right', '${rightPx}px');
                    style.setProperty('--safe-area-inset-bottom', '${bottomPx}px');
                    style.setProperty('--safe-area-inset-left', '${leftPx}px');
                    style.setProperty('--safe-area-top', '${topPx}px');
                    style.setProperty('--safe-area-right', '${rightPx}px');
                    style.setProperty('--safe-area-bottom', '${bottomPx}px');
                    style.setProperty('--safe-area-left', '${leftPx}px');
                    style.setProperty('--safe-area-bottom-computed', '${computedBottom}px');
                    style.setProperty('--safe-area-bottom-min', '48px');
                    style.setProperty('--content-bottom-padding', '${computedBottom + 16}px');
                    style.setProperty('--keyboard-height', '${keyboardPx}px');
                    style.setProperty('--keyboard-visible', '${if (isKeyboardVisible) "1" else "0"}');
                    window.dispatchEvent(new CustomEvent('safeAreaChanged', {
                        detail: { top: $topPx, right: $rightPx, bottom: $bottomPx, left: $leftPx, keyboardHeight: $keyboardPx, keyboardVisible: $isKeyboardVisible }
                    }));
                })();
            """.trimIndent()
            
            wv.evaluateJavascript(jsCode, null)
        }
    }
    
    @Command
    fun getSafeAreaInsets(invoke: Invoke) {
        val density = activity.resources.displayMetrics.density
        val result = JSObject().apply {
            put("top", cachedInsets.top / density)
            put("right", cachedInsets.right / density)
            put("bottom", cachedInsets.bottom / density)
            put("left", cachedInsets.left / density)
        }
        invoke.resolve(result)
    }
    
    @Command
    fun enable(invoke: Invoke) {
        mainHandler.post { setupEdgeToEdge() }
        invoke.resolve()
    }
    
    @Command
    fun disable(invoke: Invoke) {
        mainHandler.post {
            WindowCompat.setDecorFitsSystemWindows(activity.window, true)
        }
        invoke.resolve()
    }
}
