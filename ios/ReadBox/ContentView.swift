import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ItemListViewModel()
    @State private var showingSettings = !ReadBoxSettings.isConfigured
    @State private var showingAddURL = false

    var body: some View {
        NavigationStack {
            List {
                Picker("Mode", selection: $viewModel.mode) {
                    ForEach(ItemListMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        "No Articles",
                        systemImage: "tray",
                        description: Text(viewModel.message ?? "Saved articles will appear here.")
                    )
                } else {
                    ForEach(viewModel.items) { item in
                        NavigationLink(value: item) {
                            ItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("ReadBox")
            .navigationDestination(for: ReadBoxItem.self) { item in
                ReaderView(item: item) {
                    Task { await viewModel.load() }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddURL = true
                    } label: {
                        Image(systemName: "plus")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .task {
                await viewModel.load()
            }
            .onChange(of: viewModel.mode) {
                Task { await viewModel.load() }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView {
                    Task { await viewModel.load() }
                }
            }
            .sheet(isPresented: $showingAddURL) {
                AddURLView {
                    Task { await viewModel.load() }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: ReadBoxItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title ?? item.url)
                    .font(.headline)
                    .lineLimit(2)
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }

            if let excerpt = item.excerpt, !excerpt.isEmpty {
                Text(excerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Text(item.siteName ?? URL(string: item.url)?.host ?? item.url)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
