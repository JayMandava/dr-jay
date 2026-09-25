import SwiftUI
import UIKit

enum AppTheme: String, CaseIterable, Identifiable {
    case powderedPastels
    case takeABreak
    case atmospheric
    case comfortZone
    case tropicTonalities
    case lightAndShadow
    case glamourAndGleam

    var id: Self { self }

    var label: String {
        switch self {
        case .powderedPastels: "Powdered Pastels"
        case .takeABreak: "Take a Break"
        case .atmospheric: "Atmospheric"
        case .comfortZone: "Comfort Zone"
        case .tropicTonalities: "Tropic Tonalities"
        case .lightAndShadow: "Light & Shadow"
        case .glamourAndGleam: "Glamour & Gleam"
        }
    }

    var previewColors: [Color] {
        palette.swatches.map(\.color)
    }
}

enum DrJayTheme {
    static var primary: Color { foreground(current.palette.primary) }
    static var sleep: Color { foreground(current.palette.sleep) }
    static var water: Color { foreground(current.palette.water) }
    static var roast: Color { foreground(current.palette.roast) }
    static var muted: Color { foreground(current.palette.muted) }
    static var ugly: Color { foreground(current.palette.ugly, minimumContrast: 5) }

    static var sunnyLime: Color { decorative(current.palette.softWarm) }
    static var capri: Color { decorative(current.palette.softCool) }

    static var canvas: Color {
        let palette = current.palette
        return adaptive(
            light: palette.canvas,
            dark: palette.primary.mixed(with: .black, amount: 0.82),
            highContrastLight: .white,
            highContrastDark: palette.primary.mixed(with: .black, amount: 0.92)
        )
    }

    static var surface: Color {
        let palette = current.palette
        return adaptive(
            light: palette.canvas.mixed(with: .white, amount: 0.72),
            dark: palette.primary.mixed(with: .black, amount: 0.70),
            highContrastLight: .white,
            highContrastDark: palette.primary.mixed(with: .black, amount: 0.84)
        )
    }

    static var outline: Color {
        let palette = current.palette
        let lightSurface = palette.canvas.mixed(with: .white, amount: 0.72)
        let darkSurface = palette.primary.mixed(with: .black, amount: 0.70)
        return adaptive(
            light: palette.primary.ensuringContrast(3, against: lightSurface, toward: .black),
            dark: palette.primary.ensuringContrast(3, against: darkSurface, toward: .white),
            highContrastLight: palette.primary.ensuringContrast(4.5, against: .white, toward: .black),
            highContrastDark: palette.primary.ensuringContrast(4.5, against: darkSurface, toward: .white)
        )
    }

    private static var current: AppTheme {
        guard let rawValue = AppConfig.sharedDefaults.string(forKey: AppConfig.DefaultsKey.theme),
              let theme = AppTheme(rawValue: rawValue) else {
            return .tropicTonalities
        }
        return theme
    }

    private static func foreground(_ base: ThemeRGB, minimumContrast: Double = 4.5) -> Color {
        let palette = current.palette
        let lightSurface = palette.canvas.mixed(with: .white, amount: 0.72)
        let darkSurface = palette.primary.mixed(with: .black, amount: 0.70)
        return adaptive(
            light: base.ensuringContrast(minimumContrast, against: lightSurface, toward: .black),
            dark: base.ensuringContrast(minimumContrast, against: darkSurface, toward: .white),
            highContrastLight: base.ensuringContrast(7, against: .white, toward: .black),
            highContrastDark: base.ensuringContrast(7, against: darkSurface, toward: .white)
        )
    }

    private static func decorative(_ base: ThemeRGB) -> Color {
        adaptive(
            light: base,
            dark: base.mixed(with: .black, amount: 0.36),
            highContrastLight: base.mixed(with: .black, amount: 0.15),
            highContrastDark: base.mixed(with: .white, amount: 0.10)
        )
    }

    private static func adaptive(
        light: ThemeRGB,
        dark: ThemeRGB,
        highContrastLight: ThemeRGB,
        highContrastDark: ThemeRGB
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let components: ThemeRGB
            switch (traits.userInterfaceStyle == .dark, traits.accessibilityContrast == .high) {
            case (false, false): components = light
            case (true, false): components = dark
            case (false, true): components = highContrastLight
            case (true, true): components = highContrastDark
            }
            return components.uiColor
        })
    }
}

private struct ThemePalette {
    let swatches: [ThemeRGB]
    let primary: ThemeRGB
    let sleep: ThemeRGB
    let water: ThemeRGB
    let roast: ThemeRGB
    let softWarm: ThemeRGB
    let softCool: ThemeRGB
    let muted: ThemeRGB
    let ugly: ThemeRGB
    let canvas: ThemeRGB
}

private extension AppTheme {
    var palette: ThemePalette {
        switch self {
        case .powderedPastels:
            ThemePalette(
                swatches: [rgb(244, 236, 204), rgb(215, 228, 240), rgb(232, 217, 221), cloudDancer, rgb(218, 221, 224), rgb(236, 218, 206), rgb(203, 211, 194), rgb(218, 211, 220)],
                primary: rgb(203, 211, 194), sleep: rgb(232, 217, 221), water: rgb(215, 228, 240),
                roast: rgb(236, 218, 206), softWarm: rgb(244, 236, 204), softCool: rgb(215, 228, 240),
                muted: rgb(218, 211, 220), ugly: rgb(232, 217, 221), canvas: cloudDancer
            )
        case .takeABreak:
            ThemePalette(
                swatches: [rgb(172, 144, 112), rgb(206, 160, 72), rgb(131, 110, 91), rgb(222, 117, 140), rgb(155, 155, 137), rgb(242, 166, 113), cloudDancer, rgb(185, 128, 92)],
                primary: rgb(155, 155, 137), sleep: rgb(222, 117, 140), water: rgb(172, 144, 112),
                roast: rgb(206, 160, 72), softWarm: rgb(242, 166, 113), softCool: rgb(155, 155, 137),
                muted: rgb(131, 110, 91), ugly: rgb(222, 117, 140), canvas: cloudDancer
            )
        case .atmospheric:
            ThemePalette(
                swatches: [rgb(188, 208, 232), cloudDancer, rgb(123, 168, 207), rgb(171, 171, 194), rgb(168, 178, 170), rgb(84, 121, 178), rgb(121, 196, 194), rgb(224, 205, 140)],
                primary: rgb(84, 121, 178), sleep: rgb(171, 171, 194), water: rgb(121, 196, 194),
                roast: rgb(224, 205, 140), softWarm: rgb(224, 205, 140), softCool: rgb(123, 168, 207),
                muted: rgb(168, 178, 170), ugly: rgb(84, 121, 178), canvas: cloudDancer
            )
        case .comfortZone:
            ThemePalette(
                swatches: [rgb(212, 193, 175), rgb(215, 146, 136), rgb(135, 118, 108), rgb(221, 192, 166), rgb(180, 173, 171), rgb(169, 141, 143), rgb(122, 88, 92), cloudDancer],
                primary: rgb(122, 88, 92), sleep: rgb(215, 146, 136), water: rgb(135, 118, 108),
                roast: rgb(221, 192, 166), softWarm: rgb(212, 193, 175), softCool: rgb(180, 173, 171),
                muted: rgb(169, 141, 143), ugly: rgb(122, 88, 92), canvas: cloudDancer
            )
        case .tropicTonalities:
            ThemePalette(
                swatches: [cloudDancer, rgb(159, 106, 160), rgb(104, 185, 200), rgb(192, 202, 74), rgb(227, 238, 149), rgb(240, 148, 54), rgb(211, 82, 97), rgb(251, 233, 81)],
                primary: rgb(159, 106, 160), sleep: rgb(211, 82, 97), water: rgb(104, 185, 200),
                roast: rgb(240, 148, 54), softWarm: rgb(227, 238, 149), softCool: rgb(104, 185, 200),
                muted: rgb(159, 106, 160), ugly: rgb(211, 82, 97), canvas: cloudDancer
            )
        case .lightAndShadow:
            ThemePalette(
                swatches: [cloudDancer, rgb(205, 228, 205), rgb(135, 180, 213), rgb(213, 206, 156), rgb(164, 148, 171), rgb(153, 147, 147), rgb(116, 111, 107), rgb(79, 98, 116)],
                primary: rgb(164, 148, 171), sleep: rgb(153, 147, 147), water: rgb(135, 180, 213),
                roast: rgb(213, 206, 156), softWarm: rgb(213, 206, 156), softCool: rgb(205, 228, 205),
                muted: rgb(116, 111, 107), ugly: rgb(79, 98, 116), canvas: cloudDancer
            )
        case .glamourAndGleam:
            ThemePalette(
                swatches: [rgb(43, 44, 48), cloudDancer, rgb(147, 47, 57), rgb(144, 102, 123), rgb(56, 92, 104), rgb(85, 84, 62), rgb(208, 206, 203), rgb(147, 138, 121)],
                primary: rgb(56, 92, 104), sleep: rgb(147, 47, 57), water: rgb(147, 138, 121),
                roast: rgb(144, 102, 123), softWarm: rgb(208, 206, 203), softCool: rgb(56, 92, 104),
                muted: rgb(85, 84, 62), ugly: rgb(147, 47, 57), canvas: cloudDancer
            )
        }
    }

    func rgb(_ red: Int, _ green: Int, _ blue: Int) -> ThemeRGB {
        ThemeRGB(red, green, blue)
    }

    var cloudDancer: ThemeRGB { rgb(240, 239, 235) }
}

private struct ThemeRGB {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Int, _ green: Int, _ blue: Int) {
        self.red = Double(red) / 255
        self.green = Double(green) / 255
        self.blue = Double(blue) / 255
    }

    private init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    static let black = ThemeRGB(0, 0, 0)
    static let white = ThemeRGB(255, 255, 255)

    var color: Color { Color(red: red, green: green, blue: blue) }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    func mixed(with other: ThemeRGB, amount: Double) -> ThemeRGB {
        let amount = min(max(amount, 0), 1)
        return ThemeRGB(
            red: red + ((other.red - red) * amount),
            green: green + ((other.green - green) * amount),
            blue: blue + ((other.blue - blue) * amount)
        )
    }

    func ensuringContrast(
        _ targetRatio: Double,
        against background: ThemeRGB,
        toward target: ThemeRGB
    ) -> ThemeRGB {
        guard contrastRatio(with: background) < targetRatio else { return self }
        for step in 1...20 {
            let candidate = mixed(with: target, amount: Double(step) / 20)
            if candidate.contrastRatio(with: background) >= targetRatio {
                return candidate
            }
        }
        return target
    }

    private func contrastRatio(with other: ThemeRGB) -> Double {
        let brighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (brighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: Double {
        func linear(_ component: Double) -> Double {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * linear(red)) + (0.7152 * linear(green)) + (0.0722 * linear(blue))
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
