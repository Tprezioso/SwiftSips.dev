import Foundation
import Ignite

struct Tags: TagLayout {
    @Environment(\.content) var allContent

    var body: some HTML {
        if let tag {
            Text("Posts tagged: \(tag)")
                .font(.title1)
                .fontWeight(.black)
                .margin(.top, .xLarge)

            Divider()
                .margin(.bottom, .large)

            let blogPosts = content.filter { $0.type == "blog" }
            let archivePosts = content.filter { $0.type == "archive" }

            if blogPosts.isEmpty == false {
                Grid(spacing: .medium) {
                    ForEach(blogPosts.sorted(by: { $0.date }, order: .reverse)) { post in
                        Card {
                            Text(post.description)
                                .margin(.bottom, .small)

                            Group {
                                Badge(formattedDate(post.date))
                                    .role(.primary)
                                    .badgeStyle(.subtleBordered)
                                    .margin(.trailing, .small)

                                Badge("\(post.estimatedReadingMinutes) min read")
                                    .role(.info)
                                    .badgeStyle(.subtleBordered)
                            }
                            .margin(.bottom, .small)

                            Link("Read More", target: post.path)
                                .linkStyle(.button)
                                .role(.primary)
                                .buttonSize(.small)
                        } header: {
                            Text {
                                Link(post)
                                    .role(.none)
                            }
                            .font(.title4)
                            .fontWeight(.bold)
                        }
                        .cardStyle(.bordered)
                        .shadow(radius: 4, y: 2)
                        .hoverEffect { element in
                            element.shadow(radius: 10, y: 5)
                        }
                        .transition(.fadeIn.duration(0.5), on: .appear)
                    }
                }
                .columns(2)
            }

            if archivePosts.isEmpty == false {
                Text("Archived Posts")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .margin(.top, .xLarge)
                    .margin(.bottom, .medium)

                Grid(spacing: .medium) {
                    ForEach(archivePosts.sorted(by: { $0.date }, order: .reverse)) { post in
                        Card {
                            Text(post.description)
                                .foregroundStyle(.secondary)
                                .margin(.bottom, .small)

                            Badge(formattedDate(post.date))
                                .role(.secondary)
                                .badgeStyle(.subtleBordered)
                                .margin(.bottom, .small)

                            Link("Read Post", target: post.path)
                                .linkStyle(.button)
                                .role(.secondary)
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
                        .transition(.fadeIn.duration(0.5), on: .appear)
                    }
                }
                .columns(2)
            }
        } else {
            Text("All Tags")
                .font(.title1)
                .fontWeight(.black)
                .margin(.top, .xLarge)

            Divider()
                .margin(.bottom, .large)

            // Tag cloud with counts
            let allTags = Set(allContent.all.flatMap { $0.tags }).sorted()

            Section {
                ForEach(allTags) { tag in
                    let tagPath = tag.lowercased().replacing(" ", with: "-")
                    let count = allContent.all.filter { $0.tags.contains(tag) }.count
                    Link(target: "/tags/\(tagPath)") {
                        Badge("\(tag) (\(count))")
                            .role(.primary)
                            .badgeStyle(.subtleBordered)
                            .margin(.trailing, .px(5))
                            .margin(.bottom, .px(10))
                    }
                }
            }
            .margin(.bottom, .xLarge)

            Text("All Posts")
                .font(.title3)
                .fontWeight(.bold)
                .margin(.bottom, .medium)

            Grid(spacing: .medium) {
                ForEach(content.sorted(by: { $0.date }, order: .reverse)) { article in
                    Card {
                        Text(formattedDate(article.date))
                            .foregroundStyle(.secondary)
                            .margin(.bottom, .small)

                        Link("Read More", target: article.path)
                            .linkStyle(.button)
                            .role(.primary)
                            .buttonSize(.small)
                    } header: {
                        Text {
                            Link(article)
                                .role(.none)
                        }
                        .font(.title5)
                        .fontWeight(.bold)
                    }
                    .cardStyle(.bordered)
                    .shadow(radius: 3, y: 2)
                    .transition(.fadeIn.duration(0.5), on: .appear)
                }
            }
            .columns(3)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
