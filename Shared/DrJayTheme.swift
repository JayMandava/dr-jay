import SwiftUI
import UIKit

enum DrJayTheme {
    static let clinicalBlue = adaptive(
        light: (43, 76, 111),
        dark: (164, 194, 244),
        highContrastLight: (25, 55, 88),
        highContrastDark: (192, 214, 250)
    )

    static let frostBlue = adaptive(
        light: (111, 151, 201),
        dark: (133, 174, 226),
        highContrastLight: (69, 112, 165),
        highContrastDark: (176, 207, 247)
    )

    static let amber = adaptive(
        light: (212, 122, 55),
        dark: (240, 160, 92),
        highContrastLight: (164, 77, 19),
        highContrastDark: (255, 185, 116)
    )

    static let earth = adaptive(
        light: (122, 107, 93),
        dark: (181, 164, 148),
        highContrastLight: (84, 71, 59),
        highContrastDark: (210, 194, 178)
    )

    static let charcoal = adaptive(
        light: (34, 34, 34),
        dark: (242, 242, 242),
        highContrastLight: (16, 16, 16),
        highContrastDark: (255, 255, 255)
    )

    static let canvas = adaptive(
        light: (239, 243, 247),
        dark: (19, 23, 27),
        highContrastLight: (255, 255, 255),
        highContrastDark: (0, 0, 0)
    )

    static let surface = adaptive(
        light: (250, 251, 252),
        dark: (34, 38, 43),
        highContrastLight: (255, 255, 255),
        highContrastDark: (25, 25, 25)
    )

    static let outline = adaptive(
        light: (204, 213, 222),
        dark: (69, 77, 86),
        highContrastLight: (133, 145, 157),
        highContrastDark: (125, 133, 142)
    )

    static let ugly = adaptive(
        light: (164, 52, 52),
        dark: (244, 123, 116),
        highContrastLight: (120, 21, 21),
        highContrastDark: (255, 151, 143)
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
