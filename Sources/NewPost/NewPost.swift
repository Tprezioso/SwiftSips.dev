import ArgumentParser
import Foundation

@main
struct NewPost: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new blog post for SwiftSips.",
        usage: "new-post \"My Post Title\" --tags \"Swift, SwiftUI\""
    )

    @Argument(help: "The title of the blog post.")
    var title: String

    @Option(name: .shortAndLong, help: "Comma-separated tags (e.g. \"Swift, SwiftUI\").")
    var tags: String = "Swift"

    @Flag(name: .shortAndLong, help: "Open the file in your default editor after creation.")
    var open: Bool = false

    func run() throws {
        let now = Date()
        let formatter = DateFormatter()

        // Date for frontmatter: "2026-04-04 16:00"
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let frontmatterDate = formatter.string(from: now)

        // Date prefix for filename: "2026-04-04"
        formatter.dateFormat = "yyyy-MM-dd"
        let datePrefix = formatter.string(from: now)

        // Year for folder: "2026"
        formatter.dateFormat = "yyyy"
        let year = formatter.string(from: now)

        let slug = title
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let filename = "\(datePrefix)-\(slug).md"

        let content = """
        ---
        title: \(title)
        date: \(frontmatterDate)
        tags: \(tags)
        ---
        # \(title)

        Write your post here.
        """

        // Resolve paths relative to the package root (where Package.swift lives)
        let packageRoot = findPackageRoot()
        let dir = packageRoot.appendingPathComponent("Content/blog/\(year)")
        let filePath = dir.appendingPathComponent(filename)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: filePath, atomically: true, encoding: .utf8)

        print("Created: Content/blog/\(year)/\(filename)")

        if open {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [filePath.path]
            try process.run()
        }
    }

    /// Walk up from the current directory to find the folder containing Package.swift.
    private func findPackageRoot() -> URL {
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while dir.path != "/" {
            let packageFile = dir.appendingPathComponent("Package.swift")
            if FileManager.default.fileExists(atPath: packageFile.path) {
                return dir
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fallback to current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
