import Foundation
import Ignite

struct BlogPostLayout: ContentLayout {
    @Environment(\.siteConfiguration) private var siteConfiguration

    var body: some HTML {
        if content.type == "archive" {
            Alert {
                Text("This is an archived post from my old WordPress blog. Some code examples may reference older versions of Swift or SwiftUI.")
            }
            .role(.warning)
            .margin(.bottom, .medium)
        }

        Text(content.title)
            .font(.title1)

        Group {
            Text(formattedDate(content.date))
                .foregroundStyle(.secondary)

            Text("By \(content.author ?? siteConfiguration.author)")
                .foregroundStyle(.secondary)

            Text("\(content.estimatedReadingMinutes) min read")
                .foregroundStyle(.secondary)
        }
        .margin(.bottom, .medium)

        if let image = content.image {
            Image(image, description: content.imageDescription)
                .resizable()
                .cornerRadius(20)
                .frame(maxHeight: 300)
                .margin(.bottom, .medium)
        }

        if content.hasTags {
            Section {
                content.tagLinks()
            }
            .margin(.bottom, .medium)
        }

        Text(content.body)

        Section {
            Text("Share this post")
                .font(.title5)
                .foregroundStyle(.secondary)

            Group {
                Link(target: "https://twitter.com/intent/tweet?text=\(content.title)") {
                    Image(systemName: "twitter-x")
                    " Post on X"
                }
                .margin(.trailing, .medium)

                Link(target: "https://www.linkedin.com/sharing/share-offsite/") {
                    Image(systemName: "linkedin")
                    " Share on LinkedIn"
                }
            }
        }
        .margin(.top, .xLarge)
        .padding(.top, .medium)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
