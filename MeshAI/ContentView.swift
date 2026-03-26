import SwiftUI

// MARK: - ContentView (Home)
struct ContentView: View {
    @AppStorage("userName") private var userName: String = ""
    @State private var showNameSetup: Bool = false
    @State private var showRoomList: Bool = false

    var body: some View {
        Group {
            if userName.isEmpty {
                NameSetupView(userName: $userName)
            } else {
                RoomListView(userName: userName)
            }
        }
    }
}

// MARK: - NameSetupView
struct NameSetupView: View {
    @Binding var userName: String
    @State private var inputName: String = ""

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("MeshAI")
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("Chat offline con intelligenza artificiale\ncondivisa via Bluetooth")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Name input
                VStack(spacing: 16) {
                    Text("Come ti chiami?")
                        .font(.headline)

                    TextField("Il tuo nome", text: $inputName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 32)

                    Button {
                        let trimmed = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            userName = trimmed
                        }
                    } label: {
                        Label("Inizia", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(inputName.isEmpty ? Color.gray : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 32)
                    }
                    .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
        }
    }
}

// MARK: - RoomListView
struct RoomListView: View {
    let userName: String
    @State private var newRoomName: String = ""
    @State private var rooms: [String] = ["Emergenza", "Soccorso", "Generale"]
    @State private var showAddRoom: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // Stanze disponibili
                Section("Stanze disponibili") {
                    ForEach(rooms, id: \.self) { room in
                        NavigationLink(value: room) {
                            Label(room, systemImage: "antenna.radiowaves.left.and.right")
                                .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indices in
                        rooms.remove(atOffsets: indices)
                    }
                }

                // Aggiungi stanza
                Section {
                    Button {
                        showAddRoom = true
                    } label: {
                        Label("Nuova stanza", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }

                // Info
                Section("Come funziona") {
                    InfoRow(icon: "dot.radiowaves.left.and.right", color: .blue, text: "Connessione via Bluetooth e WiFi diretto — niente internet necessario")
                    InfoRow(icon: "brain.head.profile", color: .purple, text: "Il primo dispositivo con campo invia la domanda all'AI e condivide la risposta con tutti")
                    InfoRow(icon: "exclamationmark.triangle.fill", color: .orange, text: "Ideale per emergenze con scarsa connettività")
                }
            }
            .navigationTitle("MeshAI")
            .navigationDestination(for: String.self) { room in
                RoomView(roomName: room, userName: userName)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddRoom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Text("👤 \(userName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .alert("Nuova stanza", isPresented: $showAddRoom) {
                TextField("Nome stanza", text: $newRoomName)
                Button("Crea") {
                    let name = newRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty && !rooms.contains(name) {
                        rooms.append(name)
                    }
                    newRoomName = ""
                }
                Button("Annulla", role: .cancel) { newRoomName = "" }
            } message: {
                Text("Scegli un nome per la stanza")
            }
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
