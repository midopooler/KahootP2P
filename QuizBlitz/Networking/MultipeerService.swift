import Foundation
import CouchbaseLiteSwift
import Combine

enum PeerRole {
    case host
    case client
}

final class P2PService: NSObject, ObservableObject {
    private let db: Database
    private let collection: Collection

    private var listener: URLEndpointListener?
    private var replicator: Replicator?
    private var replicatorToken: ListenerToken?

    private var netServiceBrowser: NetServiceBrowser?
    private var publishService: NetService?
    private var resolvingServices: [NetService] = []

    @Published var discoveredHosts: [(name: String, host: String, port: Int)] = []
    @Published var connectedPeerCount: Int = 0
    @Published var isConnected = false
    @Published var listenerPort: UInt16 = 0

    var role: PeerRole = .client

    var onDocumentsReplicated: (() -> Void)?

    private static let bonjourType = "_quizblitz._tcp."
    private static let bonjourDomain = ""

    init(database: Database, collection: Collection) {
        self.db = database
        self.collection = collection
        super.init()
    }

    // MARK: - Host: start URLEndpointListener + advertise via Bonjour

    func startHosting(gameId: String) throws {
        role = .host

        var listenerConfig = URLEndpointListenerConfiguration(collections: [collection])
        listenerConfig.port = 0
        listenerConfig.disableTLS = true

        let urlListener = URLEndpointListener(config: listenerConfig)
        try urlListener.start()
        self.listener = urlListener

        let port = urlListener.port ?? 0
        self.listenerPort = port

        print("[P2PService] Host: URLEndpointListener started on port \(port)")

        let service = NetService(
            domain: Self.bonjourDomain,
            type: Self.bonjourType,
            name: "QuizBlitz-\(gameId.prefix(8))",
            port: Int32(port)
        )
        service.delegate = self
        service.publish()
        self.publishService = service

        print("[P2PService] Host: Publishing Bonjour service type='\(Self.bonjourType)' name='QuizBlitz-\(gameId.prefix(8))' port=\(port)")
    }

    func stopHosting() {
        listener?.stop()
        listener = nil
        publishService?.stop()
        publishService = nil
        listenerPort = 0
    }

    // MARK: - Client: browse for hosts via Bonjour

    func startBrowsing() {
        role = .client
        discoveredHosts = []

        print("[P2PService] Client: Starting Bonjour browse for type='\(Self.bonjourType)'")

        let browser = NetServiceBrowser()
        browser.delegate = self
        self.netServiceBrowser = browser
        browser.searchForServices(ofType: Self.bonjourType, inDomain: Self.bonjourDomain)
    }

    func stopBrowsing() {
        netServiceBrowser?.stop()
        netServiceBrowser = nil
    }

    // MARK: - Client: connect to host via Replicator

    func connectToHost(host: String, port: Int) {
        let scheme = "ws"
        guard let url = URL(string: "\(scheme)://\(host):\(port)/\(db.name)") else {
            print("[P2PService] Invalid URL")
            return
        }

        let targetEndpoint = URLEndpoint(url: url)

        let colConfig = CollectionConfiguration(collection: collection)
        var config = ReplicatorConfiguration(collections: [colConfig], target: targetEndpoint)
        config.replicatorType = .pushAndPull
        config.continuous = true

        let repl = Replicator(config: config)

        replicatorToken = repl.addChangeListener { [weak self] (change: ReplicatorChange) in
            DispatchQueue.main.async {
                let status = change.status
                print("[P2PService] Replicator status: \(status.activity)")
                switch status.activity {
                case .connecting:
                    self?.isConnected = false
                case .idle, .busy:
                    self?.isConnected = true
                    self?.onDocumentsReplicated?()
                case .stopped, .offline:
                    self?.isConnected = false
                @unknown default:
                    break
                }

                if let error = status.error {
                    print("[P2PService] Replication error: \(error.localizedDescription)")
                }
            }
        }

        repl.start()
        self.replicator = repl
        print("[P2PService] Client: Replicator connecting to \(url)")
    }

    // MARK: - Disconnect

    func disconnect() {
        stopHosting()
        stopBrowsing()
        replicatorToken?.remove()
        replicator?.stop()
        replicator = nil
        replicatorToken = nil
        isConnected = false
        connectedPeerCount = 0
    }
}

// MARK: - NetServiceBrowserDelegate

extension P2PService: NetServiceBrowserDelegate {
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        print("[P2PService] Browser: Will search")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("[P2PService] Browser: Did stop search")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[P2PService] Browser: Found service '\(service.name)' type='\(service.type)' domain='\(service.domain)' moreComing=\(moreComing)")
        resolvingServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 10)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("[P2PService] Browser: Lost service '\(service.name)'")
        DispatchQueue.main.async {
            self.discoveredHosts.removeAll { $0.name == service.name }
        }
        resolvingServices.removeAll { $0 == service }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("[P2PService] Browser: Did NOT search, error: \(errorDict)")
    }
}

// MARK: - NetServiceDelegate

extension P2PService: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        print("[P2PService] Publish: Service '\(sender.name)' published successfully on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("[P2PService] Publish: FAILED for '\(sender.name)', error: \(errorDict)")
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let hostName = sender.hostName else {
            print("[P2PService] Resolve: No hostname for '\(sender.name)'")
            return
        }
        let port = sender.port
        print("[P2PService] Resolve: '\(sender.name)' -> host=\(hostName) port=\(port)")
        DispatchQueue.main.async {
            if !self.discoveredHosts.contains(where: { $0.name == sender.name }) {
                self.discoveredHosts.append((name: sender.name, host: hostName, port: port))
                print("[P2PService] Resolve: Added to discoveredHosts, count=\(self.discoveredHosts.count)")
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("[P2PService] Resolve: FAILED for '\(sender.name)', error: \(errorDict)")
    }
}
