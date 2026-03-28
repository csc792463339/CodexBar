import SwiftUI

/// Preview demo — Fintech/Crypto Glassmorphism Dark
struct ThemePreviewDemo: View {
    var body: some View {
        ZStack {
            GlassPanelBackground()

            VStack(alignment: .leading, spacing: 0) {
                // MARK: Summary (Hero)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(MenuBarTheme.accent)

                            Text("CODEX BAR")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(MenuBarTheme.textTertiary)
                                .tracking(2)
                        }
                        Spacer()
                        Button {} label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(GlassIconButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                    }

                    HStack(alignment: .firstTextBaseline, spacing: MenuBarTheme.tagSpacing) {
                        Text("My Organization")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(MenuBarTheme.textPrimary)
                        Spacer()
                        MenuBarPill(text: "2/3 Available", tint: MenuBarTheme.success, icon: "checkmark.shield.fill", emphasized: true)
                    }

                    HStack(spacing: 16) {
                        miniStat(label: "5H", value: "42%", color: MenuBarTheme.success)
                        miniStat(label: "7D", value: "28%", color: MenuBarTheme.success)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("SECURED")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundStyle(MenuBarTheme.success.opacity(0.8))
                    }
                }
                .padding(MenuBarTheme.cardPadding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .fill(MenuBarTheme.bgSecondary)
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [MenuBarTheme.accent.opacity(0.06), Color.clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
                    }
                }
                .padding(.bottom, MenuBarTheme.cardSpacing)

                // MARK: Trust Bar
                HStack(spacing: 12) {
                    trustItem(icon: "bolt.shield.fill", text: "Auto-Switch")
                    Spacer()
                    trustItem(icon: "arrow.triangle.2.circlepath", text: "Real-Time")
                    Spacer()
                    trustItem(icon: "person.2.fill", text: "3 Wallets")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                            .fill(MenuBarTheme.glassFill)
                        RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                            .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
                    }
                }
                .padding(.bottom, MenuBarTheme.cardSpacing)

                // MARK: Accounts
                ScrollView {
                    VStack(alignment: .leading, spacing: MenuBarTheme.groupSpacing) {
                        // Group 1
                        VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                            groupHeader(email: "user@example.com", count: 2)

                            VStack(spacing: MenuBarTheme.cardSpacing) {
                                nodeCard(name: "Production Org", plan: "TEAM", planColor: MenuBarTheme.info, id: "#1747bed3-f", isActive: true, primary: 42, secondary: 28)
                                nodeCard(name: "Staging Org", plan: "PLUS", planColor: Color(hex: 0xA78BFA), id: "#acc_56cd78", isActive: false, primary: 15, secondary: 8)
                            }
                        }

                        // Group 2
                        VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                            groupHeader(email: "admin@company.io", count: 1)

                            VStack(spacing: MenuBarTheme.cardSpacing) {
                                warningCard(name: "Dev Team", plan: "TEAM", id: "#acc_99ef00", primary: 78, secondary: 55)
                            }
                        }

                        // Group 3
                        VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                            groupHeader(email: "test@dev.org", count: 1)

                            VStack(spacing: MenuBarTheme.cardSpacing) {
                                errorCard(name: "Test Account", plan: "PLUS", id: "#acc_aabb11")
                            }
                        }
                    }
                }
                .frame(maxHeight: 600)
                .padding(.bottom, MenuBarTheme.cardSpacing)

                // MARK: Success banner
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(MenuBarTheme.success)
                    Text("Account switched").font(.system(size: 13, weight: .medium)).foregroundStyle(MenuBarTheme.textPrimary)
                    Spacer()
                }
                .padding(MenuBarTheme.cardPadding)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .fill(MenuBarTheme.success.opacity(0.1))
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .strokeBorder(MenuBarTheme.success.opacity(0.2), lineWidth: 0.5)
                    }
                }
                .padding(.bottom, MenuBarTheme.cardSpacing)

                // MARK: Footer
                HStack(spacing: MenuBarTheme.buttonSpacing) {
                    Text("Just updated")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(MenuBarTheme.textTertiary)
                    Spacer()
                    HStack(spacing: 4) {
                        Button {} label: { Image(systemName: "plus") }.buttonStyle(GlassIconButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                        Button("EN") {}.buttonStyle(GlassPillButtonStyle())
                        Button {} label: { Image(systemName: "power") }.buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
                    }
                }
                .padding(.horizontal, MenuBarTheme.cardPadding)
                .padding(.vertical, MenuBarTheme.cardSpacing)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .fill(MenuBarTheme.bgSecondary)
                        RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                            .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
                    }
                }
            }
            .padding(MenuBarTheme.cardPadding)
        }
        .frame(width: MenuBarTheme.panelWidth)
    }

    // MARK: - Helpers

    private func miniStat(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func trustItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(MenuBarTheme.info)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
        }
    }

    private func groupHeader(email: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MenuBarTheme.textTertiary)
            Text(email)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MenuBarTheme.textSecondary)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(MenuBarTheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(MenuBarTheme.glassFill)
                }
        }
    }

    // MARK: - Node Cards

    @ViewBuilder
    private func nodeCard(name: String, plan: String, planColor: Color, id: String, isActive: Bool, primary: Int, secondary: Int) -> some View {
        HStack(spacing: 0) {
            if isActive {
                GlowAccentBar(color: MenuBarTheme.accent)
                    .padding(.vertical, 10)
                    .padding(.trailing, 12)
            }

            VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: MenuBarTheme.tagSpacing) {
                        Text(name).font(.system(size: 15, weight: .bold)).foregroundStyle(MenuBarTheme.textPrimary).lineLimit(1)
                        if isActive { MenuBarPill(text: "ACTIVE", tint: MenuBarTheme.accent, icon: "bolt.fill", emphasized: true) }
                        MenuBarPill(text: plan, tint: planColor)
                    }
                    HStack(spacing: 6) {
                        PulsingDot(color: isActive ? MenuBarTheme.accent : MenuBarTheme.success, size: isActive ? 6 : 5)
                        Text(id).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(MenuBarTheme.textTertiary)
                    }
                }

                HStack(alignment: .top, spacing: MenuBarTheme.cardPadding) {
                    GlassQuotaBar(title: "5H", value: Double(primary), tint: MenuBarTheme.quotaColor(Double(primary))).frame(maxWidth: .infinity)
                    GlassQuotaBar(title: "7D", value: Double(secondary), tint: MenuBarTheme.quotaColor(Double(secondary))).frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, isActive ? MenuBarTheme.cardPadding - 4 : MenuBarTheme.cardPadding)
        .padding(.trailing, MenuBarTheme.cardPadding)
        .padding(.vertical, MenuBarTheme.cardPadding)
        .background { GlassRowBackground(active: isActive, hovered: false, tint: MenuBarTheme.accent) }
    }

    @ViewBuilder
    private func warningCard(name: String, plan: String, id: String, primary: Int, secondary: Int) -> some View {
        VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: MenuBarTheme.tagSpacing) {
                    Text(name).font(.system(size: 15, weight: .bold)).foregroundStyle(MenuBarTheme.textPrimary).lineLimit(1)
                    MenuBarPill(text: plan, tint: MenuBarTheme.info)
                }
                HStack(spacing: 6) {
                    PulsingDot(color: MenuBarTheme.warning, size: 5)
                    Text(id).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(MenuBarTheme.textTertiary)
                }
            }

            HStack(alignment: .top, spacing: MenuBarTheme.cardPadding) {
                GlassQuotaBar(title: "5H", value: Double(primary), tint: MenuBarTheme.quotaColor(Double(primary))).frame(maxWidth: .infinity)
                GlassQuotaBar(title: "7D", value: Double(secondary), tint: MenuBarTheme.quotaColor(Double(secondary))).frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                Spacer()
                Button("Switch") {}.buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.accent))
                Button {} label: { Image(systemName: "trash") }.buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
            }
        }
        .padding(MenuBarTheme.cardPadding)
        .background { GlassRowBackground(active: false, hovered: false, tint: MenuBarTheme.accent) }
    }

    @ViewBuilder
    private func errorCard(name: String, plan: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: MenuBarTheme.titleContentSpacing) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: MenuBarTheme.tagSpacing) {
                    Text(name).font(.system(size: 15, weight: .bold)).foregroundStyle(MenuBarTheme.textPrimary).lineLimit(1)
                    MenuBarPill(text: plan, tint: Color(hex: 0xA78BFA))
                }
                HStack(spacing: 6) {
                    PulsingDot(color: MenuBarTheme.error, size: 5)
                    Text(id).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(MenuBarTheme.textTertiary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(MenuBarTheme.error)
                Text("Quota exhausted - resets in 2h 15m").font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuBarTheme.error).lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous).fill(MenuBarTheme.error.opacity(0.1))
                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous).strokeBorder(MenuBarTheme.error.opacity(0.2), lineWidth: 0.5)
                }
            }

            HStack(spacing: 4) {
                Spacer()
                Button("Reauth") {}.buttonStyle(GlassPillButtonStyle(prominent: true, tint: MenuBarTheme.warning))
                Button {} label: { Image(systemName: "trash") }.buttonStyle(GlassIconButtonStyle(tint: MenuBarTheme.error))
            }
        }
        .padding(MenuBarTheme.cardPadding)
        .background { GlassRowBackground(active: false, hovered: false, tint: MenuBarTheme.accent) }
    }
}

#Preview("Fintech Glassmorphism Dark") {
    ThemePreviewDemo()
        .preferredColorScheme(.dark)
}
