import SwiftUI
import Combine
import AppKit

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

    private let rotateTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let active = store.accounts.first(where: { $0.isActive })
        let window = active.flatMap(currentVisibleWindow(for:))

        MenuBarBalanceBadgeImage(
            labelText: window?.title ?? "--",
            valueText: window.map { "\(remainingPercent(for: $0))%" } ?? "--",
            tint: palette(for: window),
            isPlaceholder: window == nil
        )
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
        .help(helpText(for: active, window: window))
    }

    private func currentVisibleWindow(for active: TokenAccount) -> QuotaWindowDisplay? {
        let windows = active.visibleQuotaWindows
        guard !windows.isEmpty else { return nil }
        let index = min(visibleWindowIndex, windows.count - 1)
        return windows[index]
    }

    private func remainingPercent(for window: QuotaWindowDisplay) -> Int {
        Int(window.remainingPercent.rounded())
    }

    private func palette(for window: QuotaWindowDisplay?) -> MenuBarBadgePalette {
        guard let window else {
            return MenuBarBadgePalette.placeholder
        }
        if window.remainingPercent <= 10 { return .critical }
        if window.remainingPercent <= 30 { return .warning }
        return .healthy
    }

    private func helpText(for active: TokenAccount?, window: QuotaWindowDisplay?) -> String {
        guard let active else { return "No active account" }
        guard let window else { return active.email }
        return "\(active.email) · \(window.title) \(remainingPercent(for: window))%"
    }
}

private struct MenuBarBadgePalette {
    let border: NSColor
    let backgroundStart: NSColor
    let backgroundEnd: NSColor
    let labelText: NSColor
    let valueText: NSColor
    let shadow: NSColor

    static let placeholder = MenuBarBadgePalette(
        border: NSColor.white.withAlphaComponent(0.34),
        backgroundStart: NSColor.white.withAlphaComponent(0.08),
        backgroundEnd: NSColor.white.withAlphaComponent(0.05),
        labelText: NSColor.white.withAlphaComponent(0.62),
        valueText: NSColor.white.withAlphaComponent(0.84),
        shadow: NSColor.clear
    )

    static let healthy = MenuBarBadgePalette(
        border: NSColor(calibratedRed: 0.12, green: 0.95, blue: 0.46, alpha: 0.98),
        backgroundStart: NSColor(calibratedRed: 0.06, green: 0.23, blue: 0.14, alpha: 0.96),
        backgroundEnd: NSColor(calibratedRed: 0.05, green: 0.18, blue: 0.11, alpha: 0.94),
        labelText: NSColor(calibratedRed: 0.38, green: 0.96, blue: 0.63, alpha: 0.90),
        valueText: NSColor(calibratedRed: 0.14, green: 0.98, blue: 0.50, alpha: 1),
        shadow: NSColor(calibratedRed: 0.12, green: 0.95, blue: 0.46, alpha: 0.28)
    )

    static let warning = MenuBarBadgePalette(
        border: NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.16, alpha: 0.98),
        backgroundStart: NSColor(calibratedRed: 0.25, green: 0.17, blue: 0.04, alpha: 0.96),
        backgroundEnd: NSColor(calibratedRed: 0.20, green: 0.12, blue: 0.03, alpha: 0.94),
        labelText: NSColor(calibratedRed: 1.0, green: 0.82, blue: 0.40, alpha: 0.90),
        valueText: NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.22, alpha: 1),
        shadow: NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.16, alpha: 0.26)
    )

    static let critical = MenuBarBadgePalette(
        border: NSColor(calibratedRed: 1.0, green: 0.36, blue: 0.36, alpha: 0.98),
        backgroundStart: NSColor(calibratedRed: 0.25, green: 0.07, blue: 0.09, alpha: 0.96),
        backgroundEnd: NSColor(calibratedRed: 0.19, green: 0.05, blue: 0.07, alpha: 0.94),
        labelText: NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.62, alpha: 0.90),
        valueText: NSColor(calibratedRed: 1.0, green: 0.44, blue: 0.44, alpha: 1),
        shadow: NSColor(calibratedRed: 1.0, green: 0.34, blue: 0.34, alpha: 0.24)
    )
}

private struct MenuBarBalanceBadgeImage: View {
    let labelText: String
    let valueText: String
    let tint: MenuBarBadgePalette
    let isPlaceholder: Bool

    var body: some View {
        Image(nsImage: renderedImage)
            .renderingMode(.original)
    }

    private var renderedImage: NSImage {
        let size = NSSize(width: 40, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()

        let bodyRect = NSRect(x: 1, y: 2, width: 38, height: 20)
        let innerRect = bodyRect.insetBy(dx: 1.2, dy: 1.2)

        if !isPlaceholder {
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 3
            shadow.shadowOffset = NSSize(width: 0, height: -0.5)
            shadow.shadowColor = tint.shadow
            shadow.set()
        }

        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 7.5, yRadius: 7.5)
        let gradient = NSGradient(colors: [tint.backgroundStart, tint.backgroundEnd])!
        gradient.draw(in: bodyPath, angle: 90)
        bodyPath.lineWidth = 1.2
        tint.border.setStroke()
        bodyPath.stroke()

        let shinePath = NSBezierPath(roundedRect: innerRect, xRadius: 6.4, yRadius: 6.4)
        NSColor.white.withAlphaComponent(isPlaceholder ? 0.03 : 0.14).setFill()
        shinePath.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 7.5, weight: .semibold),
            .foregroundColor: tint.labelText,
            .paragraphStyle: paragraph
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: tint.valueText,
            .paragraphStyle: paragraph
        ]

        let labelRect = NSRect(x: bodyRect.minX + 3, y: bodyRect.minY + 10.2, width: bodyRect.width - 6, height: 7)
        NSString(string: labelText).draw(in: labelRect, withAttributes: labelAttrs)

        let valueRect = NSRect(x: bodyRect.minX + 3, y: bodyRect.minY + 3.2, width: bodyRect.width - 6, height: 9)
        NSString(string: valueText).draw(in: valueRect, withAttributes: valueAttrs)

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
