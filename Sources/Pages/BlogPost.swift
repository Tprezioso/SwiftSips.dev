//
//  File.swift
//  IgniteStarter
//
//  Created by Thomas Prezioso Jr on 1/10/25.
//

import Foundation
import Ignite

struct BlogPost: ContentLayout {
    var body: some HTML {
        Text(content.title)
            .font(.title1)
//번호 : 050, 작성일자: 2024-12-23
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
