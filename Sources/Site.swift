import Foundation
import Ignite

@main
struct IgniteWebsite {
    static func main() async {
        let site = ExampleSite()

        do {
            try await site.publish()
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct ExampleSite: Site {
  var name = "Hello World"
  var titleSuffix = " – My Awesome Site"
  var url = URL(static: "https://www.example.com")
  var builtInIconsEnabled = true

  var author = "Thomas Prezioso Jr"
  var homePage = Blog()
  var staticLayouts: [any StaticLayout] = [Blog()]
  var contentLayouts: [any ContentLayout] {
    BlogPostLayout()
  }
  var layout = MainLayout()
  var prettifyHTML = true
}
