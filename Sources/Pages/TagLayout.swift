import Foundation
import Ignite

struct Tags: TagLayout {
    @Environment(\.content) var allContent

    var body: some HTML {
        if let tag {
            Text("Posts tagged: \(tag)")
                .font(.title1)
                .fontWeight(.black)
                .margin(.top, .large)

            let blogPosts = content.filter { $0.type == "blog" }
            let archivePosts = content.filter { $0.type == "archive" }

            if blogPosts.isEmpty == false {
                Section {
                    ForEach(blogPosts.sorted(by: { $0.date }, order: .reverse)) { post in
                        Card {
                            Text(post.description)
                                .margin(.bottom, .none)

                            Text(formattedDate(post.date))
                                .foregroundStyle(.secondary)
                                .font(.body)
                        } header: {
                            Text {
                                Link(post)
                                    .role(.none)
                            }
                            .font(.title3)
                        }
                        .margin(.top, 15)
                    }
                }
            }

            if archivePosts.isEmpty == false {
                Text("Archived Posts")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .margin(.top, .xLarge)

                List {
                    ForEach(archivePosts.sorted(by: { $0.date }, order: .reverse)) { post in
                        Link(post)
                    }
                }
                .listStyle(.flushGroup)
            }
        } else {
            Text("All Tags")
                .font(.title1)
                .fontWeight(.black)
                .margin(.top, .large)

            let allTags = Set(allContent.all.flatMap { $0.tags }).sorted()

            Section {
                ForEach(allTags) { tag in
                    let tagPath = tag.lowercased().replacing(" ", with: "-")
                    Link(target: "/tags/\(tagPath)") {
                        Badge(tag)
                            .role(.primary)
                            .margin(.trailing, .px(5))
                            .margin(.bottom, .px(8))
                    }
                }
            }

            List {
                ForEach(content.sorted(by: { $0.date }, order: .reverse)) { article in
                    Link(article)
                }
            }
            .listStyle(.flushGroup)
            .margin(.top, .large)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
