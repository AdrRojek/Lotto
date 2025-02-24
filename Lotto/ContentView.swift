import SwiftUI
import SwiftData
import WebKit

@Model
class LottoEntry {
    var id = UUID()
    var date: Date
    var numbers: [Int]
    var hasPlus: Bool
    var checked: [Bool]
    
    init(date: Date, numbers: [Int], hasPlus: Bool) {
        self.date = date
        self.numbers = numbers
        self.hasPlus = hasPlus
        self.checked = Array(repeating: false, count: numbers.count)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.preferences.javaScriptEnabled = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [LottoEntry]
    @State private var showingAddPopup = false
    @State private var newEntries: [TempEntry] = [TempEntry()]
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            NavigationSplitView {
                List {
                    ForEach(entries) { entry in
                        NavigationLink {
                            DetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: { showingAddPopup = true }) {
                            Label("Dodaj", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                Text("Wybierz wpis")
            }
            
            WebView(url: URL(string: "https://www.lotto.pl/lotto/wyniki-i-wygrane")!)
                .frame(height: 400)
                .cornerRadius(12)
                .padding()
        }
        .sheet(isPresented: $showingAddPopup) {
            AddEntryPopup(
                entries: $newEntries,
                errorMessage: $errorMessage,
                onSave: saveEntries,
                onCancel: {
                    newEntries = [TempEntry()]
                    showingAddPopup = false
                }
            )
        }
    }

    private func saveEntries() {
        for entry in newEntries {
            let numbers = entry.numbers.components(separatedBy: " ").compactMap { Int($0) }
            
            for i in 1...5 {
                if numbers.sorted()[i] == numbers.sorted()[i-1]{
                    errorMessage = "Liczby musza sie różnić!"
                    return
                }
            }
            
            guard numbers.count == 6 else {
                errorMessage = "Każdy zestaw musi mieć 6 liczb!"
                return
            }
            
            guard numbers.allSatisfy({ 1...49 ~= $0 }) else {
                errorMessage = "Liczby muszą być w zakresie 1-49!"
                return
            }
            
            let newEntry = LottoEntry(
                date: Date(),
                numbers: numbers.sorted(),
                hasPlus: entry.hasPlus
            )
            modelContext.insert(newEntry)
        }
        
        newEntries = [TempEntry()]
        errorMessage = nil
        showingAddPopup = false
    }

    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

// MARK: - Wiersz wpisu
struct EntryRow: View {
    @Bindable var entry: LottoEntry
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.date.formatted(date: .numeric, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack {
                ForEach(0..<entry.numbers.count, id: \.self) { index in
                    Button {
                        entry.checked[index].toggle()
                    } label: {
                        Text("\(entry.numbers[index])")
                            .numberStyle(checked: entry.checked[index])
                    }
                    .buttonStyle(.plain)
                }
                
                if entry.hasPlus {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Widok szczegółów
struct DetailView: View {
    @Bindable var entry: LottoEntry
    
    var body: some View {
        VStack(spacing: 20) {
            Text(entry.date.formatted(date: .complete, time: .shortened))
                .font(.title3)
            
            HStack {
                ForEach(0..<entry.numbers.count, id: \.self) { index in
                    Button {
                        entry.checked[index].toggle()
                    } label: {
                        Text("\(entry.numbers[index])")
                            .numberStyle(checked: entry.checked[index])
                    }
                }
            }
            
            if entry.hasPlus {
                Text("Lotto z Plusem")
                    .foregroundColor(.green)
                    .font(.headline)
            }
        }
        .padding()
    }
}

// MARK: - Styl liczby
extension View {
    func numberStyle(checked: Bool) -> some View {
        self
            .padding(10)
            .frame(minWidth: 40)
            .background(Circle().fill(checked ? Color.green : Color.blue))
            .foregroundColor(.white)
            .font(.headline)
    }
}

// MARK: - Tymczasowy model dla formularza
struct TempEntry: Identifiable {
    let id = UUID()
    var numbers = ""
    var hasPlus = false
}

// MARK: - Popup dodawania
struct AddEntryPopup: View {
    @Binding var entries: [TempEntry]
    @Binding var errorMessage: String?
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Dodaj nowe losowanie")
                .font(.title3)
            
            ScrollView {
                VStack(spacing: 15) {
                    ForEach($entries) { $entry in
                        HStack {
                            TextField("Liczby (6 liczb)", text: $entry.numbers)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numbersAndPunctuation)
                            
                            Toggle("Plus", isOn: $entry.hasPlus)
                                .labelsHidden()
                            
                            Button {
                                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                                    entries.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
            }
            
            HStack {
                Button("Dodaj kolejny") {
                    entries.append(TempEntry())
                }
                
                Spacer()
                
                Button("Anuluj", action: onCancel)
                    .buttonStyle(.bordered)
                
                Button("Zapisz", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(15)
        .shadow(radius: 10)
        .padding()
    }
}

// MARK: - Podgląd
#Preview {
    ContentView()
        .modelContainer(for: LottoEntry.self, inMemory: true)
}
