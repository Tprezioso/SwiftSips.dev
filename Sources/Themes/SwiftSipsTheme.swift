import Foundation
import Ignite

struct SwiftSipsLightTheme: LightTheme {
    static var name = "swift-sips-light"

    // Swift-inspired orange and blue
    var accent: Color = Color(hex: "#F05138")           // Swift orange
    var secondaryAccent: Color = Color(hex: "#0071E3")   // Apple blue

    var success: Color = Color(hex: "#34C759")
    var info: Color = Color(hex: "#0071E3")
    var warning: Color = Color(hex: "#FF9500")
    var danger: Color = Color(hex: "#FF3B30")

    var light: Color = Color(hex: "#F5F5F7")
    var dark: Color = Color(hex: "#1D1D1F")

    var primary: Color = Color(hex: "#1D1D1F")
    var emphasis: Color = Color(hex: "#000000")
    var secondary: Color = Color(red: 29, green: 29, blue: 31, opacity: 0.6)
    var tertiary: Color = Color(red: 29, green: 29, blue: 31, opacity: 0.4)

    var background: Color = Color(hex: "#FFFFFF")
    var secondaryBackground: Color = Color(hex: "#F5F5F7")
    var tertiaryBackground: Color = Color(hex: "#FBFBFD")

    var link: Color = Color(hex: "#F05138")
    var linkHover: Color = Color(hex: "#D63D25")
    var linkDecoration: TextDecoration = .none

    var border: Color = Color(hex: "#E5E5EA")
    var heading: Color = Color(hex: "#1D1D1F")

    var headingFont: Font = .default
    var font: Font = .default
}

struct SwiftSipsDarkTheme: DarkTheme {
    static var name = "swift-sips-dark"

    var accent: Color = Color(hex: "#F05138")
    var secondaryAccent: Color = Color(hex: "#2997FF")

    var success: Color = Color(hex: "#30D158")
    var info: Color = Color(hex: "#2997FF")
    var warning: Color = Color(hex: "#FFD60A")
    var danger: Color = Color(hex: "#FF453A")

    var light: Color = Color(hex: "#F5F5F7")
    var dark: Color = Color(hex: "#1D1D1F")

    var primary: Color = Color(hex: "#F5F5F7")
    var emphasis: Color = Color(hex: "#FFFFFF")
    var secondary: Color = Color(red: 245, green: 245, blue: 247, opacity: 0.6)
    var tertiary: Color = Color(red: 245, green: 245, blue: 247, opacity: 0.4)

    var background: Color = Color(hex: "#000000")
    var secondaryBackground: Color = Color(hex: "#1C1C1E")
    var tertiaryBackground: Color = Color(hex: "#2C2C2E")

    var link: Color = Color(hex: "#F05138")
    var linkHover: Color = Color(hex: "#FF6F59")
    var linkDecoration: TextDecoration = .none

    var border: Color = Color(hex: "#38383A")
    var heading: Color = Color(hex: "#F5F5F7")

    var headingFont: Font = .default
    var font: Font = .default
}
