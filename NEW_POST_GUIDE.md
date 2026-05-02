# New Post CLI Guide

## Quick Start

From your project directory, run:

```bash
new-post "Your Post Title"
```

This creates a new markdown file at `Content/blog/YYYY/YYYY-MM-DD-your-post-title.md` with the frontmatter pre-filled.

## Commands

```bash
# Create a post with default "Swift" tag
new-post "My Post Title"

# Create a post with custom tags
new-post "My Post Title" --tags "Swift, SwiftUI, CoreData"

# Short flag for tags
new-post "My Post Title" -t "Swift, SwiftUI"

# Create and immediately open in your default editor
new-post "My Post Title" --tags "Swift, SwiftUI" --open

# Show help
new-post --help
```

## Post Format

The CLI generates a file with this structure:

```markdown
---
title: Your Post Title
date: 2026-04-04 16:00
tags: Swift, SwiftUI
---
# Your Post Title

Write your post here.
```

### Frontmatter Fields

| Field   | Description                          | Example                |
|---------|--------------------------------------|------------------------|
| `title` | The title of your post               | `How to Use TipKit`   |
| `date`  | Auto-generated date and time         | `2026-04-04 16:00`    |
| `tags`  | Comma-separated list of tags         | `Swift, SwiftUI`      |

## Writing Tips

- **Code blocks**: Use triple backticks with `swift` for syntax highlighting
- **Spacing**: Add `<p>&nbsp;</p>` between sections if you need extra vertical space (matches your existing posts)
- **Images**: Use standard markdown `![alt text](url)` syntax
- **Bold links**: Use `**[Link Text](url)**` for bold links (matches your existing style)

## File Organization

```
Content/
  blog/          <-- New posts go here
    2025/
    2026/
  archive/       <-- Older posts (migrated from WordPress)
    2019/
    2020/
    2021/
```

## Rebuilding the CLI

If you make changes to `Sources/NewPost/NewPost.swift`, rebuild and reinstall:

```bash
swift build -c release --product NewPost && cp .build/arm64-apple-macosx/release/NewPost /usr/local/bin/new-post
```

## Important

- Always run `new-post` from inside the project directory (or a subdirectory) so it can find `Package.swift` and place the file correctly.
- The CLI source lives at `Sources/NewPost/NewPost.swift`.
