import SwiftUI
import SwiftData
import WebKit
import Foundation

@Model
class LottoEntry {
    var id = UUID()
    var date: Date
    var numbers: [Int]
    var hasPlus: Bool
    var checked: [Bool]
    var plusChecked : [Bool]
    
    init(date: Date, numbers: [Int], hasPlus: Bool) {
        self.date = date
        self.numbers = numbers
        self.hasPlus = hasPlus
        self.checked = Array(repeating: false, count: numbers.count)
        self.plusChecked = Array(repeating: false, count: numbers.count)

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
                    ForEach(entries.sorted(by: { $0.date > $1.date })) { entry in
                        NavigationLink {
                            DetailView(entry: entry)
                        } label: {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        EditButton()
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingAddPopup = true }) {
                            Label("Dodaj", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Usuń wszystko") {
                            for entry in entries {
                                modelContext.delete(entry)
                            }
                        }
                        .tint(.red)
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
        var validEntries: [LottoEntry] = []
        
        for entry in newEntries {
            guard !entry.numbers.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }
            
            let numbers = entry.numbers.components(separatedBy: " ").compactMap { Int($0) }.sorted()
            
            guard numbers.count == 6,
                  numbers.allSatisfy({ 1...49 ~= $0 }),
                  numbers == Array(Set(numbers)).sorted() else {
                errorMessage = "Każdy zestaw musi mieć 6 unikalnych liczb w zakresie 1-49!"
                return
            }
            
            let newEntry = LottoEntry(
                date: Date(),
                numbers: numbers,
                hasPlus: entry.hasPlus
            )
            validEntries.append(newEntry)
        }
        
        if validEntries.isEmpty {
            errorMessage = "Brak poprawnych wpisów do zapisania!"
            return
        }
        
        for entry in validEntries {
            modelContext.insert(entry)
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
                .id("main-\(entry.id)-\(String(describing: index))")
            }
            
            if entry.hasPlus {
                HStack {
                    ForEach(0..<entry.numbers.count, id: \.self) { index in
                        Button {
                            entry.plusChecked[index].toggle()
                        } label: {
                            Text("\(entry.numbers[index])")
                                .numberStyle(checked: entry.plusChecked[index])
                        }
                    }
                    .id("plus-\(entry.id)-\(String(describing: index))")
                }
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
    var selectedNumbers: [Int] = []
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
                    ForEach($entries.indices, id: \.self) { index in
                        EntryView(entry: $entries[index], allEntries: $entries)
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
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(15)
        .shadow(radius: 10)
        .padding()
    }
}

struct EntryView: View {
    @Binding var entry: TempEntry
    @Binding var allEntries: [TempEntry]
    
    var body: some View {
        VStack {
            HStack {
                ForEach(entry.selectedNumbers.sorted(), id: \.self) { number in
                    Text("\(number)")
                        .numberStyle(checked: true)
                        .transition(.scale)
                }
            }
            
            NumberPadView(selectedNumbers: $entry.selectedNumbers)
            
            HStack {
                Toggle("Plus", isOn: $entry.hasPlus)
                    .labelsHidden()
                
                Button {
                    if let index = allEntries.firstIndex(where: { $0.id == entry.id }) {
                        allEntries.remove(at: index)
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .onChange(of: entry.selectedNumbers) { newValue in
            entry.numbers = newValue.sorted().map { String($0) }.joined(separator: " ")
        }
    }
}

struct NumberPadView: View {
    @Binding var selectedNumbers: [Int]
    
    let columns = Array(repeating: GridItem(.flexible()), count: 10)
    
    var body: some View {
        VStack(spacing: 15) {
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(1...49, id: \.self) { number in
                    Button(action: {
                        toggleNumber(number)
                    }) {
                        Text("\(number)")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(selectedNumbers.contains(number) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedNumbers.contains(number) ? .white : .primary)
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Button("Wyczyść") {
                selectedNumbers.removeAll()
            }
            .frame(width:70,height: 5)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
            .frame(width: 350)
            .padding()
            
        }
    }
    
    private func toggleNumber(_ number: Int) {
        if selectedNumbers.contains(number) {
            selectedNumbers.removeAll { $0 == number }
        } else if selectedNumbers.count < 6 {
            selectedNumbers.append(number)
        }
    }
}


// MARK: - Podgląd
#Preview {
    ContentView()
        .modelContainer(for: LottoEntry.self, inMemory: true)
}
