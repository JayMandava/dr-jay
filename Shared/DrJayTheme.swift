import SwiftUI
import UIKit

enum DrJayTheme {
    // Pantone Color of the Year “Light & Shadow” palette, adapted for
    // legibility in light, dark, and increased-contrast appearances.
    static let primary = adaptive( // Blue Fusion
        light: (79, 106, 124),
        dark: (126, 164, 187),
        highContrastLight: (48, 76, 96),
        highContrastDark: (159, 194, 214)
    )

    static let sleep = adaptive( // Quiet Violet
        light: (158, 137, 166),
        dark: (193, 174, 199),
        highContrastLight: (112, 88, 123),
        highContrastDark: (220, 202, 225)
    )

    static let water = adaptive( // Baltic Sea
        light: (91, 158, 192),
        dark: (125, 190, 219),
        highContrastLight: (43, 112, 151),
        highContrastDark: (157, 212, 235)
    )

    static let roast = adaptive( // Golden Mist, deepened where used as text
        light: (143, 124, 53),
        dark: (222, 210, 145),
        highContrastLight: (105, 88, 24),
        highContrastDark: (240, 229, 164)
    )

    static let goldenMist = adaptive(
        light: (216, 204, 143),
        dark: (222, 210, 145),
        highContrastLight: (143, 124, 53),
        highContrastDark: (240, 229, 164)
    )

    static let veiledVista = adaptive(
        light: (198, 222, 198),
        dark: (159, 194, 161),
        highContrastLight: (124, 157, 126),
        highContrastDark: (189, 218, 190)
    )

    static let muted = adaptive( // Hematite
        light: (122, 116, 112),
        dark: (181, 176, 172),
        highContrastLight: (79, 74, 70),
        highContrastDark: (213, 208, 204)
    )

    static let canvas = adaptive( // Cloud Dancer
        light: (240, 239, 235),
        dark: (28, 29, 30),
        highContrastLight: (255, 255, 255),
        highContrastDark: (14, 14, 15)
    )

    static let surface = adaptive(
        light: (250, 249, 246),
        dark: (43, 43, 44),
        highContrastLight: (255, 255, 255),
        highContrastDark: (31, 31, 32)
    )

    static let outline = adaptive( // Cloud Cover
        light: (163, 157, 158),
        dark: (105, 101, 102),
        highContrastLight: (115, 109, 110),
        highContrastDark: (151, 146, 147)
    )

    static let ugly = adaptive( // Hematite
        light: (101, 86, 82),
        dark: (196, 178, 173),
        highContrastLight: (65, 50, 47),
        highContrastDark: (225, 207, 201)
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
