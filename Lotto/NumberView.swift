import SwiftUI
import Foundation
import SwiftData
import SwiftSoup

class LottoScraper: ObservableObject {
    @Published var numbers: [String] = []
    @Published var drawDate: String = ""
    @Published var error: String?
    
    func fetch() {
        guard let url = URL(string: "https://www.lotto.pl/lotto/wyniki-i-wygrane") else {
            self.error = "Nieprawidłowy URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                self?.handleError(error.localizedDescription)
                return
            }
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                self?.handleError("Brak danych")
                return
            }
            
            DispatchQueue.main.async {
                self?.parseHTML(html)
            }
        }.resume()
    }
    
    private func parseHTML(_ html: String) {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Parsowanie daty losowania
            if let dateElement = try doc.select("div.wynik_lotto div.date").first() {
                self.drawDate = try dateElement.text()
            }
            
            // Parsowanie numerów
            let numbers = try doc.select("div.wynik_lotto span.number")
                .compactMap { try? $0.text() }
                .filter { $0.trimmingCharacters(in: .whitespaces) != "" }
                .prefix(6)
                .map { $0 }
            
            self.numbers = numbers.count == 6 ? numbers : ["?", "?", "?", "?", "?", "?"]
            
        } catch {
            handleError("Błąd parsowania: \(error.localizedDescription)")
        }
    }
    
    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.numbers = ["?", "?", "?", "?", "?", "?"]
            self.error = message
        }
    }
}

struct NumberView: View {
    @StateObject private var scraper = LottoScraper()
    
    var body: some View {
        VStack(spacing: 20) {
            if let error = scraper.error {
                Text("Błąd: \(error)")
                    .foregroundColor(.red)
            }
            
            Text("Ostatnie losowanie: \(scraper.drawDate)")
                .font(.headline)
            
            HStack(spacing: 15) {
                ForEach(scraper.numbers.indices, id: \.self) { index in
                    NumberCircle(number: scraper.numbers[index])
                }
            }
            
            Button("Odśwież") {
                scraper.fetch()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear { scraper.fetch() }
    }
}

struct NumberCircle: View {
    let number: String
    
    var body: some View {
        Text(number)
            .font(.system(size: 18, weight: .bold))
            .frame(width: 40, height: 40)
            .background(Circle().fill(Color.orange))
            .foregroundColor(.white)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
    }
}

#Preview {
    NumberView()
        .modelContainer(for: Item.self, inMemory: true)
}
