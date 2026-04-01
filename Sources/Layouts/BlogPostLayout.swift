import Foundation
import Ignite

struct BlogPostLayout: ContentLayout {
    @Environment(\.siteConfiguration) private var siteConfiguration

    var body: some HTML {
        if content.type == "archive" {
            Alert {
                Text {
                    Image(systemName: "exclamation-triangle")
                    " This is an archived post from my old WordPress blog. Some code examples may reference older versions of Swift or SwiftUI."
                }
            }
            .role(.warning)
            .margin(.bottom, .medium)
        }

        Text(content.title)
            .font(.title1)
            .fontWeight(.black)

        Group {
            Badge(formattedDate(content.date))
                .role(.primary)
                .badgeStyle(.subtleBordered)
                .margin(.trailing, .small)

            Badge("By \(content.author ?? siteConfiguration.author)")
                .role(.secondary)
                .badgeStyle(.subtleBordered)
                .margin(.trailing, .small)

            Badge("\(content.estimatedReadingMinutes) min read")
                .role(.info)
                .badgeStyle(.subtleBordered)
        }
        .margin(.bottom, .medium)

        if content.hasTags {
            Section {
                content.tagLinks()
            }
            .margin(.bottom, .medium)
        }

        Divider()
            .margin(.bottom, .large)

        if let image = content.image {
            Image(image, description: content.imageDescription)
                .resizable()
                .cornerRadius(12)
                .frame(maxHeight: 400)
                .margin(.bottom, .large)
        }

        Text(content.body)

        Divider()
            .margin(.top, .xLarge)
            .margin(.bottom, .medium)

        Text("Share this post")
            .font(.title5)
            .fontWeight(.bold)
            .margin(.bottom, .small)

        Group {
            Link(target: "https://twitter.com/intent/tweet?text=\(content.title)") {
                Image(systemName: "twitter-x")
                " Post on X"
            }
            .linkStyle(.button)
            .role(.dark)
            .buttonSize(.small)
            .margin(.trailing, .small)

            Link(target: "https://www.linkedin.com/sharing/share-offsite/") {
                Image(systemName: "linkedin")
                " Share on LinkedIn"
            }
            .linkStyle(.button)
            .role(.primary)
            .buttonSize(.small)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
