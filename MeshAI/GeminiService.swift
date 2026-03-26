import Foundation

// MARK: - GeminiService
// Usa Gemini 1.5 Flash — API gratuita (15 req/min, no carta di credito)
// Ottieni la tua chiave gratis su: https://aistudio.google.com/app/apikey
class GeminiService {

    // ⚠️ SOSTITUISCI con la tua chiave gratuita da https://aistudio.google.com/app/apikey
    private let apiKey = "INSERISCI_QUI_LA_TUA_API_KEY_GEMINI"

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    // MARK: - Ask AI
    func ask(question: String) async throws -> String {
        let url = URL(string: "\(baseURL)?key=\(apiKey)")!

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": question]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 512
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_ONLY_HIGH"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15  // Timeout aggressivo per emergenze

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("Risposta non valida")
        }

        guard httpResponse.statusCode == 200 else {
            throw AIError.httpError(httpResponse.statusCode)
        }

        // Parse response
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw AIError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Check Internet
    func hasInternetConnection() async -> Bool {
        // Prova un HEAD request leggero a Google
        guard let url = URL(string: "https://www.google.com") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

// MARK: - Errors
enum AIError: LocalizedError {
    case networkError(String)
    case httpError(Int)
    case parseError
    case noInternet

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Errore di rete: \(msg)"
        case .httpError(let code): return "Errore HTTP \(code)"
        case .parseError: return "Errore nel parsing della risposta"
        case .noInternet: return "Nessuna connessione internet"
        }
    }
}
