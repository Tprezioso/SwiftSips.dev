//
//  Blog.swift
//  IgniteStarter
//
//  Created by Thomas Prezioso Jr on 1/10/25.
//
import Foundation
import Ignite

struct Blog: StaticLayout {
    var title = "Home"
  @Environment(\.content) var content
  var body: some HTML {
          Group {
              Text("Blogs")
                  .font(.title1)
                  .fontWeight(.black)
                  .margin(.top, .large)
              Section {
                ForEach(content.all.sorted(by: { $0.date }, order: .reverse)) { content in
                  ContentPreview(for: content)
                    .margin(.top, 20)
                    .foregroundStyle(.primary)
//                  Link(content)
                }
//                  for post in content.all.sorted(by: { $0.date }, order: .reverse) {
//                    ContentPreview(for: post)
//                          .margin(.top, 20)
//                          .foregroundStyle(.primary)
//                  }
              }

          }

    }
}
