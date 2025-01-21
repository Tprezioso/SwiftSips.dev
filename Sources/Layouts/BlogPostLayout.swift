//
//  article.swift
//  IgniteStarter
//
//  Created by Thomas Prezioso Jr on 1/10/25.
//

import Foundation
import Ignite

struct BlogPostLayout: ContentLayout {
    @Environment(\.siteConfiguration) private var siteConfiguration
    @Environment(\.content) private var content

    var body: some HTML {
      Text(content.title)
          .font(.title1)

      if let image = content.image {
          Image(image, description: content.imageDescription)
              .resizable()
              .cornerRadius(20)
              .frame(maxHeight: 300)
      }

      if content.hasTags {
          Section {
              Text("Tagged with: \(content.tags.joined(separator: ", "))")

              Text("\(content.estimatedWordCount) words; \(content.estimatedReadingMinutes) minutes to read.")
          }
      }

      
      Text(content.body)
  }
}
