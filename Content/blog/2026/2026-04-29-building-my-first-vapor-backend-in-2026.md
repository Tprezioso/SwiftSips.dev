---
title: Building My First Vapor Backend in 2026 pt. 1
date: 2026-04-29 12:49
tags: Swift, ServerSideSwift, Vapor
---
# Building My First Vapor Backend in 2026 pt. 1

I really want to learn how to build server side swift apps! 

For years I have been doing frontend iOS development without really knowing what was happening when I made a HTTP request to a server. I know at a high level whats going on but I have never dove into writing my own backend for an app or website. 

This year that changes! I have tried to learn server side swift in the past but either gave up because I had to much going on in my life (Now with 2 kids) or didn't have a project I was building it for.

This year that changes. With my revival of this blog, I thought I would take another try at learning server side swift.

If you’re a Swift developer and you want to learn backend development in 2026, Vapor is still one of the best places to start. Hummingbird is a fantastic option too but I am choosing to start with Vapor just because Vapor gives you everything you need out of the box to start building your backend. With not really knowing what I am doing this is a fantastic place to start.

In this series of posts we are going to be building a real backend project step by step and evolve it into something "production-ready". Recently I make an app that saves URL links into a list and allows you to tag, search, and read from those links. For my TrapprKeeper app I used SQLite-Data (a fantastic framework by the amazing team at Point Free) but I want to see how I can build similar functionality making my own server side backend.

The real benefit is that if you already know Swift, Codable, async/await, and basic app architecture, you are not starting from zero. You are really learning how to apply familiar Swift skills to HTTP APIs and backend systems. 

The official Vapor docs show two very useful ways to create a project:

`vapor new hello -n` for a bare-bones template that auto-answers no to the setup questions

or

`vapor new app-name` for an interactive setup flow where you choose the options you want

For this series, I want to use the interactive version because it teaches the easiest way to setup a project for beginners. 

---

## What we are building:

Our project will be called **LinkVault**.

Eventually, this backend will let users:

- save links
- organize them into collections
- tag them
- search through them
- mark them read or unread
- sync metadata in the background

But in Part 1, of what I suspect will be an on going series of posts, we are only setting up the project and creating the first routes.

---

## Prerequisites:

Before we start lets make sure you have:

- A Mac or a Linux machine with Swift installed via Xcode if using a Mac or the Swift toolchain if you are on Linux
- Homebrew installed
- a terminal you are comfortable using
- And a coding editor (Xcode if you are on a back or VSCode or some other editor)

For this tutorial I will be using a Mac so from here on down I will be going through the Mac way of building this project.

First thing we need to do is open our terminal and type:
```bash
brew install vapor
```

This will install the Vapor framework onto our machines. This
Once that is finished installing we will run:
```bash
vapor --help
```
This is to just show that everything we just installed correctly and working.

Now that Vapor is installed lets create our project:

```bash
vapor new LinkVault
```

This command opens Vapor's interactive prompt so you can choose the features you want in your starting template. Vapor recommends we select Fluent and Postgres so we will pick both of these choices for out app.

As we are prompted in our terminal we will pick 
- Fluent
- Postgres
- No Leaf

So why these choices?

**Fluent** is Vapor’s ORM and database abstraction layer. We are going to use it throughout the series for models, migrations, and database queries.

**Postgres** is the database we are using for this backend tutorial. The official Vapor docs specifically recommend Fluent with Postgres for database-backed setups, including deployment-oriented guides.

Skipping **Leaf** keeps this series focused on building a JSON API. Leaf is Vapor’s templating engine for generating dynamic HTML pages and email-style rendered output, which is useful, but not what we need for an API-first tutorial.

---

## Setup and Running our app:
Now let's go into our project:

```bash
cd LinkVault
```

Now let's open up LinkVault in Xcode. (Fun trick, if you have Xcode in your Applications folder and you are in the directory you want to open, you can use the command `xed .`. This will open the current directory in Xcode.)

Let's start by just running the app. Make sure your destination in Xcode is set to My Mac and then hit Command + R to run it or click on the play button.

Then we can open a web browser and going to `http://localhost:8080` where we should see the message ***"It works!"***. Congratulations! You just made your first Vapor app! 🥳

---

## Making Our First Route:

Now that we have successfully setup our project and it is running let's make out first custom route.
We can navigate to Sources > LinkVault > routes.swift. Now that we are in the routes folder we can go below the generated code and add the following our own ***health*** route like the code below:

```swift
import Fluent
import Vapor

func routes(_ app: Application) throws {
  app.get { req async in
    "It works!"
  }

  app.get("hello") { req async -> String in
    "Hello, world!"
  }

  try app.register(collection: TodoController())

  app.get("health") { req async in
    ["status": "ok"]
  }
}
``` 

Now lets re-run our app and lets go back to the browser and add `/health` to the end of our localhost url.

```bash
http://127.0.0.1:8080/health
```

We should now be routed to a new page where we will see:

```JSON
{
  "status": "ok"
}
```

A health route may seem small, but it is one of the best habits you can build early. Real backends almost always benefit from having a simple endpoint that proves the server is alive and responding.

Next lets make a typed JSON response. We will do this by using Vapor's `Content` protocol. We are going to add a WelcomeResponse type with a name, message, and our API version.

The Content protocol is Vapor’s main way to encode and decode request and response bodies. It is one of the core ideas we’ll use constantly when building APIs.

Lets update the **routes.swift**:

```swift
import Vapor

struct WelcomeResponse: Content {
    let name: String
    let message: String
    let version: String
}

func routes(_ app: Application) throws {
    app.get("health") { req async in
        ["status": "ok"]
    }

    app.get("api", "welcome") { req async -> WelcomeResponse in
        WelcomeResponse(
            name: "LinkVault API",
            message: "Welcome to the LinkVault backend built with Vapor",
            version: "0.1.0"
        )
    }
}
```

Now if we re-run our app and refresh our browser go to `http://127.0.0.1:8080/api/welcome` we should our new JSON Welcome type being returned.

```JSON
{
  "name": "LinkVault API",
  "version": "0.1.0",
  "message": "Welcome to the LinkVault backend built with Vapor"
}
```

This is one of the places where Vapor feels very natural to someone coming from Swift development. You create a Swift type, return it from a route, and Vapor handles the JSON encoding.

Lastly let create a mock of a future route we are going to use to retrieve our links. Lets start by LinkPreview struct:

```swift
struct LinkPreview: Content {
    let id: UUID
    let title: String
    let url: String
    let isRead: Bool
}
```

Next let's add a some mock data and a new route to our `func routes(_ app: Application)` to return our mocked links.

```swift
    let sampleLinks: [LinkPreview] = [
        .init(
            id: UUID(),
            title: "Vapor Docs",
            url: "https://docs.vapor.codes",
            isRead: false
        ),
        .init(
            id: UUID(),
            title: "Swift.org Server",
            url: "https://swift.org/get-started/cloud-services/",
            isRead: true
        )
    ]
    
    app.get("api", "links") { req async -> [LinkPreview] in
        sampleLinks
    }

```

Now we can re-run our app and reload our browser and we should see:

```JSON
[
  {
    "id": "ED6A2274-0AD9-4771-BBEB-F09BAB239241",
    "title": "Vapor Docs",
    "isRead": false,
    "url": "https://docs.vapor.codes"
  },
  {
    "id": "0F65E5B8-8D60-4A3C-B599-33B55E7217A9",
    "title": "Swift.org Server",
    "isRead": true,
    "url": "https://swift.org/get-started/cloud-services/"
  }
]
```

Awesome! This ends the part 1 of this series of posts I will be doing on learning server side swift. I want to try and keep these posts short and sweet just like a little sip of Swift development (Swift Sips...you see what I did there 🤣). In part 2 we will be taking are new `links` route and we will be replacing it with a real model, a migration, and CRUD database!

So just to recap, in the post we have:
- setup a Vapor project to use Fluent + Postgres
- learned how to run the app locally in our browser
- added some starter routes for use play with
- returned JSON responses using Swift types

## Whats Next?
In Part 2, we’ll take our mocked /api/links route and turn it into a real database-backed API using:

- a Link model
- a Fluent migration
-  some Postgres
- create, list, get, update, and delete endpoints for our links

That is where this project is going to starts to feel like a real backend instead of a starter app. Thanks for following along and until next time, happy coding! 🤘 
