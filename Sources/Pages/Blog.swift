import Foundation
import Ignite

struct Blog: StaticLayout {
    var title = "Blog"

    @Environment(\.content) var content

    var body: some HTML {
        Group {
            Section {
                Text("Swift Sips")
                    .font(.title1)
                    .fontWeight(.black)
                    .margin(.top, .large)

                Text("Small sips of Swift wisdom. A blog about Swift and iOS development by Thomas Prezioso Jr.")
                    .font(.lead)
                    .foregroundStyle(.secondary)
                    .margin(.bottom, .large)
            }

            Section {
                ForEach(content.typed("blog").sorted(by: { $0.date }, order: .reverse)) { item in
                    Card(imageName: item.image) {
                        Text(item.description)
                            .margin(.bottom, .none)

                        Text(formattedDate(item.date))
                            .foregroundStyle(.secondary)
                            .font(.body)
                            .margin(.bottom, .small)

                        Text("\(item.estimatedReadingMinutes) min read")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    } header: {
                        Text {
                            Link(item)
                                .role(.none)
                        }
                        .font(.title2)
                    } footer: {
                        let tagLinks = item.tagLinks()

                        if tagLinks.isEmpty == false {
                            Section {
                                tagLinks
                            }
                            .style("margin-top: -5px")
                        }
                    }
                    .margin(.top, 20)
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
