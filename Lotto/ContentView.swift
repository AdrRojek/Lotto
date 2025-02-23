import SwiftUI
import SwiftData
import WebKit



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
    @Query private var items: [Item]
    @State private var showingAddPopup = false
    @State private var newNumbers = ""
    @State private var hasPlus = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            NavigationSplitView {
                List {
                    ForEach(items) { item in
                        NavigationLink {
                            DetailView(item: item)
                        } label: {
                            HStack {
                                Text(item.numbers.map { String($0) }.joined(separator: " "))
                                if item.hasPlus {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: { showingAddPopup = true }) {
                            Label("Add Item", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                Text("Select an item")
            }
            
            HStack {
                WebView(url: URL(string: "https://www.lotto.pl/lotto/wyniki-i-wygrane")!)
                    .frame(height: 600)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAddPopup) {
            AddNumberPopup(
                newNumbers: $newNumbers,
                hasPlus: $hasPlus,
                errorMessage: $errorMessage,
                onSave: saveNumbers,
                onCancel: { showingAddPopup = false }
            )
        }
    }

    private func saveNumbers() {
        let numbers = newNumbers.components(separatedBy: " ").compactMap { Int($0) }
        
        guard numbers.count == 6 else {
            errorMessage = "Wprowadź dokładnie 6 liczb!"
            return
        }
        
        guard numbers.allSatisfy({ 1...49 ~= $0 }) else {
            errorMessage = "Liczby muszą być w zakresie 1-49!"
            return
        }
        
        let newItem = Item(
            timestamp: Date(),
            numbers: numbers.sorted(),
            hasPlus: hasPlus
        )
        
        modelContext.insert(newItem)
        newNumbers = ""
        hasPlus = false
        errorMessage = nil
        showingAddPopup = false
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

struct AddNumberPopup: View {
    @Binding var newNumbers: String
    @Binding var hasPlus: Bool
    @Binding var errorMessage: String?
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Dodaj nowe losowanie")
                .font(.headline)
            
            TextField("Wpisz 6 liczb oddzielonych spacją", text: $newNumbers)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
                .padding()
            
            Toggle("Lotto z Plusem", isOn: $hasPlus)
                .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 20) {
                Button("Anuluj", action: onCancel)
                    .buttonStyle(.bordered)
                
                Button("Zapisz", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .padding()
    }
}

struct DetailView: View {
    let item: Item
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Data: \(item.timestamp, style: .date)")
                .font(.title3)
            
            HStack {
                ForEach(item.numbers, id: \.self) { number in
                    Text("\(number)")
                        .padding()
                        .background(Circle().fill(Color.blue))
                        .foregroundColor(.white)
                }
            }
            
            if item.hasPlus {
                Text("Lotto z Plusem")
                    .foregroundColor(.green)
                    .font(.headline)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
