import Foundation
import Ignite

struct MainLayout: Layout {
    
    @Environment(\.siteConfiguration) private var siteConfiguration
    
    var body: some HTML {
        HTMLDocument {
            HTMLHead(for: page, with: siteConfiguration)
          HTMLBody {
            NavigationBar(logo: "Swift Tom") {
                Link("Blog", target: Blog())
            }
            .navigationBarStyle(.dark)
            .navigationItemAlignment(.trailing)
            .background(.darkSlateGray)
          }
            HTMLBody(for: page)
        }
    }
}
