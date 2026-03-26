import Foundation
import Combine
import SwiftUI

// MARK: - RoomViewModel
// Coordina: rete mesh, richieste AI, stato UI
@MainActor
class RoomViewModel: ObservableObject {

    // MARK: - Published
    @Published var messages: [MeshMessage] = []
    @Published var connectedPeersCount: Int = 0
    @Published var isSearchingPeers: Bool = false
    @Published var pendingAIRequests: Set<UUID> = []   // Richieste AI in attesa
    @Published var isWaitingForAI: Bool = false
    @Published var hasInternet: Bool = false

    // MARK: - Services
    private let network: MeshNetworkManager
    private let aiService = GeminiService()

    // MARK: - State
    private var currentQuestion: String = ""
    private var myAIRequestID: UUID? = nil

    // MARK: - Init
    init(userName: String) {
        self.network = MeshNetworkManager(userName: userName)
        setupCallbacks()
    }

    // MARK: - Setup Callbacks
    private func setupCallbacks() {

        // Nuovo messaggio ricevuto da un peer
        network.onMessageReceived = { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                self.addMessage(message)

                // Se è una richiesta AI, provo anch'io a rispondere
                if message.type == .aiRequest {
                    await self.tryRespondToAIRequest(message)
                }
            }
        }

        // Risposta AI ricevuta da un peer
        network.onAIResponseReceived = { [weak self] message in
            guard let self else { return }
            Task { @MainActor in
                // Cancella nostra richiesta pendente
                self.isWaitingForAI = false
                self.myAIRequestID = nil
                self.pendingAIRequests.removeAll()
                self.addMessage(message)
            }
        }

        // Cancella una richiesta AI specifica
        network.onCancelAIRequest = { [weak self] reqID in
            guard let self else { return }
            Task { @MainActor in
                self.pendingAIRequests.remove(reqID)
                if self.myAIRequestID == reqID {
                    self.isWaitingForAI = false
                    self.myAIRequestID = nil
                }
            }
        }

        // Osserva i peer connessi
        network.$connectedPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                self?.connectedPeersCount = peers.count
            }
            .store(in: &cancellables)

        network.$isSearching
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSearchingPeers)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Join Room
    func joinRoom(_ roomID: String) {
        network.joinRoom(roomID: roomID)

        // Controlla connessione internet periodicamente
        Task {
            await checkInternetLoop()
        }
    }

    func leaveRoom() {
        network.leaveRoom()
    }

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        let message = MeshMessage(
            senderID: network.localPeerID.displayName,
            senderName: network.localPeerName,
            content: text,
            type: .userMessage
        )
        addMessage(message)

        let payload = NetworkPayload(
            type: .newMessage,
            message: message,
            cancelRequestID: nil,
            senderHasInternet: hasInternet
        )
        network.broadcast(payload: payload)
    }

    // MARK: - Send AI Question
    // 1. Manda la domanda a tutti come richiesta AI
    // 2. Ogni device prova a rispondere se ha internet
    func sendAIQuestion(_ question: String) {
        currentQuestion = question
        let requestID = UUID()
        myAIRequestID = requestID

        let requestMessage = MeshMessage(
            id: requestID,
            senderID: network.localPeerID.displayName,
            senderName: network.localPeerName,
            content: question,
            type: .aiRequest
        )

        addMessage(requestMessage)
        pendingAIRequests.insert(requestID)
        isWaitingForAI = true

        // Broadcast la richiesta a tutti
        let payload = NetworkPayload(
            type: .newMessage,
            message: requestMessage,
            cancelRequestID: nil,
            senderHasInternet: hasInternet
        )
        network.broadcast(payload: payload)

        // Provo anch'io a rispondere
        Task {
            await tryAnswerAI(requestID: requestID, question: question)
        }
    }

    // MARK: - Try to Answer AI Request (ricevuto da un peer)
    private func tryRespondToAIRequest(_ request: MeshMessage) async {
        pendingAIRequests.insert(request.id)

        // Provo a rispondere solo se ho internet
        guard hasInternet else { return }

        await tryAnswerAI(requestID: request.id, question: request.content)
    }

    // MARK: - Core: Try to Call AI
    private func tryAnswerAI(requestID: UUID, question: String) async {
        // Doppio check internet
        let online = await aiService.hasInternetConnection()
        guard online else { return }

        // Verifica che la richiesta sia ancora pendente
        guard pendingAIRequests.contains(requestID) else { return }

        do {
            let answer = try await aiService.ask(question: question)

            // Sono il primo ad avere risposta!
            // 1. Rimuovo la richiesta localmente
            pendingAIRequests.remove(requestID)
            isWaitingForAI = false
            myAIRequestID = nil

            // 2. Creo il messaggio risposta
            let responseMessage = MeshMessage(
                senderID: network.localPeerID.displayName,
                senderName: network.localPeerName,
                content: answer,
                type: .aiResponse,
                aiResponse: answer
            )
            addMessage(responseMessage)

            // 3. Mando la risposta AI a tutti i peer
            let aiPayload = NetworkPayload(
                type: .aiResponse,
                message: responseMessage,
                cancelRequestID: nil,
                senderHasInternet: true
            )
            network.broadcast(payload: aiPayload)

            // 4. Mando anche il "cancella richiesta" per quella specifica domanda
            let cancelPayload = NetworkPayload(
                type: .cancelAIRequest,
                message: nil,
                cancelRequestID: requestID,
                senderHasInternet: true
            )
            network.broadcast(payload: cancelPayload)

        } catch {
            // Non riuscito — qualcun altro proverà
            print("AI request failed: \(error)")
        }
    }

    // MARK: - Internet Check Loop
    private func checkInternetLoop() async {
        while !Task.isCancelled {
            let online = await aiService.hasInternetConnection()
            hasInternet = online  // già su @MainActor
            try? await Task.sleep(nanoseconds: 10_000_000_000) // ogni 10 secondi
        }
    }

    // MARK: - Add Message (dedup)
    private func addMessage(_ message: MeshMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
    }

    // MARK: - Helpers
    var localUserName: String { network.localPeerName }
    var localUserID: String { network.localPeerID.displayName }
}
