import Foundation
import Ignite

struct SiteFooter: HTML {
    var body: some HTML {
        Divider()
            .margin(.top, .xLarge)

        Section {
            // Back to top
            Link(target: "#") {
                Image(systemName: "arrow-up-circle")
                " Back to top"
            }
            .role(.secondary)
            .margin(.bottom, .large)

            Group {
                Link(target: "https://github.com/tprezioso") {
                    Image(systemName: "github")
                }
                .linkStyle(.button)
                .role(.dark)
                .buttonSize(.small)
                .margin(.trailing, .small)

                Link(target: "https://x.com/tommyprezioso") {
                    Image(systemName: "twitter-x")
                }
                .linkStyle(.button)
                .role(.dark)
                .buttonSize(.small)
                .margin(.trailing, .small)

                Link(target: "https://bsky.app/profile/tommyprezioso.bsky.social") {
                    Image(systemName: "cloud-fill")
                }
                .linkStyle(.button)
                .role(.info)
                .buttonSize(.small)
            }
            .margin(.bottom, .medium)

            Text {
                Image(systemName: "rss-fill")
                    .foregroundStyle("#f26522")
                    .margin(.trailing, .px(10))

                Link("RSS Feed", target: "/feed.rss")
            }
            .horizontalAlignment(.center)
            .margin(.bottom, .medium)

            Text("© 2026 Thomas Prezioso Jr. All rights reserved.")
                .foregroundStyle(.tertiary)
                .font(.body)

            Text {
                "Built with Swift using "
                Link("Ignite", target: "https://github.com/twostraws/Ignite")
            }
            .foregroundStyle(.tertiary)
            .font(.body)
            .margin(.bottom, .medium)
        }
        .horizontalAlignment(.center)
        .padding(.vertical, .large)
    }
}
