import Foundation
import Ignite

struct SiteFooter: HTML {
    var body: some HTML {
        Section {
            Group {
                Link(target: "https://github.com/tprezioso") {
                    Image(systemName: "github")
                }
                .margin(.trailing, .small)

                Link(target: "https://x.com/tommyprezioso") {
                    Image(systemName: "twitter-x")
                }
            }
            .margin(.bottom, .small)

            Text("© 2025 Thomas Prezioso Jr. All rights reserved.")
                .font(.body)
                .foregroundStyle(.secondary)

            Text {
                "Built with Swift using "
                Link("Ignite", target: "https://github.com/twostraws/Ignite")
            }
            .font(.body)
            .foregroundStyle(.secondary)
        }
        .horizontalAlignment(.center)
        .padding(.vertical, .large)
        .margin(.top, .xLarge)
    }
}
