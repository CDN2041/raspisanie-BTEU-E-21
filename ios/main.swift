import UIKit
import WebKit

// Обёртка над сайтом: заметки и настройки хранятся в localStorage этого приложения
let SITE = "https://cdn2041.github.io/raspisanie-BTEU-E-21/"

class VC: UIViewController, WKNavigationDelegate {
  var web: WKWebView!
  override func loadView() {
    let c = WKWebViewConfiguration()
    c.websiteDataStore = .default()
    web = WKWebView(frame: .zero, configuration: c)
    let bg = UIColor(red: 5/255, green: 6/255, blue: 8/255, alpha: 1)
    web.backgroundColor = bg
    web.scrollView.backgroundColor = bg
    web.isOpaque = false
    web.allowsBackForwardNavigationGestures = true
    web.navigationDelegate = self
    view = web
    web.load(URLRequest(url: URL(string: SITE)!))
  }
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler h: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let u = a.request.url else { return h(.allow) }
    if u.absoluteString.hasPrefix(SITE) || u.scheme == "about" || u.scheme == "blob" || u.scheme == "data" { return h(.allow) }
    // Чужие ссылки открываем в Safari
    UIApplication.shared.open(u)
    h(.cancel)
  }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ a: UIApplication, didFinishLaunchingWithOptions o: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = VC()
    window?.makeKeyAndVisible()
    return true
  }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
