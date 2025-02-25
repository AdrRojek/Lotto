import SwiftUI
import Foundation
import SwiftData
import SwiftSoup

class LottoScraper: ObservableObject {
    @Published var numbers: [String] = []
    @Published var drawDate: String = ""
    @Published var error: String?
    
    func fetch() {
        print("Rozpoczynanie pobierania...")
        guard let url = URL(string: "https://www.lotto.pl/lotto/wyniki-i-wygrane") else {
            self.handleError("Nieprawidłowy URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (compatible; MyLottoApp)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.handleError("Błąd sieciowy: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self?.handleError("Brak odpowiedzi HTTP")
                return
            }
            
            print("Status HTTP:", httpResponse.statusCode)
            print("Nagłówki:", httpResponse.allHeaderFields)
            
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                self?.handleError("Brak danych")
                return
            }
            
            print("Pierwsze 500 znaków HTML:")
            print(String(html.prefix(500)))
            
            DispatchQueue.main.async {
                self?.parseHTML(html)
            }
        }.resume()
    }
    func testWithMockHTML() {
        let mockHTML = """
        <div class="lotto-results">
            <span class="date-value">12.07.2024</span>
            <div class="results-container">
                <div class="result-item">11</div>
                <div class="result-item">22</div>
                <div class="result-item">33</div>
                <div class="result-item">44</div>
                <div class="result-item">55</div>
                <div class="result-item">66</div>
            </div>
        </div>
        """
        
        self.parseHTML(mockHTML)
    }
    
    private func parseHTML(_ html: String) {
        do {
            let doc = try SwiftSoup.parse(html)
            
            guard let resultsContainer = try doc.select("div.lotto-results").first() else {
                self.handleError("Nie znaleziono kontenera wyników")
                return
            }
            
            if let dateElement = try resultsContainer.select("span.date-value").first() {
                self.drawDate = try dateElement.text()
            }
            
            let numbers = try resultsContainer.select("div.your-correct-css-selector")
                .compactMap { try? $0.text() }

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
            Button("Testuj z mockiem HTML") {
                            scraper.testWithMockHTML()
                        }
            
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
        .modelContainer(for: LottoEntry.self, inMemory: true)
}
