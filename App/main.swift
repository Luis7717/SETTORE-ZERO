import UIKit
import WebKit

// Serve i file del gioco (cartella www/ dentro l'app) su uno schema proprio, come un sito:
// fetch, modelli e audio funzionano senza le limitazioni di file://.
final class AppSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL
    private var active = Set<ObjectIdentifier>()
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "tiroagiro.files", qos: .userInitiated)

    init(root: URL) { self.root = root.standardizedFileURL }

    private static let types: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
        "json": "application/json", "glb": "model/gltf-binary", "gltf": "model/gltf+json", "bin": "application/octet-stream",
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp", "ktx2": "image/ktx2",
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "aac": "audio/aac", "wav": "audio/wav",
    ]

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let id = ObjectIdentifier(task)
        lock.lock(); active.insert(id); lock.unlock()
        let url = task.request.url
        queue.async {
            var path = url?.path ?? "/"
            if path.isEmpty || path == "/" { path = "/index.html" }
            let file = self.root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
            let inside = file.path.hasPrefix(self.root.path + "/")
            let data: Data? = inside ? (try? Data(contentsOf: file, options: .mappedIfSafe)) : nil
            DispatchQueue.main.async {
                self.lock.lock(); let alive = self.active.remove(id) != nil; self.lock.unlock()
                guard alive, let reqURL = url else { return }
                let type = AppSchemeHandler.types[file.pathExtension.lowercased()] ?? "application/octet-stream"
                var headers = ["Content-Type": "text/plain", "Content-Length": "0"]
                if let d = data { headers = ["Content-Type": type, "Content-Length": String(d.count), "Cache-Control": "no-cache"] }
                if let resp = HTTPURLResponse(url: reqURL, statusCode: data == nil ? 404 : 200, httpVersion: "HTTP/1.1", headerFields: headers) {
                    task.didReceive(resp)
                }
                task.didReceive(data ?? Data())
                task.didFinish()
            }
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {
        lock.lock(); active.remove(ObjectIdentifier(task)); lock.unlock()
    }
}

// Evita il ciclo di riferimenti tra WKUserContentController e il controller.
final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

final class GameVC: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private var web: WKWebView!
    private var gameLoaded = false
    private let scheme = WKWebView.handlesURLScheme("app") ? "tiroagiro" : "app"
    private let defaults = UserDefaults.standard
    // Recupero del salvataggio: l'origine passa da file:// a app://, quindi localStorage cambia.
    private let kRead = "legacySaveRead", kDone = "legacySaveDone", kSave = "legacySave"
    // copia di sicurezza del vecchio salvataggio: non viene mai cancellata
    private let kBackup = "legacySaveBackup"

    override func loadView() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let root = Bundle.main.bundleURL.appendingPathComponent("www", isDirectory: true)
        cfg.setURLSchemeHandler(AppSchemeHandler(root: root), forURLScheme: scheme)
        cfg.userContentController.add(WeakHandler(self), name: "legacy")
        web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsLinkPreview = false
        web.allowsBackForwardNavigationGestures = false
        web.navigationDelegate = self
        view = web
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if defaults.bool(forKey: kDone) { loadGame(legacy: nil) }
        else if defaults.bool(forKey: kRead) { loadGame(legacy: defaults.string(forKey: kSave)) }
        else { readLegacy() }
    }

    // 1) pagina di passaggio nella vecchia posizione (file://): legge tag_save_v1 e lo manda con postMessage
    private func readLegacy() {
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html") else { loadGame(legacy: nil); return }
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        // se la pagina non risponde, il gioco parte lo stesso (si riproverà al prossimo avvio)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.loadGame(legacy: nil) }
    }

    // 2) il gioco vero su app://; se c'è un vecchio salvataggio lo passa alla pagina prima che parta
    private func loadGame(legacy: String?) {
        if gameLoaded { return }
        gameLoaded = true
        if let s = legacy, !s.isEmpty,
           let json = try? JSONSerialization.data(withJSONObject: [s]),
           let arr = String(data: json, encoding: .utf8) {
            let js = "window.__legacySave = \(arr)[0];"
            web.configuration.userContentController.addUserScript(
                WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        if let url = URL(string: "\(scheme)://localhost/index.html") { web.load(URLRequest(url: url)) }
    }

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        guard let body = m.body as? [String: Any] else { return }
        if body["error"] != nil {
            // la vecchia origine non si è lasciata leggere: si gioca e si riprova al prossimo avvio
            loadGame(legacy: nil)
        } else if let save = body["save"] as? String {
            if gameLoaded { return }
            // letto dalla vecchia origine
            defaults.set(true, forKey: kRead)
            if save.isEmpty { defaults.set(true, forKey: kDone) }
            else { defaults.set(save, forKey: kSave); defaults.set(save, forKey: kBackup) }
            loadGame(legacy: save.isEmpty ? nil : save)
        } else if let result = body["result"] as? String, result != "error" {
            // copia riuscita (o non necessaria) nella nuova origine: non si ripete più
            defaults.set(true, forKey: kDone)
            defaults.removeObject(forKey: kSave)
        }
    }

    // se il processo della pagina viene chiuso (per esempio per memoria) si ricarica il gioco
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let url = URL(string: "\(scheme)://localhost/index.html") { webView.load(URLRequest(url: url)) }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}

final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.backgroundColor = .black
        w.rootViewController = GameVC()
        w.makeKeyAndVisible()
        window = w
        return true
    }
}

UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(AppDelegate.self))
