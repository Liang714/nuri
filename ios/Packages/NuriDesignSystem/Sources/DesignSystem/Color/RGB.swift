import Foundation

/// An sRGB color with channels in 0…1.
public struct RGB: Equatable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

/// A color token with a light and a dark appearance.
public struct ThemedColor: Equatable, Hashable, Sendable {
    public let light: RGB
    public let dark: RGB

    public init(light: UInt32, dark: UInt32) {
        self.light = RGB(hex: light)
        self.dark = RGB(hex: dark)
    }
}

/// WCAG 2.x relative luminance and contrast ratio.
public enum Contrast {
    public static func relativeLuminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    public static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = relativeLuminance(a), lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
