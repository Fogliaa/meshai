import Foundation
import MultipeerConnectivity
import Combine

// MARK: - MeshNetworkManager
// Gestisce la rete mesh tramite MultipeerConnectivity (Bluetooth + WiFi P2P)
class MeshNetworkManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var connectedPeers: [MCPeerID] = []
    @Published var receivedMessages: [MeshMessage] = []
    @Published var pendingAIRequestID: UUID? = nil   // Nostra richiesta AI in attesa
    @Published var isSearching: Bool = false

    // MARK: - Callbacks
    var onMessageReceived: ((MeshMessage) -> Void)?
    var onAIResponseReceived: ((MeshMessage) -> Void)?
    var onCancelAIRequest: ((UUID) -> Void)?

    // MARK: - Multipeer Setup
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser

    private let serviceType = "meshai-room"   // max 15 chars, solo [a-z0-9\-]
    private var currentRoomID: String = ""

    // MARK: - Init
    init(userName: String) {
        self.peerID = MCPeerID(displayName: userName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)

        // Usa roomID come discovery info per filtrare stanze
        self.advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        self.browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)

        super.init()

        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self
    }

    // MARK: - Join / Leave Room
    func joinRoom(roomID: String) {
        leaveRoom()
        currentRoomID = roomID

        // Ricrea advertiser con roomID nei discovery info
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["roomID": roomID],
            serviceType: serviceType
        )
        advertiser.delegate = self

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser.delegate = self

        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        isSearching = true
    }

    func leaveRoom() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeers = []
        isSearching = false
        currentRoomID = ""
    }

    // MARK: - Send Message to All Peers
    func broadcast(payload: NetworkPayload) {
        guard !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Broadcast error: \(error)")
        }
    }

    // MARK: - Helpers
    var localPeerID: MCPeerID { peerID }
    var localPeerName: String { peerID.displayName }

    var connectedPeerCount: Int { session.connectedPeers.count }
}

// MARK: - MCSessionDelegate
extension MeshNetworkManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.connectedPeers = session.connectedPeers
            let statusMsg = MeshMessage(
                senderID: "system",
                senderName: "Sistema",
                content: state == .connected
                    ? "📡 \(peerID.displayName) si è unito alla stanza"
                    : "👋 \(peerID.displayName) ha lasciato la stanza",
                type: .systemInfo
            )
            self.onMessageReceived?(statusMsg)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let payload = try? JSONDecoder().decode(NetworkPayload.self, from: data) else { return }

        DispatchQueue.main.async {
            switch payload.type {

            case .newMessage:
                // Messaggio normale — propagalo in UI e ritenta AI se necessario
                if let msg = payload.message {
                    self.onMessageReceived?(msg)
                }

            case .aiResponse:
                // Qualcuno ha avuto risposta dall'AI → cancella nostra richiesta pendente
                if let msg = payload.message {
                    self.pendingAIRequestID = nil
                    self.onAIResponseReceived?(msg)
                }

            case .cancelAIRequest:
                // Cancella una richiesta AI specifica
                if let reqID = payload.cancelRequestID {
                    if self.pendingAIRequestID == reqID {
                        self.pendingAIRequestID = nil
                    }
                    self.onCancelAIRequest?(reqID)
                }

            case .peerStatus:
                break
            }
        }
    }

    // Unused delegates required by protocol
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension MeshNetworkManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Controlla che il peer sia nella stessa stanza
        if let ctx = context, let info = try? JSONDecoder().decode([String: String].self, from: ctx) {
            let theirRoom = info["roomID"] ?? ""
            invitationHandler(theirRoom == currentRoomID, session)
        } else {
            // Accetta comunque (il browser invia il roomID nel contesto)
            invitationHandler(true, session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension MeshNetworkManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Invita solo peer nella stessa stanza
        let theirRoom = info?["roomID"] ?? ""
        guard theirRoom == currentRoomID else { return }

        // Manda il nostro roomID come contesto dell'invito
        let contextData = try? JSONEncoder().encode(["roomID": currentRoomID])
        browser.invitePeer(peerID, to: session, withContext: contextData, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.connectedPeers = self.session.connectedPeers
        }
    }
}
