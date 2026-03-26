import Foundation
import MultipeerConnectivity

// MARK: - Message Model
struct MeshMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let senderID: String
    let senderName: String
    let content: String
    let type: MessageType
    let timestamp: Date
    var aiResponse: String?

    enum MessageType: String, Codable {
        case userMessage      // Messaggio normale
        case aiRequest        // Richiesta AI in attesa
        case aiResponse       // Risposta AI ricevuta
        case systemInfo       // Messaggio di sistema
        case cancelAIRequest  // Cancella richieste AI pendenti
    }

    init(id: UUID = UUID(), senderID: String, senderName: String, content: String, type: MessageType, aiResponse: String? = nil) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.aiResponse = aiResponse
    }
}

// MARK: - Peer Model
struct MeshPeer: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String
    var isConnected: Bool
    var hasInternet: Bool

    var name: String { displayName }
}

// MARK: - Room Model
struct Room: Identifiable {
    let id: String
    let name: String
    var peers: [MeshPeer]
    var messages: [MeshMessage]

    init(name: String) {
        self.id = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.name = name
        self.peers = []
        self.messages = []
    }
}

// MARK: - Network Payload (what we send over Multipeer)
struct NetworkPayload: Codable {
    let type: PayloadType
    let message: MeshMessage?
    let cancelRequestID: UUID?    // ID della richiesta AI da cancellare
    let senderHasInternet: Bool

    enum PayloadType: String, Codable {
        case newMessage
        case aiResponse
        case cancelAIRequest
        case peerStatus
    }
}
