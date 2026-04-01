import Foundation
import Ignite

struct About: StaticLayout {
    var title = "About"
    var description = "About Thomas Prezioso Jr, the author of Swift Sips."

    var body: some HTML {
        Text("About")
            .font(.title1)
            .fontWeight(.black)
            .margin(.top, .xLarge)

        Divider()
            .margin(.bottom, .large)

        // Avatar / icon section
        Section {
            Text {
                Image(systemName: "person-circle")
            }
            .margin(.bottom, .small)
            .class("display-1 text-danger")

            Text("Thomas Prezioso Jr")
                .font(.title2)
                .fontWeight(.bold)

            Text("iOS Developer & Swift Enthusiast")
                .foregroundStyle(.secondary)
                .font(.lead)
                .margin(.bottom, .large)
        }
        .horizontalAlignment(.center)
        .transition(.fadeIn.duration(0.6), on: .appear)

        Grid(spacing: .large) {
            Card {
                Text {
                    Image(systemName: "code-slash")
                    " About Me"
                }
                .font(.title4)
                .fontWeight(.bold)
                .margin(.bottom, .small)

                Text("I'm an iOS developer who is passionate about Swift and building great apps. This blog is where I share small sips of Swift wisdom — tutorials, tips, and things I've learned along the way.")
                    .margin(.bottom, .medium)

                Text("Whether you're just getting started with Swift or looking to level up, I hope you find something useful here.")
            }
            .cardStyle(.bordered)
            .shadow(radius: 6, y: 3)
            .transition(.fadeIn.duration(0.7), on: .appear)

            Card {
                Text {
                    Image(systemName: "link-45deg")
                    " Connect"
                }
                .font(.title4)
                .fontWeight(.bold)
                .margin(.bottom, .medium)

                Group {
                    Link(target: "https://github.com/tprezioso") {
                        Image(systemName: "github")
                        " GitHub"
                    }
                    .linkStyle(.button)
                    .role(.dark)
                    .margin(.bottom, .small)
                }

                Group {
                    Link(target: "https://x.com/tommyprezioso") {
                        Image(systemName: "twitter-x")
                        " X / Twitter"
                    }
                    .linkStyle(.button)
                    .role(.dark)
                }
            }
            .cardStyle(.bordered)
            .shadow(radius: 6, y: 3)
            .transition(.fadeIn.duration(0.7), on: .appear)
        }
        .columns(2)
        .margin(.bottom, .xLarge)

        Card {
            Text {
                Image(systemName: "swift")
                " This Site"
            }
            .font(.title4)
            .fontWeight(.bold)
            .margin(.bottom, .small)

            Text {
                "Swift Sips is built entirely in Swift using the "
                Link("Ignite", target: "https://github.com/twostraws/Ignite")
                " static site generator by Paul Hudson. No JavaScript frameworks, no complex build tools — just Swift all the way down."
            }
        }
        .cardStyle(.bordered)
        .shadow(radius: 4, y: 2)
        .transition(.fadeIn.duration(0.8), on: .appear)
    }
}
