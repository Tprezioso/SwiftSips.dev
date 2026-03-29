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
            .margin(.top, .large)

        Alert {
            Text("These posts were originally published on my WordPress blog between 2019 and 2021. Some code examples may reference older versions of Swift or SwiftUI, but I've kept them here for reference.")
        }
        .role(.info)
        .margin(.bottom, .large)

        let archivePosts = content.typed("archive").sorted(by: { $0.date }, order: .reverse)
        let groupedByYear = Dictionary(grouping: archivePosts) { item in
            Calendar.current.component(.year, from: item.date)
        }

        ForEach(groupedByYear.keys.sorted().reversed()) { year in
            Text("\(year)")
                .font(.title2)
                .fontWeight(.bold)
                .margin(.top, .large)

            if let posts = groupedByYear[year] {
                List {
                    ForEach(posts) { post in
                        Group {
                            Text {
                                Link(post)
                            }
                            .font(.title5)
                            .margin(.bottom, .none)

                            Text(formattedDate(post.date))
                                .foregroundStyle(.secondary)
                                .font(.body)
                        }
                    }
                }
                .listStyle(.flushGroup)
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
