import Foundation
import Ignite

struct MainLayout: Layout {
    @Environment(\.siteConfiguration) private var siteConfiguration

    var body: some HTML {
        HTMLDocument {
            HTMLHead(for: page, with: siteConfiguration)
            HTMLBody {
                NavigationBar(logo: "Swift Sips") {
                    Link("Blog", target: Blog())
                    Link("Archive", target: Archive())
                    Link("About", target: About())
                }
                .navigationBarStyle(.dark)
                .navigationItemAlignment(.trailing)
                .background(.ultraThickMaterial)
                .ignorePageGutters()
            }
            HTMLBody(for: page)
            HTMLBody {
                SiteFooter()
            }
        }
    }
}
