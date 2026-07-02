import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ItemListViewModel()
    @State private var showingSettings = !ReadBoxSettings.isConfigured
    @State private var showingAddURL = false

    var body: some View {
        NavigationStack {
            ZStack {
                ReadBoxTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        modePicker

                        if viewModel.items.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(viewModel.items) { item in
                                    NavigationLink(value: item) {
                                        ItemRow(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding(18)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: ReadBoxItem.self) { item in
                ReaderView(item: item) {
                    Task { await viewModel.load() }
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
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingAddURL) {
                AddURLView {
                    Task { await viewModel.load() }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ReadBoxMark(size: 34)
                    Text("ReadBox")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(ReadBoxTheme.inkDeep)
                }
                Text("待读")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ReadBoxTheme.inkDeep)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    showingAddURL = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(RoundIconButtonStyle())

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(RoundIconButtonStyle())
            }
        }
    }

    private var modePicker: some View {
        Picker("文章筛选", selection: $viewModel.mode) {
            ForEach(ItemListMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .tint(ReadBoxTheme.ink)
    }

    private var emptyState: some View {
        ReadBoxCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ReadBoxTheme.accent)
                Text(viewModel.message ?? "这里还没有文章")
                    .font(.headline)
                    .foregroundStyle(ReadBoxTheme.inkDeep)
                Text("从分享菜单、Chrome 插件或粘贴 URL 保存第一个网页链接。")
                    .font(.subheadline)
                    .foregroundStyle(ReadBoxTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ItemRow: View {
    let item: ReadBoxItem

    var body: some View {
        ReadBoxCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    Text(item.title ?? item.url)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ReadBoxTheme.inkDeep)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    statusDot
                }

                if let excerpt = item.excerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.subheadline)
                        .foregroundStyle(ReadBoxTheme.muted)
                        .lineLimit(2)
                }

                HStack {
                    Text(item.siteName ?? URL(string: item.url)?.host ?? item.url)
                    Spacer()
                    if item.isFavorite {
                        Label("收藏", systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Text(item.status == .read ? "已读" : "未读")
                    }
                }
                .font(.caption)
                .foregroundStyle(ReadBoxTheme.muted)
            }
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(item.status == .read ? ReadBoxTheme.border : ReadBoxTheme.accent)
            .frame(width: 8, height: 8)
            .padding(.top, 6)
    }
}

struct RoundIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(ReadBoxTheme.ink)
            .frame(width: 44, height: 44)
            .background(ReadBoxTheme.surface)
            .clipShape(Circle())
            .overlay {
                Circle().stroke(ReadBoxTheme.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}
