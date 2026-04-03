import SwiftUI

struct CompatibleProviderRowView: View {
    let provider: CodexBarProvider
    let isActiveProvider: Bool
    let activeAccountId: String?
    let isBatchMode: Bool
    let selectedItemIds: Set<String>
    let onToggleSelection: (CodexBarProviderAccount) -> Void
    let onActivate: (CodexBarProviderAccount) -> Void
    let onAddAccount: () -> Void
    let onDeleteAccount: (CodexBarProviderAccount) -> Void
    let onDeleteProvider: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Provider Header
            HStack(spacing: 6) {
                Circle()
                    .fill(isActiveProvider ? MenuBarTheme.accent : MenuBarTheme.textTertiary.opacity(0.5))
                    .frame(width: 7, height: 7)

                Text(provider.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActiveProvider ? MenuBarTheme.accent : MenuBarTheme.textPrimary)

                Text(provider.hostLabel)
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(MenuBarTheme.glassFill)
                    .foregroundStyle(MenuBarTheme.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                if isActiveProvider {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MenuBarTheme.accent)
                }

                Spacer()

                if !isBatchMode {
                    Button(action: onAddAccount) {
                        Image(systemName: "plus")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.info))

                    Button(action: onDeleteProvider) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
                }
            }

            // Account Rows
            ForEach(provider.accounts) { account in
                HStack(spacing: 6) {
                    if isBatchMode {
                        let isSelected = selectedItemIds.contains(account.id)
                        Button {
                            onToggleSelection(account)
                        } label: {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(isSelected ? MenuBarTheme.error : MenuBarTheme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(account.label)
                        .font(.system(size: 11, weight: account.id == activeAccountId && isActiveProvider ? .semibold : .regular))
                        .foregroundStyle(MenuBarTheme.textPrimary)

                    if account.id == activeAccountId && isActiveProvider {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(MenuBarTheme.accent)
                    }

                    Spacer()

                    if !isBatchMode {
                        Text(account.maskedAPIKey)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(MenuBarTheme.textTertiary)
                            .lineLimit(1)

                        if account.id != activeAccountId || !isActiveProvider {
                            Button("Use") { onActivate(account) }
                                .buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                                .controlSize(.mini)
                        }

                        Button {
                            let alert = NSAlert()
                            alert.messageText = "Delete \(account.label)?"
                            alert.alertStyle = .warning
                            alert.addButton(withTitle: "Delete")
                            alert.addButton(withTitle: "Cancel")
                            if alert.runModal() == .alertFirstButtonReturn { onDeleteAccount(account) }
                        } label: {
                            Image(systemName: "trash").font(.system(size: 10))
                        }
                        .buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
                    }
                }
                .padding(.leading, isBatchMode ? 0 : 14)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, MenuBarTheme.cardPadding)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(isActiveProvider ? MenuBarTheme.accent.opacity(0.08) : MenuBarTheme.glassFill)
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .strokeBorder(
                        isActiveProvider ? MenuBarTheme.accent.opacity(0.3) : MenuBarTheme.glassBorder,
                        lineWidth: 0.5
                    )
            }
        }
    }
}
