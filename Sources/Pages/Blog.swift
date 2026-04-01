import Foundation
import Ignite

struct Blog: StaticLayout {
    var title = "Blog"

    @Environment(\.content) var content

    var body: some HTML {
        let blogPosts = content.typed("blog").sorted(by: { $0.date }, order: .reverse)

        // Hero section
        Section {
            Text("Swift Sips")
                .font(.title1)
                .fontWeight(.black)
                .margin(.top, .xLarge)

            Text("Small sips of Swift wisdom. A blog about Swift and iOS development by Thomas Prezioso Jr.")
                .font(.lead)
                .foregroundStyle(.secondary)
                .margin(.bottom, .large)
        }
        .transition(.fadeIn.duration(0.6), on: .appear)

        Divider()
            .margin(.bottom, .large)

        // Featured latest post (hero card)
        if let latest = blogPosts.first {
            Card(imageName: latest.image) {
                Text(latest.description)
                    .margin(.bottom, .small)

                Group {
                    Text(formattedDate(latest.date))
                        .foregroundStyle(.secondary)

                    Text("\(latest.estimatedReadingMinutes) min read")
                        .foregroundStyle(.secondary)
                }
                .margin(.bottom, .small)

                Link("Read Article", target: latest.path)
                    .linkStyle(.button)
                    .role(.primary)
            } header: {
                Badge("Latest")
                    .role(.danger)
                    .badgeStyle(.subtleBordered)
                    .margin(.bottom, .small)

                Text {
                    Link(latest)
                        .role(.none)
                }
                .font(.title2)
                .fontWeight(.bold)
            } footer: {
                let tagLinks = latest.tagLinks()
                if tagLinks.isEmpty == false {
                    Section {
                        tagLinks
                    }
                    .style("margin-top: -5px")
                }
            }
            .cardStyle(.bordered)
            .shadow(radius: 6, y: 3)
            .margin(.bottom, .xLarge)
            .transition(.fadeIn.duration(0.8), on: .appear)
        }

        // Remaining posts in grid
        if blogPosts.count > 1 {
            Text("More Posts")
                .font(.title3)
                .fontWeight(.bold)
                .margin(.bottom, .medium)

            Grid(spacing: .medium) {
                ForEach(blogPosts.dropFirst()) { item in
                    Card(imageName: item.image) {
                        Text(item.description)
                            .margin(.bottom, .small)

                        Text(formattedDate(item.date))
                            .foregroundStyle(.secondary)
                            .font(.body)

                        Text("\(item.estimatedReadingMinutes) min read")
                            .foregroundStyle(.secondary)
                            .font(.body)
                            .margin(.bottom, .small)

                        Link("Read More", target: item.path)
                            .linkStyle(.button)
                            .role(.primary)
                            .buttonSize(.small)
                    } header: {
                        Text {
                            Link(item)
                                .role(.none)
                        }
                        .font(.title4)
                        .fontWeight(.bold)
                    } footer: {
                        let tagLinks = item.tagLinks()
                        if tagLinks.isEmpty == false {
                            Section {
                                tagLinks
                            }
                            .style("margin-top: -5px")
                        }
                    }
                    .cardStyle(.bordered)
                    .shadow(radius: 4, y: 2)
                    .hoverEffect { element in
                        element.shadow(radius: 12, y: 6)
                    }
                    .transition(.fadeIn.duration(0.6), on: .appear)
                }
            }
            .columns(2)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
