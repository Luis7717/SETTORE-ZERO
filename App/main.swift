import UIKit
import WebKit

// MARK: - Costanti

/// Schema personalizzato con cui serviamo i file del gioco (come se fosse un sito).
private enum Schema {
    static let nome = "app"
    static let paginaIniziale = "app://localhost/index.html"
}

/// Chiavi salvate in UserDefaults per il trasferimento dei salvataggi.
private enum Chiavi {
    /// true solo dopo che la pagina app:// ha confermato di aver scritto i vecchi dati.
    static let migrazioneFatta = "sz_migrazione_localstorage_fatta"
    /// Copia di riserva (JSON {chiave: valore}) del vecchio localStorage file://. Non viene mai cancellata.
    static let copiaRiserva = "sz_localstorage_file_copia"
}

/// Nomi dei canali window.webkit.messageHandlers.<nome>.
private enum Messaggi {
    /// Da migra.html (origine file://): tutte le chiavi del vecchio localStorage.
    static let datiVecchi = "szMigraDati"
    /// Dallo script iniettato nella pagina app://: conferma che i dati sono stati scritti.
    static let conferma = "szMigraFatto"
}

/// Secondi di attesa massima per la risposta di migra.html.
private let attesaMassimaLettura: TimeInterval = 10

// MARK: - Lettura dei file del bundle (nessuno stato condiviso: si può usare da qualsiasi thread)

struct RispostaFile {
    let stato: Int
    let intestazioni: [String: String]
    let corpo: Data
}

struct LettoreBundle {
    private enum RichiestaRange {
        case intero
        case parte(Int, Int)
        case nonSoddisfacibile
    }

    private static let tipiMime: [String: String] = [
        "html": "text/html", "htm": "text/html",
        "js": "text/javascript", "mjs": "text/javascript",
        "css": "text/css", "json": "application/json",
        "glb": "model/gltf-binary", "gltf": "model/gltf+json",
        "bin": "application/octet-stream",
        "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg",
        "webp": "image/webp", "ktx2": "image/ktx2", "svg": "image/svg+xml",
        "mp3": "audio/mpeg", "m4a": "audio/mp4", "ogg": "audio/ogg", "wav": "audio/wav",
        "wasm": "application/wasm", "txt": "text/plain"
    ]

    /// Tipi di testo a cui aggiungere "; charset=utf-8".
    private static let tipiTesto: Set<String> = [
        "text/html", "text/javascript", "text/css", "application/json",
        "model/gltf+json", "image/svg+xml", "text/plain"
    ]

    private let radice: URL
    private let radiceRisolta: URL

    init(radice base: URL) {
        radice = base.standardizedFileURL
        radiceRisolta = radice.resolvingSymlinksInPath()
    }

    func risposta(per richiesta: URLRequest, url: URL) -> RispostaFile {
        guard let file = fileRichiesto(url) else {
            return LettoreBundle.errore(403, "Forbidden")
        }
        var cartella: ObjCBool = false
        guard FileManager.default.fileExists(atPath: file.path, isDirectory: &cartella), !cartella.boolValue else {
            return LettoreBundle.errore(404, "Not Found")
        }
        // Controllo finale dopo aver risolto eventuali link simbolici.
        guard LettoreBundle.dentro(file.resolvingSymlinksInPath(), radice: radiceRisolta) else {
            return LettoreBundle.errore(403, "Forbidden")
        }
        let dati: Data
        do {
            dati = try Data(contentsOf: file, options: .mappedIfSafe)
        } catch {
            return LettoreBundle.errore(500, "Internal Server Error")
        }

        let totale = dati.count
        var intestazioni: [String: String] = [
            "Content-Type": LettoreBundle.tipoMime(per: file),
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache",
            "Accept-Ranges": "bytes"
        ]
        let soloIntestazioni = richiesta.httpMethod?.uppercased() == "HEAD"

        switch LettoreBundle.leggiRange(richiesta.value(forHTTPHeaderField: "Range"), dimensione: totale) {
        case .intero:
            intestazioni["Content-Length"] = String(totale)
            return RispostaFile(stato: 200, intestazioni: intestazioni, corpo: soloIntestazioni ? Data() : dati)
        case .parte(let inizio, let fine):
            let pezzo = dati.subdata(in: inizio..<(fine + 1))
            intestazioni["Content-Length"] = String(pezzo.count)
            intestazioni["Content-Range"] = "bytes \(inizio)-\(fine)/\(totale)"
            return RispostaFile(stato: 206, intestazioni: intestazioni, corpo: soloIntestazioni ? Data() : pezzo)
        case .nonSoddisfacibile:
            let base = LettoreBundle.errore(416, "Range Not Satisfiable")
            var conRange = base.intestazioni
            conRange["Content-Range"] = "bytes */\(totale)"
            return RispostaFile(stato: base.stato, intestazioni: conRange, corpo: base.corpo)
        }
    }

    /// Trasforma il path dell'URL in un file dentro la radice del bundle; nil se prova a uscirne.
    private func fileRichiesto(_ url: URL) -> URL? {
        let percorso = url.path  // già senza %xx
        if percorso.contains("\0") { return nil }
        let parti = percorso.split(separator: "/", omittingEmptySubsequences: true).map { String($0) }
        if parti.contains(where: { $0 == ".." || $0 == "." }) { return nil }
        let relativo = parti.isEmpty ? "index.html" : parti.joined(separator: "/")
        let file = radice.appendingPathComponent(relativo).standardizedFileURL
        return LettoreBundle.dentro(file, radice: radice) ? file : nil
    }

    private static func dentro(_ file: URL, radice base: URL) -> Bool {
        var prefisso = base.path
        if !prefisso.hasSuffix("/") { prefisso += "/" }
        return file.path.hasPrefix(prefisso)
    }

    static func errore(_ stato: Int, _ testo: String) -> RispostaFile {
        let corpo = Data(testo.utf8)
        return RispostaFile(stato: stato, intestazioni: [
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": String(corpo.count),
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-cache"
        ], corpo: corpo)
    }

    private static func tipoMime(per file: URL) -> String {
        let tipo = tipiMime[file.pathExtension.lowercased()] ?? "application/octet-stream"
        return tipiTesto.contains(tipo) ? tipo + "; charset=utf-8" : tipo
    }

    /// Legge "Range: bytes=a-b" (solo il primo intervallo). Un header non valido viene ignorato.
    private static func leggiRange(_ valore: String?, dimensione: Int) -> RichiestaRange {
        guard let grezzo = valore?.trimmingCharacters(in: .whitespaces),
              grezzo.lowercased().hasPrefix("bytes=") else { return .intero }
        let elenco = String(grezzo.dropFirst("bytes=".count))
        guard let primo = elenco.split(separator: ",", omittingEmptySubsequences: false).first else { return .intero }
        let parti = String(primo).trimmingCharacters(in: .whitespaces)
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            .map { String($0) }
        guard parti.count == 2 else { return .intero }
        let a = parti[0], b = parti[1]

        if a.isEmpty {
            // "bytes=-N": gli ultimi N byte
            guard let n = Int(b) else { return .intero }
            guard n > 0, dimensione > 0 else { return .nonSoddisfacibile }
            return .parte(max(0, dimensione - n), dimensione - 1)
        }
        guard let inizio = Int(a), inizio >= 0 else { return .intero }
        guard inizio < dimensione else { return .nonSoddisfacibile }
        var fine = dimensione - 1
        if !b.isEmpty {
            guard let f = Int(b), f >= inizio else { return .intero }
            fine = min(f, dimensione - 1)
        }
        return .parte(inizio, fine)
    }
}

// MARK: - Server dello schema app://

/// Serve i file della radice del bundle (dove il workflow copia www/) sullo schema app://.
final class GestoreFileBundle: NSObject, WKURLSchemeHandler {
    private let lettore = LettoreBundle(radice: Bundle.main.resourceURL ?? Bundle.main.bundleURL)
    private let coda = DispatchQueue(label: "it.settorezero.file", qos: .userInitiated, attributes: .concurrent)
    /// Task ancora in corso (usato SOLO sul main thread). Un task fermato viene tolto:
    /// chiamare didReceive su un task fermato fa crashare l'app.
    private var attivi = Set<ObjectIdentifier>()

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let richiesta = urlSchemeTask.request
        guard let url = richiesta.url else {
            urlSchemeTask.didFailWithError(NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: nil))
            return
        }
        let id = ObjectIdentifier(urlSchemeTask)
        attivi.insert(id)
        let lettore = self.lettore
        // Lettura del file fuori dal main thread; consegna sul main thread.
        coda.async { [weak self] in
            let risposta = lettore.risposta(per: richiesta, url: url)
            DispatchQueue.main.async {
                guard let self = self, self.attivi.remove(id) != nil else { return }  // fermato: non toccarlo
                GestoreFileBundle.consegna(risposta, url: url, a: urlSchemeTask)
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        attivi.remove(ObjectIdentifier(urlSchemeTask))
    }

    /// Chiamata solo sul main thread e solo per task ancora attivi.
    private static func consegna(_ risposta: RispostaFile, url: URL, a task: WKURLSchemeTask) {
        if let http = HTTPURLResponse(url: url, statusCode: risposta.stato,
                                      httpVersion: "HTTP/1.1", headerFields: risposta.intestazioni) {
            task.didReceive(http)
        } else {
            task.didReceive(URLResponse(url: url, mimeType: risposta.intestazioni["Content-Type"],
                                        expectedContentLength: risposta.corpo.count, textEncodingName: nil))
        }
        if !risposta.corpo.isEmpty {
            task.didReceive(risposta.corpo)
        }
        task.didFinish()
    }
}

// MARK: - Proxy debole per i messaggi JS (evita il retain cycle con WKUserContentController)

final class ProxyMessaggiDebole: NSObject, WKScriptMessageHandler {
    weak var bersaglio: WKScriptMessageHandler?

    init(_ bersaglio: WKScriptMessageHandler) {
        self.bersaglio = bersaglio
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        bersaglio?.userContentController(userContentController, didReceive: message)
    }
}

// MARK: - Schermata del gioco

final class GameVC: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private enum Fase {
        case avvio
        case letturaVecchiDati
        case gioco
    }

    private var web: WKWebView!
    private var contenuti: WKUserContentController!
    private var gestoreFile: GestoreFileBundle!
    private let impostazioni = UserDefaults.standard
    private var fase = Fase.avvio

    override func loadView() {
        let gestore = GestoreFileBundle()
        let controller = WKUserContentController()
        let proxy = ProxyMessaggiDebole(self)
        controller.add(proxy, name: Messaggi.datiVecchi)
        controller.add(proxy, name: Messaggi.conferma)
        gestoreFile = gestore
        contenuti = controller

        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        // Stesso archivio persistente per la vecchia origine file:// e la nuova app://
        cfg.websiteDataStore = WKWebsiteDataStore.default()
        cfg.setURLSchemeHandler(gestore, forURLScheme: Schema.nome)
        cfg.userContentController = controller

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
        if impostazioni.bool(forKey: Chiavi.migrazioneFatta) {
            caricaGioco()
            return
        }
        // Salvataggi non ancora trasferiti: leggo il localStorage della vecchia origine file://
        guard let pagina = Bundle.main.url(forResource: "migra", withExtension: "html") else {
            letturaFinita(dati: nil)
            return
        }
        fase = .letturaVecchiDati
        web.loadFileURL(pagina, allowingReadAccessTo: pagina.deletingLastPathComponent())
        perform(#selector(letturaScaduta), with: nil, afterDelay: attesaMassimaLettura)
    }

    /// migra.html non ha risposto in tempo: si gioca lo stesso (con la copia di riserva, se c'è).
    @objc private func letturaScaduta() {
        if fase == .letturaVecchiDati { letturaFinita(dati: nil) }
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    // MARK: Avvio e trasferimento

    private func caricaGioco() {
        fase = .gioco
        guard let url = URL(string: Schema.paginaIniziale) else { return }
        web.load(URLRequest(url: url))
    }

    /// dati = chiavi lette da migra.html (anche vuoto); nil = lettura fallita o scaduta.
    private func letturaFinita(dati letti: [String: String]?) {
        guard fase != .gioco else { return }
        fase = .gioco

        if let letti = letti, !letti.isEmpty, let json = GameVC.testoJSON(letti) {
            impostazioni.set(json, forKey: Chiavi.copiaRiserva)
        }
        var daTrasferire = letti
        if daTrasferire?.isEmpty ?? true,
           let riserva = impostazioni.string(forKey: Chiavi.copiaRiserva),
           let datiRiserva = GameVC.dizionario(daJSON: riserva) {
            daTrasferire = datiRiserva
        }
        // Lettura fallita e nessuna copia: niente script, il flag resta falso e si riprova al prossimo avvio.
        if let dati = daTrasferire, let sorgente = GameVC.scriptTrasferimento(dati) {
            contenuti.addUserScript(WKUserScript(source: sorgente, injectionTime: .atDocumentStart,
                                                 forMainFrameOnly: true))
        }
        caricaGioco()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame else { return }
        switch message.name {
        case Messaggi.datiVecchi:
            guard fase == .letturaVecchiDati, let testo = message.body as? String else { return }
            letturaFinita(dati: GameVC.datiDaMigra(testo))
        case Messaggi.conferma:
            guard let testo = message.body as? String, GameVC.confermaRiuscita(testo) else { return }
            impostazioni.set(true, forKey: Chiavi.migrazioneFatta)
            // Da qui in poi non serve più: evita di riscrivere i vecchi dati se la pagina si ricarica.
            contenuti.removeAllUserScripts()
        default:
            break
        }
    }

    // MARK: Navigazione

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if fase == .letturaVecchiDati { letturaFinita(dati: nil) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if fase == .letturaVecchiDati { letturaFinita(dati: nil) }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Il processo web è morto (es. troppa memoria): invece di restare su uno schermo nero, ricarico.
        if fase == .letturaVecchiDati {
            letturaFinita(dati: nil)
        } else {
            caricaGioco()
        }
    }

    // MARK: JSON

    /// Messaggio di migra.html: {"dati": {chiave: valore}, "errore": null | "testo"}.
    private static func datiDaMigra(_ testo: String) -> [String: String]? {
        guard let busta = oggettoJSON(testo), let grezzi = busta["dati"] as? [String: Any] else { return nil }
        let dati = soloStringhe(grezzi)
        if dati.isEmpty, busta["errore"] is String { return nil }
        return dati
    }

    private static func confermaRiuscita(_ testo: String) -> Bool {
        return (oggettoJSON(testo)?["ok"] as? Bool) == true
    }

    private static func dizionario(daJSON testo: String) -> [String: String]? {
        guard let grezzi = oggettoJSON(testo) else { return nil }
        return soloStringhe(grezzi)
    }

    private static func oggettoJSON(_ testo: String) -> [String: Any]? {
        guard let dati = testo.data(using: .utf8),
              let oggetto = try? JSONSerialization.jsonObject(with: dati, options: []) else { return nil }
        return oggetto as? [String: Any]
    }

    private static func soloStringhe(_ grezzi: [String: Any]) -> [String: String] {
        var risultato: [String: String] = [:]
        for (chiave, valore) in grezzi {
            if let s = valore as? String { risultato[chiave] = s }
        }
        return risultato
    }

    private static func testoJSON(_ valore: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(valore),
              let dati = try? JSONSerialization.data(withJSONObject: valore, options: []) else { return nil }
        return String(data: dati, encoding: .utf8)
    }

    /// Script iniettato a inizio documento nella pagina app:// (prima di dati.js): scrive ogni vecchia
    /// chiave SOLO se non esiste già, segna sz_migrato='1' e conferma a Swift.
    /// I dati sono codificati due volte: JSON dell'oggetto, poi JSON di [quel testo], così nel JS
    /// arrivano come stringa letterale sicura (apici, backslash, a capo, emoji) e poi JSON.parse.
    private static func scriptTrasferimento(_ dati: [String: String]) -> String? {
        guard let interno = testoJSON(dati), var letterale = testoJSON([interno]) else { return nil }
        // U+2028/U+2029 non sono ammessi nelle stringhe JS dei motori più vecchi.
        letterale = letterale
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return """
        (function () {
          var invia = function (esito) {
            try { window.webkit.messageHandlers.\(Messaggi.conferma).postMessage(JSON.stringify(esito)); } catch (e) {}
          };
          try {
            var ls = window.localStorage;
            var scritte = 0;
            if (ls.getItem('sz_migrato') !== '1') {
              var dati = JSON.parse(\(letterale)[0]);
              for (var k in dati) {
                if (!Object.prototype.hasOwnProperty.call(dati, k)) continue;
                if (k === 'sz_migrato' || typeof dati[k] !== 'string') continue;
                if (ls.getItem(k) === null) { ls.setItem(k, dati[k]); scritte++; }
              }
              ls.setItem('sz_migrato', '1');
            }
            invia({ ok: true, scritte: scritte });
          } catch (e) {
            invia({ ok: false, errore: String(e) });
          }
        })();
        """
    }
}

// MARK: - App

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
