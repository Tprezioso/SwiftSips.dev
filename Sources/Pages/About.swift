import Foundation
import Ignite

struct About: StaticLayout {
    var title = "About"
    var description = "About Thomas Prezioso Jr, the author of Swift Sips."

    var body: some HTML {
        Text("About")
            .font(.title1)
            .fontWeight(.black)
            .margin(.top, .large)

        Text("Hi, I'm Thomas Prezioso Jr.")
            .font(.title3)
            .margin(.bottom, .small)

        Text("I'm an iOS developer who is passionate about Swift and building great apps. This blog is where I share small sips of Swift wisdom — tutorials, tips, and things I've learned along the way.")
            .margin(.bottom, .medium)

        Text("Whether you're just getting started with Swift or looking to level up, I hope you find something useful here.")
            .margin(.bottom, .large)

        Text("Connect")
            .font(.title3)
            .fontWeight(.bold)
            .margin(.bottom, .small)

        Group {
            Link(target: "https://github.com/tprezioso") {
                Image(systemName: "github")
                " GitHub"
            }
            .margin(.trailing, .medium)

            Link(target: "https://x.com/tommyprezioso") {
                Image(systemName: "twitter-x")
                " X / Twitter"
            }
        }
        .margin(.bottom, .large)

        Text("This Site")
            .font(.title3)
            .fontWeight(.bold)
            .margin(.bottom, .small)

        Text {
            "Swift Sips is built entirely in Swift using the "
            Link("Ignite", target: "https://github.com/twostraws/Ignite")
            " static site generator by Paul Hudson."
        }
    }
}
