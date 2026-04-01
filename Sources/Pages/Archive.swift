import Foundation
import Ignite

struct Archive: StaticLayout {
    var title = "Archive"
    var description = "Archived blog posts from the original Swift Sips WordPress site (2019-2021)."

    @Environment(\.content) var content

    var body: some HTML {
        Text("Archive")
            .font(.title1)
            .fontWeight(.black)
            .margin(.top, .xLarge)

        Text("Posts from the original WordPress blog, preserved for reference.")
            .font(.lead)
            .foregroundStyle(.secondary)
            .margin(.bottom, .medium)

        Divider()
            .margin(.bottom, .large)

        Alert {
            Text {
                Image(systemName: "info-circle")
                " These posts were originally published between 2019 and 2021. Some code examples may reference older versions of Swift or SwiftUI, but I've kept them here for reference."
            }
        }
        .role(.info)
        .margin(.bottom, .xLarge)

        let archivePosts = content.typed("archive").sorted(by: { $0.date }, order: .reverse)
        let groupedByYear = Dictionary(grouping: archivePosts) { item in
            Calendar.current.component(.year, from: item.date)
        }

        ForEach(groupedByYear.keys.sorted().reversed()) { year in
            Text("\(year)")
                .font(.title2)
                .fontWeight(.bold)
                .margin(.top, .large)
                .margin(.bottom, .medium)

            if let posts = groupedByYear[year] {
                Badge("\(posts.count) posts")
                    .role(.primary)
                    .badgeStyle(.subtleBordered)
                    .margin(.bottom, .medium)

                Grid(spacing: .medium) {
                    ForEach(posts) { post in
                        Card {
                            Text(post.description)
                                .foregroundStyle(.secondary)
                                .margin(.bottom, .small)

                            Group {
                                Badge(formattedDate(post.date))
                                    .role(.secondary)
                                    .badgeStyle(.subtleBordered)
                                    .margin(.trailing, .small)

                                Badge("\(post.estimatedReadingMinutes) min read")
                                    .role(.info)
                                    .badgeStyle(.subtleBordered)
                            }
                            .margin(.bottom, .small)

                            Link("Read Post", target: post.path)
                                .linkStyle(.button)
                                .role(.primary)
                                .buttonSize(.small)
                        } header: {
                            Text {
                                Link(post)
                                    .role(.none)
                            }
                            .font(.title5)
                            .fontWeight(.bold)
                        }
                        .cardStyle(.bordered)
                        .shadow(radius: 3, y: 2)
                        .hoverEffect { element in
                            element.shadow(radius: 10, y: 5)
                        }
                        .transition(.fadeIn.duration(0.5), on: .appear)
                    }
                }
                .columns(2)
            }
        }

        // Back to top
        Divider()
            .margin(.top, .xLarge)

        Section {
            Link(target: "#") {
                Image(systemName: "arrow-up-circle")
                " Back to top"
            }
            .linkStyle(.button)
            .role(.secondary)
            .buttonSize(.small)
        }
        .horizontalAlignment(.center)
        .margin(.top, .medium)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
