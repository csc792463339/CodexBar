import SwiftUI

/// Account Card — Glassmorphism fintech style
struct AccountRowView: View {
    let account: TokenAccount
    let isActive: Bool
    let now: Date
    let isRefreshing: Bool
    let onActivate: () -> Void
    let onRefresh: () -> Void
    let onReauth: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // Left glow accent bar
            if isActive {
                GlowAccentBar(color: MenuBarTheme.accent)
                    .padding(.vertical, 10)
                    .padding(.trailing, 12)
            }

            VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                headerRow
                contentArea
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, isActive ? MenuBarTheme.cardPadding - 4 : MenuBarTheme.cardPadding)
        .padding(.trailing, MenuBarTheme.cardPadding)
        .padding(.vertical, MenuBarTheme.cardPadding)
        .background {
            GlassRowBackground(active: isActive, hovered: isHovered, tint: MenuBarTheme.accent)
        }
        .offset(y: isHovered ? -2 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovered in
            isHovered = hovered
        }
    }

    // MARK: - Header: Name + Tags + Actions

    private var headerRow: some View {
        HStack(alignment: .center, spacing: MenuBarTheme.buttonSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: MenuBarTheme.tagSpacing) {
                    Text(displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MenuBarTheme.textPrimary)
                        .lineLimit(1)

                    if isActive {
                        MenuBarPill(
                            text: L.activeBadge,
                            tint: MenuBarTheme.accent,
                            icon: "bolt.fill",
                            emphasized: true
                        )
                    }

                    MenuBarPill(
                        text: account.planType.uppercased(),
                        tint: MenuBarTheme.planColor(account.planType)
                    )
                }

                HStack(spacing: 6) {
                    // Status dot
                    PulsingDot(
                        color: statusTone,
                        size: isActive ? 6 : 5
                    )

                    Text("#\(String(account.accountId.prefix(10)))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(MenuBarTheme.textTertiary)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                if !account.tokenExpired && !account.isBanned {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: statusTone))
                    .help(L.refreshUsage)
                    .disabled(isRefreshing)
                }

                if account.tokenExpired {
                    Button(L.reauth, action: onReauth)
                        .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.warning))
                } else if !account.isBanned && !isActive {
                    Button(L.switchBtn, action: onActivate)
                        .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                }

                Button {
                    let alert = NSAlert()
                    alert.messageText = L.confirmDelete(displayName)
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L.delete)
                    alert.addButton(withTitle: L.cancel)
                    if alert.runModal() == .alertFirstButtonReturn {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
                .help(L.delete)
            }
        }
    }

    // MARK: - Content Area: Status or Quota

    @ViewBuilder
    private var contentArea: some View {
        if let statusDetail {
            statusBanner(statusDetail)
        } else {
            quotaSection
        }

        if !resetFootnote.isEmpty {
            Text(resetFootnote)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
                .lineLimit(1)
        }
    }

    // MARK: - Status Banner

    private func statusBanner(_ detail: (icon: String, text: String, tint: Color)) -> some View {
        HStack(spacing: 8) {
            Image(systemName: detail.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(detail.tint)

            Text(detail.text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(detail.tint)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                    .fill(detail.tint.opacity(0.1))

                RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                    .strokeBorder(detail.tint.opacity(0.2), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Quota Progress Bars

    private var quotaSection: some View {
        let windows = account.visibleQuotaWindows

        return Group {
            if windows.isEmpty {
                statusBanner((icon: "clock.arrow.circlepath", text: L.waitingForRefresh, tint: MenuBarTheme.info))
            } else if windows.count == 1, let window = windows.first {
                quotaBar(for: window)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: MenuBarTheme.cardPadding) {
                    ForEach(windows) { window in
                        quotaBar(for: window)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func quotaBar(for window: QuotaWindowDisplay) -> some View {
        GlassQuotaBar(
            title: window.title,
            value: window.usedPercent,
            tint: MenuBarTheme.quotaColor(window.usedPercent),
            detail: account.nextRefreshDescription(for: window.kind)
        )
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if let org = account.organizationName, !org.isEmpty { return org }
        return String(account.accountId.prefix(8))
    }

    private var statusTone: Color {
        MenuBarTheme.tone(for: account)
    }

    private var statusDetail: (icon: String, text: String, tint: Color)? {
        if account.tokenExpired {
            return ("key.slash.fill", L.tokenExpiredHint, MenuBarTheme.warning)
        }
        if account.isBanned {
            return ("xmark.circle.fill", L.accountSuspended, MenuBarTheme.error)
        }
        if let exhaustedWindow = account.exhaustedWindow {
            let label = exhaustedWindow.kind == .sevenDay ? L.weeklyExhausted : L.primaryExhausted
            let resetDesc = account.resetDescription(for: exhaustedWindow.kind)
            let text = resetDesc.isEmpty ? label : "\(label) · \(resetDesc)"
            return ("exclamationmark.circle.fill", text, MenuBarTheme.error)
        }
        return nil
    }

    private var resetFootnote: String {
        _ = now
        guard
            let window = account.visibleQuotaWindows
                .filter({ $0.usedPercent >= 70 })
                .max(by: { $0.usedPercent < $1.usedPercent })
        else {
            return ""
        }
        return account.resetDescription(for: window.kind)
    }
}
