import SwiftUI
import UIKit

enum DrJayTheme {
    // Pantone Color of the Year “Tropic Tonalities” palette, adapted for
    // legibility in light, dark, and increased-contrast appearances.
    static let primary = adaptive( // Iris Orchid, deepened where used as text
        light: (130, 78, 130),
        dark: (200, 151, 200),
        highContrastLight: (94, 46, 94),
        highContrastDark: (226, 182, 226)
    )

    static let sleep = adaptive( // Paradise Pink
        light: (196, 67, 82),
        dark: (237, 132, 143),
        highContrastLight: (151, 35, 49),
        highContrastDark: (255, 169, 178)
    )

    static let water = adaptive( // Capri, deepened where used as text
        light: (42, 139, 157),
        dark: (134, 211, 222),
        highContrastLight: (12, 100, 118),
        highContrastDark: (174, 231, 239)
    )

    static let roast = adaptive( // Bright Marigold, deepened where used as text
        light: (181, 98, 0),
        dark: (255, 184, 91),
        highContrastLight: (128, 66, 0),
        highContrastDark: (255, 210, 149)
    )

    static let sunnyLime = adaptive(
        light: (232, 239, 165),
        dark: (105, 112, 48),
        highContrastLight: (177, 188, 83),
        highContrastDark: (216, 226, 139)
    )

    static let capri = adaptive(
        light: (121, 197, 210),
        dark: (73, 153, 168),
        highContrastLight: (42, 139, 157),
        highContrastDark: (156, 222, 232)
    )

    static let muted = adaptive( // Iris Orchid
        light: (130, 91, 130),
        dark: (190, 157, 190),
        highContrastLight: (94, 54, 94),
        highContrastDark: (220, 190, 220)
    )

    static let canvas = adaptive( // Cloud Dancer
        light: (243, 242, 239),
        dark: (29, 27, 31),
        highContrastLight: (255, 255, 255),
        highContrastDark: (15, 14, 17)
    )

    static let surface = adaptive(
        light: (253, 252, 250),
        dark: (48, 42, 49),
        highContrastLight: (255, 255, 255),
        highContrastDark: (34, 29, 35)
    )

    static let outline = adaptive( // Iris Orchid
        light: (176, 128, 176),
        dark: (112, 78, 112),
        highContrastLight: (130, 78, 130),
        highContrastDark: (173, 127, 173)
    )

    static let ugly = adaptive( // Paradise Pink
        light: (167, 39, 56),
        dark: (221, 105, 116),
        highContrastLight: (120, 20, 35),
        highContrastDark: (247, 147, 157)
    )

    private static func adaptive(
        light: (Int, Int, Int),
        dark: (Int, Int, Int),
        highContrastLight: (Int, Int, Int),
        highContrastDark: (Int, Int, Int)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            let components: (Int, Int, Int)

            switch (isDark, isHighContrast) {
            case (false, false): components = light
            case (true, false): components = dark
            case (false, true): components = highContrastLight
            case (true, true): components = highContrastDark
            }

            return UIColor(
                red: CGFloat(components.0) / 255,
                green: CGFloat(components.1) / 255,
                blue: CGFloat(components.2) / 255,
                alpha: 1
            )
        })
    }
}

private struct ClinicalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                DrJayTheme.surface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DrJayTheme.outline.opacity(0.7), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.035), radius: 10, y: 3)
    }
}

extension View {
    func clinicalCard() -> some View {
        modifier(ClinicalCardModifier())
    }
}
