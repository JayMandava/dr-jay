import SwiftUI
import UIKit

enum DrJayTheme {
    // Pantone Color of the Year “Take a Break” palette, adapted for
    // legibility in light, dark, and increased-contrast appearances.
    static let primary = adaptive( // Cocoa Crème
        light: (149, 129, 110),
        dark: (186, 160, 130),
        highContrastLight: (99, 78, 61),
        highContrastDark: (218, 195, 169)
    )

    static let sleep = adaptive( // Pink Lemonade
        light: (230, 139, 157),
        dark: (239, 166, 180),
        highContrastLight: (170, 76, 98),
        highContrastDark: (255, 194, 205)
    )

    static let water = adaptive( // Tea
        light: (140, 139, 118),
        dark: (188, 187, 168),
        highContrastLight: (91, 90, 70),
        highContrastDark: (218, 217, 198)
    )

    static let roast = adaptive( // Mango Mojito, deepened where used as text
        light: (170, 123, 28),
        dark: (224, 185, 96),
        highContrastLight: (119, 80, 8),
        highContrastDark: (241, 207, 132)
    )

    static let papaya = adaptive(
        light: (245, 181, 131),
        dark: (231, 169, 122),
        highContrastLight: (190, 116, 65),
        highContrastDark: (249, 199, 159)
    )

    static let icedCoffee = adaptive(
        light: (186, 160, 130),
        dark: (202, 179, 151),
        highContrastLight: (126, 97, 70),
        highContrastDark: (227, 207, 183)
    )

    static let muted = adaptive( // Cocoa Crème
        light: (149, 129, 110),
        dark: (190, 172, 154),
        highContrastLight: (99, 78, 61),
        highContrastDark: (220, 204, 187)
    )

    static let canvas = adaptive( // Cloud Dancer
        light: (243, 242, 239),
        dark: (32, 29, 27),
        highContrastLight: (255, 255, 255),
        highContrastDark: (17, 15, 14)
    )

    static let surface = adaptive(
        light: (252, 251, 248),
        dark: (51, 45, 41),
        highContrastLight: (255, 255, 255),
        highContrastDark: (36, 31, 28)
    )

    static let outline = adaptive( // Iced Coffee
        light: (186, 160, 130),
        dark: (111, 93, 78),
        highContrastLight: (126, 97, 70),
        highContrastDark: (164, 140, 115)
    )

    static let ugly = adaptive( // Caramel
        light: (145, 88, 57),
        dark: (211, 160, 124),
        highContrastLight: (99, 51, 28),
        highContrastDark: (236, 190, 154)
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
