import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public extension Color {
    /// A dynamic color that follows the system light/dark appearance.
    init(_ themed: ThemedColor) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? themed.dark : themed.light
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? themed.dark : themed.light
            return NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
        #endif
    }

    init(_ rgb: RGB) { self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1) }

    static let nuriGround = Color(NuriPalette.ground)
    static let nuriSurface = Color(NuriPalette.surface)
    static let nuriInk = Color(NuriPalette.ink)
    static let nuriInkSoft = Color(NuriPalette.inkSoft)
    static let nuriTint = Color(NuriPalette.tint)
    static let nuriTintPressed = Color(NuriPalette.tintPressed)
    static let nuriOnTint = Color(NuriPalette.onTint)
    static let nuriProgress = Color(NuriPalette.progress)
    static let nuriTrack = Color(NuriPalette.track)
    static let nuriLink = Color(NuriPalette.link)
    static let nuriSeparator = Color(NuriPalette.separator)
    static let nuriFillSecondary = Color(NuriPalette.fillSecondary)
    static let nuriSand = Color(NuriPalette.sand)
    static let nuriVerified = Color(NuriPalette.verified)
    static let nuriManufacturer = Color(NuriPalette.manufacturer)
    static let nuriCommunity = Color(NuriPalette.community)
    static let nuriAdLabel = Color(NuriPalette.adLabel)
    static let nuriAdOutline = Color(NuriPalette.adOutline)
    static let nuriNotice = Color(NuriPalette.notice)
    static let nuriNoticeInk = Color(NuriPalette.noticeInk)
    static let nuriToast = Color(NuriPalette.toast)
    static let nuriOnToast = Color(NuriPalette.onToast)
    static let nuriToastAction = Color(NuriPalette.toastAction)
    static let nuriDisabledFill = Color(NuriPalette.disabledFill)
    static let nuriDisabledText = Color(NuriPalette.disabledText)
    static let nuriChevron = Color(NuriPalette.chevron)
    static let nuriDestructive = Color(NuriPalette.destructive)
}
