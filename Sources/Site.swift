import Foundation
import Ignite

@main
struct IgniteWebsite {
    static func main() async {
        let site = SwiftSipsSite()

        do {
            try await site.publish()
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct SwiftSipsSite: Site {
    var name = "Swift Sips"
    var titleSuffix = " | Swift Sips"
    var url = URL(static: "https://swiftsips.dev")
    var builtInIconsEnabled = true

    var author = "Thomas Prezioso Jr"
    var homePage = Blog()
    var tagLayout = Tags()
    var lightTheme: (any Theme)? = SwiftSipsLightTheme()
    var darkTheme: (any Theme)? = SwiftSipsDarkTheme()
    var staticLayouts: [any StaticLayout] = [Blog(), Archive(), About()]
    var contentLayouts: [any ContentLayout] {
        BlogPostLayout()
    }
    var layout = MainLayout()
    var prettifyHTML = true
    var syntaxHighlightingEnabled = true
    var syntaxHighlighters: [HighlighterLanguage] = [.swift]
}
