# MeshAI — Chat offline con AI condivisa

App iOS per comunicare in situazioni di emergenza senza internet,  
con intelligenza artificiale condivisa via rete mesh Bluetooth/WiFi.

---

## Come funziona

```
Dispositivo A ──── Bluetooth/WiFi P2P ──── Dispositivo B
     │                                          │
     │  "Dove sono i soccorsi?"                │
     │ ─────────────────────────────────────> │
     │                                          │
     │  [A prova internet: NO]                  │
     │  [B prova internet: SÌ] ──> Gemini AI   │
     │                          <── risposta    │
     │  <─── risposta AI (broadcast) ──────── │
     │  <─── cancella richiesta pendente ────  │
```

1. I dispositivi si scoprono automaticamente nella stessa stanza via **Multipeer Connectivity** (Bluetooth + WiFi Direct)
2. Un utente manda una domanda → tutti i peer la ricevono
3. **Ogni dispositivo** tenta di contattare l'AI se ha connessione internet
4. Il **primo** che riesce manda la risposta a tutti + cancella le richieste pendenti degli altri
5. Nessuno spreca banda: una sola richiesta AI arriva a destinazione

---

## Setup Xcode

### 1. Crea il progetto
- Xcode → File → New → Project
- Scegli **App** (SwiftUI, Swift)
- Product Name: `MeshAI`
- Bundle Identifier: `com.tuonome.meshai`

### 2. Aggiungi i file
Copia tutti i `.swift` di questa cartella nel progetto Xcode.  
Sostituisci il `ContentView.swift` generato automaticamente.

### 3. Configura Info.plist
Aggiungi le chiavi dal file `Info.plist` incluso al tuo `Info.plist` del progetto,  
oppure sostituiscilo interamente.

In alternativa, in Xcode vai su:  
**Target → Info → Custom iOS Target Properties** e aggiungi:
- `NSBluetoothAlwaysUsageDescription` → stringa descrittiva
- `NSLocalNetworkUsageDescription` → stringa descrittiva  
- `NSBonjourServices` → Array con `_meshai-room._tcp` e `_meshai-room._udp`

### 4. Ottieni la chiave API Gemini (GRATUITA)
1. Vai su https://aistudio.google.com/app/apikey
2. Fai login con Google
3. Clicca "Create API Key"
4. Copia la chiave

In `GeminiService.swift`, sostituisci:
```swift
private let apiKey = "INSERISCI_QUI_LA_TUA_API_KEY_GEMINI"
```
con:
```swift
private let apiKey = "AIzaSy...la_tua_chiave..."
```

### 5. Build & Run
- Serve un **iPhone fisico** (il simulatore non supporta Multipeer Connectivity)
- Installa su 2+ iPhone per testare la rete mesh
- Firma il codice con il tuo Apple ID in Xcode → Signing & Capabilities

---

## Limiti gratuiti Gemini API
| Piano | Limite |
|-------|--------|
| Gratuito | 15 richieste/minuto |
| Gratuito | 1.500 richieste/giorno |
| Gratuito | Nessuna carta di credito |

Perfetto per uso di emergenza!

---

## Struttura del codice

```
MeshAI/
├── MeshAIApp.swift          # Entry point
├── Models.swift             # Strutture dati (MeshMessage, NetworkPayload...)
├── MeshNetworkManager.swift # Bluetooth/WiFi mesh via MultipeerConnectivity
├── GeminiService.swift      # Client API Gemini (gratuita)
├── RoomViewModel.swift      # Logica: coordina rete + AI
├── ContentView.swift        # Home: selezione nome e stanze
├── RoomView.swift           # Chat UI dentro una stanza
└── Info.plist               # Permessi necessari
```

---

## Note tecniche

### MultipeerConnectivity
Apple's framework built-in che usa automaticamente:
- **Bluetooth LE** per la discovery dei peer
- **WiFi Direct** (se disponibile) per trasferimento dati più veloce
- Funziona senza router, senza internet, senza infrastruttura

### Logica "first responder"
Ogni dispositivo tenta la chiamata AI in parallelo.  
Il primo che risponde vince e cancella le richieste degli altri.  
Questo massimizza la probabilità di avere una risposta anche con segnale scarso.

### Sicurezza
La sessione Multipeer usa `.required` encryption — i messaggi sono crittografati tra i peer.

---

## Possibili miglioramenti futuri
- [ ] Messaggi vocali (più utile in emergenza)
- [ ] Mappa offline dei peer (triangolazione Bluetooth)
- [ ] Cache delle risposte AI (riutilizzabile offline)
- [ ] Watchdog: se il "first responder" sparisce, il prossimo riprende la richiesta
- [ ] Supporto Android (via Nearby Connections API)
