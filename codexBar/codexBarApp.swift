import SwiftUI
import Combine

@main
struct codexBarApp: App {
    @StateObject private var store = TokenStore.shared
    @StateObject private var oauth = OAuthManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .environmentObject(oauth)
        } label: {
            MenuBarIconView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar icon: status capsule + rotating 5h / 7d usage
struct MenuBarIconView: View {
    @ObservedObject var store: TokenStore
    @State private var visibleWindowIndex = 0

    private let normalText = Color(nsColor: .labelColor)
    private let mutedText = Color(nsColor: .secondaryLabelColor)
    private let rotateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Capsule(style: .continuous)
                .fill(statusColor)
                .frame(width: 3, height: 14)
                .shadow(color: statusColor.opacity(0.6), radius: 2, x: 0, y: 0)

            if let active = store.accounts.first(where: { $0.isActive }) {
                if let window = currentVisibleWindow(for: active) {
                    Text("\(window.compactTitle) \(Int(window.usedPercent))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(metricColor(for: window))
                        .monospacedDigit()
                        .transition(.push(from: .bottom))
                } else {
                    Text("--")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(mutedText)
                }
            } else {
                Text("--")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(mutedText)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: visibleWindowIndex)
        .onReceive(rotateTimer) { _ in
            guard let active = store.accounts.first(where: { $0.isActive }) else {
                visibleWindowIndex = 0
                return
            }
            let windowCount = active.visibleQuotaWindows.count
            guard windowCount > 1 else {
                visibleWindowIndex = 0
                return
            }
            visibleWindowIndex = (visibleWindowIndex + 1) % windowCount
        }
    }

    private func currentVisibleWindow(for active: TokenAccount) -> QuotaWindowDisplay? {
        let windows = active.visibleQuotaWindows
        guard !windows.isEmpty else { return nil }
        let index = min(visibleWindowIndex, windows.count - 1)
        return windows[index]
    }

    private func metricColor(for window: QuotaWindowDisplay) -> Color {
        if window.usedPercent >= 100 { return MenuBarTheme.error }
        if window.usedPercent >= 80 { return MenuBarTheme.warning }
        return normalText
    }

    private var statusColor: Color {
        let ref: [TokenAccount]
        if let active = store.accounts.first(where: { $0.isActive }) {
            ref = [active]
        } else {
            ref = store.accounts
        }
        if ref.contains(where: { $0.isBanned }) { return MenuBarTheme.error }
        if ref.contains(where: { $0.secondaryExhausted }) { return MenuBarTheme.error }
        if ref.contains(where: { $0.quotaExhausted || $0.primaryUsedPercent >= 80 || $0.secondaryUsedPercent >= 80 }) { return MenuBarTheme.warning }
        return MenuBarTheme.success
    }
}
