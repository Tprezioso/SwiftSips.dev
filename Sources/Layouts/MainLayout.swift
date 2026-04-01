import Foundation
import Ignite

struct MainLayout: Layout {
    @Environment(\.siteConfiguration) private var siteConfiguration

    var body: some HTML {
        HTMLDocument {
            HTMLHead(for: page, with: siteConfiguration)
            HTMLBody {
                // Swift orange accent bar
                Section {}
                    .background(Color(hex: "#F05138"))
                    .frame(height: .px(4))
                    .ignorePageGutters()

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
