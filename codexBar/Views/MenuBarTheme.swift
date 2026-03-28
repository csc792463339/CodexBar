import SwiftUI
import AppKit

// MARK: - Fintech / Crypto Dark Glassmorphism Design System

enum MenuBarTheme {
    // MARK: Layout
    static let panelWidth: CGFloat = 340
    static let panelRadius: CGFloat = 16
    static let cardRadius: CGFloat = 14
    static let buttonRadius: CGFloat = 10
    static let tagRadius: CGFloat = 8
    static let barRadius: CGFloat = 3
    static let accentBarWidth: CGFloat = 3

    // MARK: Spacing (4pt system)
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let groupSpacing: CGFloat = 20
    static let titleContentSpacing: CGFloat = 10
    static let rowSpacing: CGFloat = 6
    static let tagSpacing: CGFloat = 6
    static let buttonSpacing: CGFloat = 8

    // MARK: Background (Deep Void Palette)
    static let bgPrimary   = Color(hex: 0x0F172A)           // Deep navy
    static let bgSecondary = Color(hex: 0x1E293B)           // Elevated surface
    static let bgCard      = Color(hex: 0x1E293B, opacity: 0.7) // Glass card
    static let separator   = Color(hex: 0x334155)           // Slate border

    // MARK: Text Colors
    static let textPrimary   = Color(hex: 0xF8FAFC)         // Near white
    static let textSecondary = Color(hex: 0x94A3B8)         // Slate muted
    static let textTertiary  = Color(hex: 0x64748B)         // Dimmed

    // MARK: Semantic Accent Colors (Fintech)
    static let accent  = Color(hex: 0x3B82F6)               // Trust blue
    static let success = Color(hex: 0x22C55E)               // Crypto green
    static let warning = Color(hex: 0xF59E0B)               // Gold / amber
    static let error   = Color(hex: 0xEF4444)               // Alert red
    static let info    = Color(hex: 0x8B5CF6)               // Tech purple

    // MARK: Gradient Accent
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x3B82F6), Color(hex: 0x8B5CF6)],
        startPoint: .leading, endPoint: .trailing
    )
    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)],
        startPoint: .leading, endPoint: .trailing
    )
    static let successGradient = LinearGradient(
        colors: [Color(hex: 0x22C55E), Color(hex: 0x34D399)],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: Glass Effect
    static let glassFill       = Color.white.opacity(0.05)
    static let glassBorder     = Color.white.opacity(0.08)
    static let glassHighlight  = Color.white.opacity(0.12)

    // MARK: Button States
    static let buttonHover  = Color.white.opacity(0.06)
    static let buttonActive = Color(hex: 0x3B82F6).opacity(0.15)
    static let iconDefault  = Color(hex: 0x94A3B8)

    // MARK: Tap Target
    static let minTapSize: CGFloat = 32
    static let buttonSize: CGFloat = 32

    // MARK: Color Logic

    static func tone(for account: TokenAccount) -> Color {
        if account.tokenExpired { return warning }
        switch account.usageStatus {
        case .ok:       return accent
        case .warning:  return warning
        case .exceeded: return error
        case .banned:   return error
        }
    }

    static func planColor(_ planType: String) -> Color {
        switch planType.lowercased() {
        case "team": return info
        case "plus": return Color(hex: 0xA78BFA)  // Violet 400
        default:     return textTertiary
        }
    }

    static func quotaColor(_ percent: Double) -> Color {
        if percent >= 90 { return error }
        if percent >= 70 { return warning }
        return success
    }

    static func quotaGradient(_ percent: Double) -> LinearGradient {
        if percent >= 90 {
            return LinearGradient(colors: [Color(hex: 0xEF4444), Color(hex: 0xF87171)], startPoint: .leading, endPoint: .trailing)
        }
        if percent >= 70 {
            return LinearGradient(colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color(hex: 0x22C55E), Color(hex: 0x34D399)], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Glass Panel Background (Main Container)

struct GlassPanelBackground: View {
    var body: some View {
        ZStack {
            // Deep base
            RoundedRectangle(cornerRadius: MenuBarTheme.panelRadius, style: .continuous)
                .fill(MenuBarTheme.bgPrimary)

            // Subtle top-edge light
            RoundedRectangle(cornerRadius: MenuBarTheme.panelRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                )

            // Glass border
            RoundedRectangle(cornerRadius: MenuBarTheme.panelRadius, style: .continuous)
                .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Glass Section Background

struct GlassSectionBackground: View {
    var emphasized = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                .fill(emphasized ? MenuBarTheme.bgSecondary : MenuBarTheme.glassFill)

            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
        }
    }
}

// MARK: - Glass Row Background (Account Card)

struct GlassRowBackground: View {
    let active: Bool
    let hovered: Bool
    let tint: Color

    var body: some View {
        ZStack {
            // Glass fill
            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                .fill(MenuBarTheme.glassFill)

            // Subtle gradient overlay on hover
            if hovered {
                RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }

            // Border: active glow or glass hairline
            RoundedRectangle(cornerRadius: MenuBarTheme.cardRadius, style: .continuous)
                .strokeBorder(
                    active ? MenuBarTheme.accent.opacity(0.6) : MenuBarTheme.glassBorder,
                    lineWidth: active ? 1 : 0.5
                )
        }
        .shadow(
            color: active ? MenuBarTheme.accent.opacity(0.15) : Color.black.opacity(hovered ? 0.3 : 0.2),
            radius: hovered ? 12 : 8,
            x: 0,
            y: hovered ? 4 : 2
        )
    }
}

// MARK: - Tag / Pill Badge

struct MenuBarPill: View {
    let text: String
    let tint: Color
    var icon: String? = nil
    var emphasized = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(emphasized ? tint : MenuBarTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                    .fill(emphasized ? tint.opacity(0.15) : MenuBarTheme.glassFill)

                RoundedRectangle(cornerRadius: MenuBarTheme.tagRadius, style: .continuous)
                    .strokeBorder(emphasized ? tint.opacity(0.25) : MenuBarTheme.glassBorder, lineWidth: 0.5)
            }
        }
    }
}

// MARK: - Gradient Quota Bar (Progress)

struct GlassQuotaBar: View {
    let title: String
    let value: Double
    let tint: Color
    var detail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MenuBarTheme.textSecondary)

                Spacer()

                Text("\(Int(value))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(tint)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(MenuBarTheme.glassFill)
                        .overlay {
                            Capsule()
                                .strokeBorder(MenuBarTheme.glassBorder, lineWidth: 0.5)
                        }

                    // Fill with gradient
                    Capsule()
                        .fill(MenuBarTheme.quotaGradient(value))
                        .frame(width: max(0, min(100, CGFloat(value))) / 100 * geo.size.width)
                        .shadow(color: tint.opacity(0.4), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 5)
            .clipShape(Capsule())

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MenuBarTheme.textTertiary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Glass Icon Button (32pt)

struct GlassIconButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = MenuBarTheme.iconDefault

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(
                configuration.isPressed ? MenuBarTheme.accent :
                prominent ? tint : MenuBarTheme.iconDefault
            )
            .frame(width: MenuBarTheme.buttonSize, height: MenuBarTheme.buttonSize)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                        .fill(
                            configuration.isPressed ? MenuBarTheme.buttonActive :
                            MenuBarTheme.glassFill
                        )

                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                        .strokeBorder(
                            configuration.isPressed ? MenuBarTheme.accent.opacity(0.3) :
                            MenuBarTheme.glassBorder,
                            lineWidth: 0.5
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Glass Pill Button (Text)

struct GlassPillButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = MenuBarTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(prominent ? tint : MenuBarTheme.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: MenuBarTheme.buttonSize)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                        .fill(
                            configuration.isPressed ? MenuBarTheme.buttonActive :
                            prominent ? tint.opacity(0.12) : MenuBarTheme.glassFill
                        )

                    RoundedRectangle(cornerRadius: MenuBarTheme.buttonRadius, style: .continuous)
                        .strokeBorder(
                            prominent ? tint.opacity(0.25) : MenuBarTheme.glassBorder,
                            lineWidth: 0.5
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Pulsing Status Dot

struct PulsingDot: View {
    let color: Color
    let size: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .opacity(isPulsing ? 0 : 0.6)

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 0)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Glow Accent Bar (Left indicator)

struct GlowAccentBar: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.5)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: MenuBarTheme.accentBarWidth)
            .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
    }
}
