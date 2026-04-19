import SwiftUI

/// NothingOS-style design tokens used everywhere in the app.
/// Pure black background, vibrant orange accent, white text, glyph-style.
enum Theme {
    static let orange  = Color("ilockinOrange")
    static let black   = Color("ilockinBlack")
    static let dark    = Color("ilockinDark")
    static let textPrimary   = Color.white
    static let textSecondary = Color("ilockinTextSecondary")

    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 18

    /// Heavy rounded SF Pro – the closest stock match to NothingOS dot-matrix vibe.
    static func displayFont(_ size: CGFloat, weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func monoFont(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Card / Glyph helpers

/// Standard NothingOS card: black fill, optional active orange border,
/// large rounded corners, subtle inner shadow.
struct ILCard<Content: View>: View {
    var isActive: Bool = false
    var padding: CGFloat = Theme.cardPadding
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(isActive ? Theme.orange : Color.white.opacity(0.06), lineWidth: isActive ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 2)
    }
}

/// Large glyph-style icon as used on the dashboard.
struct ILGlyph: View {
    let name: String
    var size: CGFloat = 28
    var active: Bool = true

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(active ? Theme.orange : Theme.textSecondary)
    }
}

/// Primary orange action button.
struct ILPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16, weight: .black))
                Text(title.uppercased())
                    .font(Theme.displayFont(13, weight: .black))
                    .tracking(1.4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.orange)
            )
            .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }
}

/// Secondary outline button (transparent bg + orange border).
struct ILSecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .black))
                Text(title.uppercased())
                    .font(Theme.displayFont(12, weight: .black))
                    .tracking(1.2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.orange.opacity(0.7), lineWidth: 1)
            )
            .foregroundStyle(Theme.orange)
        }
        .buttonStyle(.plain)
    }
}

/// Section title used at top of major panels.
struct ILSectionTitle: View {
    let text: String
    var glyph: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let glyph { ILGlyph(name: glyph, size: 18) }
            Text(text.uppercased())
                .font(Theme.displayFont(13, weight: .black))
                .tracking(2)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - View modifiers

extension View {
    /// Apply the iLockin global background + tint everywhere.
    func iLockinBackground() -> some View {
        self.background(Theme.black.ignoresSafeArea())
            .tint(Theme.orange)
            .preferredColorScheme(.dark)
    }
}
