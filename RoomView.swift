import SwiftUI

// MARK: - RoomView
struct RoomView: View {
    let roomName: String
    let userName: String

    @StateObject private var viewModel: RoomViewModel
    @State private var inputText: String = ""
    @State private var isAIMode: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    init(roomName: String, userName: String) {
        self.roomName = roomName
        self.userName = userName
        _viewModel = StateObject(wrappedValue: RoomViewModel(userName: userName))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            StatusBarView(viewModel: viewModel)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromMe: message.senderID == viewModel.localUserID
                            )
                            .id(message.id)
                        }

                        // AI waiting indicator
                        if viewModel.isWaitingForAI {
                            AIWaitingView()
                                .id("ai-waiting")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: viewModel.isWaitingForAI) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            Divider()

            // Input area
            InputAreaView(
                inputText: $inputText,
                isAIMode: $isAIMode,
                onSend: sendMessage,
                isWaiting: viewModel.isWaitingForAI
            )
        }
        .navigationTitle(roomName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PeersIndicator(count: viewModel.connectedPeersCount, isSearching: viewModel.isSearchingPeers)
            }
        }
        .onAppear {
            let roomID = roomName.lowercased().replacingOccurrences(of: " ", with: "-")
            viewModel.joinRoom(roomID)
        }
        .onDisappear {
            viewModel.leaveRoom()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        if isAIMode {
            viewModel.sendAIQuestion(text)
        } else {
            viewModel.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if viewModel.isWaitingForAI {
                proxy.scrollTo("ai-waiting", anchor: .bottom)
            } else if let last = viewModel.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Status Bar
struct StatusBarView: View {
    @ObservedObject var viewModel: RoomViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Peer count
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Text("\(viewModel.connectedPeersCount) connessi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Internet status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.hasInternet ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.hasInternet ? "Internet" : "Offline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Pending AI requests
            if !viewModel.pendingAIRequests.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("\(viewModel.pendingAIRequests.count) in attesa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Peers Indicator
struct PeersIndicator: View {
    let count: Int
    let isSearching: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isSearching {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(count > 0 ? .blue : .gray)
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: MeshMessage
    let isFromMe: Bool

    var body: some View {
        HStack {
            if isFromMe { Spacer(minLength: 60) }

            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                // Sender name (not for system messages)
                if message.type != .systemInfo && !isFromMe {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                // Bubble
                VStack(alignment: .leading, spacing: 6) {
                    // AI request badge
                    if message.type == .aiRequest {
                        Label("Domanda all'AI", systemImage: "brain.head.profile")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }

                    Text(message.content)
                        .font(message.type == .systemInfo ? .caption : .body)
                        .foregroundStyle(message.type == .systemInfo ? .secondary : bubbleTextColor)

                    // AI response badge
                    if message.type == .aiResponse {
                        Label("Risposta AI via \(message.senderName)", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleColor)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Timestamp
                if message.type != .systemInfo {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
            }

            if !isFromMe { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }

    var bubbleColor: Color {
        switch message.type {
        case .systemInfo: return .clear
        case .aiRequest: return Color.purple.opacity(0.15)
        case .aiResponse: return Color.green.opacity(0.15)
        case .userMessage: return isFromMe ? .blue : Color(.secondarySystemBackground)
        case .cancelAIRequest: return .clear
        }
    }

    var bubbleTextColor: Color {
        if isFromMe && message.type == .userMessage {
            return .white
        }
        return .primary
    }
}

// MARK: - AI Waiting View
struct AIWaitingView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2), value: animating)
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("In attesa di risposta AI…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .onAppear { animating = true }
    }
}

// MARK: - Input Area
struct InputAreaView: View {
    @Binding var inputText: String
    @Binding var isAIMode: Bool
    let onSend: () -> Void
    let isWaiting: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Mode toggle
            HStack {
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        isAIMode = false
                    }
                } label: {
                    Label("Messaggio", systemImage: "message.fill")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(!isAIMode ? Color.blue : Color.clear)
                        .foregroundStyle(!isAIMode ? .white : .secondary)
                        .clipShape(Capsule())
                }

                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        isAIMode = true
                    }
                } label: {
                    Label("Chiedi all'AI", systemImage: "brain.head.profile")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isAIMode ? Color.purple : Color.clear)
                        .foregroundStyle(isAIMode ? .white : .secondary)
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Text input + send
            HStack(spacing: 8) {
                TextField(
                    isAIMode ? "Fai una domanda all'AI…" : "Scrivi un messaggio…",
                    text: $inputText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button(action: onSend) {
                    Image(systemName: isAIMode ? "brain.head.profile" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? (isAIMode ? .purple : .blue) : .gray)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isWaiting
    }
}
