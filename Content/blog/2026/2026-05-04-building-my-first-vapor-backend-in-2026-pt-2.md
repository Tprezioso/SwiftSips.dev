---
title: Building My First Vapor Backend in 2026 pt. 2
date: 2026-05-04 20:38
tags: Swift, ServerSideSwift, Vapor
---
# Building My First Vapor Backend in 2026 pt. 2

In part 1, we set up a Vapor project to use Fluent + Postgres, learned how to run the app locally in our browser, added some starter routes for us to play with, and returned JSON responses using Swift types. In this post, we’re going to build the first real version of LinkVault, our saved-links backend. By the end, we’ll have:

- a Link model
- a migration that creates the links table
- a Postgres-backed app configuration
- request DTOs for clean API input
- CRUD routes for creating, listing, fetching, updating, and deleting links

## Before we start 

Let's go over some of the things we will be using so we have a better understanding overall, starting with Fluent. 
What the hell is Fluent? Fluent gives Vapor a typed way to work with data. Fluent is an ORM (Object-Relational Mapping) centered around model types that represent database structures. These models are then used for CRUD (Create, Read, Update, and Delete) operations.

Next, let's understand what a model is and what migrations are. Our model is a Swift type we use in our app code. This is very similar to how we would make models if you have done any frontend iOS development.
Your migration is the database change that creates or updates the schema.

The Fluent migration docs describe migrations as a kind of version control system for your database, where each migration defines a change and how to undo it. What both models and migrations do is give us a clean Swift model for our app, an explicit history of how the database is evolving, and a repeatable way to build the schema across environments.

## Let's create our Link model

First let's go to the `Models` folder and add a new Swift file called `Link.swift`. Then let's add the following code to our model file:

```swift
import Vapor
import Fluent

final class Link: Model, Content, @unchecked Sendable {
  static let schema = "links"
  
  @ID(key: .id)
  var id: UUID?

  @Field(key: "title")
  var title: String
  
  @Field(key: "url")
  var url: String
  
  @OptionalField(key: "note")
  var note: String?
  
  @Field(key: "is_read")
  var isRead: Bool
  
  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?
  
  init() {}
  
  init(
    id: UUID? = nil,
    title: String,
    url: String,
    note: String? = nil,
    isRead: Bool = false
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.note = note
    self.isRead = isRead
  }
}

```

A few things to know about the code above:

- The `Model` protocol tells Fluent this type maps to a database table.
- The `Content` protocol lets `Link` be encoded as JSON in responses.

Next, let's go over the Fluent wrappers and what each one maps to:

- @ID marks the identifier field of that variable as the ID for our Link model in the database. This is the primary key.
- @Field maps required stored fields to the appropriate table column.
- @OptionalField is the right choice for optional values, like how the note variable can be optional in our model.
- @Timestamp(..., on: .create) gives us a creation timestamp automatically.

These help us create migrations for the database tables that we will store using PostgreSQL.

Definitely take a look at the [Fluent docs](https://docs.vapor.codes/fluent/overview/#models) to get a better explanation of each one of these wrappers.

## Let's create our first migration that builds the database table

Let's start by navigating to our Migrations folder and making a new file called `CreateLink.swift`.

Then let's add the following code:

```swift
import Fluent

struct CreateLink: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("links")
            .id()
            .field("title", .string, .required)
            .field("url", .string, .required)
            .field("note", .string)
            .field("is_read", .bool, .required)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("links").delete()
    }
}
```

This is our first real schema! Let's go over what we just made.

- First, we create a table schema named links
- Then we add an id column so we can identify each row
- Then we add our title and url columns with the appropriate type and make them required.
- Next we add an optional note with its string type
- Then we add a required is_read bool type
- Next we add a created_at datetime type that maps how we want to store a date in our database.
- Finally we call `.create()` to make our table


The migration docs explicitly recommend AsyncMigration for async/await-based apps, and they frame migrations as the safe, repeatable way to evolve database structure over time.

## Next we need to register the database and migration

Because we created this project with Fluent and Postgres selected, our configure.swift file likely already contains a Postgres-related setup. We can check this by going to our `configure.swift` file, where we should see something like the following:

```swift
import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    app.migrations.add(CreateLink())

    // register routes
    try routes(app)
}

```


Awesome! Before we start saving links to our LinkVault, we need a real Postgres database running on our machine.

There are two common ways to do this:

- Docker — easiest to reset and keeps Postgres isolated from your Mac.
- Homebrew — good if you prefer installing Postgres directly on your machine.

For this tutorial series, I recommend Docker because it keeps our project setup clean.

Let's first download [Docker Desktop](https://www.docker.com/products/docker-desktop/). 

***Make sure you have the Docker Desktop app open and running before using any of these docker terminal commands!***

Next in our project, you are going to want to navigate to our `docker-compose.yml` file. From here we should see some really useful terminal commands in the commented-out section at the top. They should look something like this: 

```bash
#   Build images: docker compose build
#      Start app: docker compose up app
# Start database: docker compose up db
# Run migrations: docker compose run migrate
#       Stop all: docker compose down (add -v to wipe db)
#
``` 

Now that we have Docker Desktop open and running, we can run the `docker compose up -d` command in our terminal. This starts our Postgres database, and the `-d` flag we added makes it run in the background. Once that is done doing its thing in the terminal, we can run the following command to make sure everything is working. 

```bash
docker compose ps
``` 

This should print out the current running Postgres service we just started. 
Now we should run the following code:
```bash
docker compose build
docker compose up db
```

Great, we now have a database up and running, but we have nothing in it. 
Now we will set up our migration for our database. We do this by running the following command in our terminal:

```bash
swift run LinkVault migrate
```

This can prompt you for confirmation before executing the new migrations. We can use automatic migration by passing the `--auto-migrate` flag when starting our server to run migrations automatically:

```bash
swift run LinkVault migrate --auto-migrate
```
Nice! Now that we have our migrations applied to our database schema, we will make some DTOs (Data Transfer Objects) for our app.

Let's navigate to our DTOs folder and start by adding a new Swift file called `CreateLinkRequest.swift`.

```swift
import Vapor

struct CreateLinkRequest: Content {
    let title: String
    let url: String
    let note: String?
}
```

We also want to add an `UpdateLinkRequest` DTO:

```swift
import Vapor

struct UpdateLinkRequest: Content {
    let title: String?
    let url: String?
    let note: String?
    let isRead: Bool?
}
```

These DTOs are intentionally simple, but they teach a really valuable habit:
input types should describe API requests, not just mirror your database model because it is convenient.

Since Vapor uses Content for body encoding/decoding, these DTOs plug directly into route handlers with `req.content.decode(...)`.

Now let's go back to our routes file and replace what we had from part 1 with: 

```swift
import Vapor
import Fluent

func routes(_ app: Application) throws {
    // This is a simple health check route.
    // It is useful for confirming that the server is running.
    //
    // GET /health
    app.get("health") { req async in
        ["status": "ok"]
    }

    // This creates a route group with the shared path "/api/links".
    //
    // Instead of writing:
    // app.get("api", "links")
    // app.post("api", "links")
    // app.delete("api", "links", ":linkID")
    //
    // We can group the common path once and define routes inside it.
    let links = app.grouped("api", "links")

    // MARK: - Create a Link

    // This route creates a new link.
    //
    // POST /api/links
    //
    // The request body should look like:
    //
    // {
    //   "title": "Vapor Docs",
    //   "url": "https://docs.vapor.codes",
    //   "note": "Read this later"
    // }
    links.post { req async throws -> Link in
        // Decode the incoming JSON body into our request DTO.
        //
        // CreateLinkRequest is not the database model.
        // It is a small type that describes the JSON we expect from the client.
        let data = try req.content.decode(CreateLinkRequest.self)

        // Create a new Fluent model from the decoded request data.
        //
        // We set isRead to false because a newly saved link should start unread.
        let link = Link(
            title: data.title,
            url: data.url,
            note: data.note,
            isRead: false
        )

        // Save the new Link to the database using Fluent.
        //
        // req.db is the database connection for this request.
        // Because this is async, we use try await.
        try await link.save(on: req.db)

        // Return the saved link as JSON.
        //
        // This works because Link conforms to Content.
        return link
    }

    // MARK: - List Links

    // This route returns all saved links.
    //
    // GET /api/links
    links.get { req async throws -> [Link] in
        // Start a Fluent query for the Link model.
        try await Link.query(on: req.db)
            // Sort the links so the newest ones come first.
            .sort(\.$createdAt, .descending)
            // Execute the query and return all matching rows.
            .all()
    }

    // MARK: - Get One Link

    // This route returns a single link by id.
    //
    // GET /api/links/:linkID
    //
    // Example:
    // GET /api/links/123E4567-E89B-12D3-A456-426614174000
    links.get(":linkID") { req async throws -> Link in
        // Read the "linkID" route parameter from the URL.
        //
        // This corresponds to the ":linkID" part of the route.
        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid linkID")
        }

        // Ask Fluent to find a Link with this id.
        //
        // Link.find returns an optional because the link may not exist.
        guard let link = try await Link.find(linkID, on: req.db) else {
            // If no link exists for that id, return a 404 Not Found response.
            throw Abort(.notFound)
        }

        // Return the found link as JSON.
        return link
    }

    // MARK: - Update a Link

    // This route updates an existing link.
    //
    // PUT /api/links/:linkID
    //
    // The request body can contain any fields we want to update:
    //
    // {
    //   "title": "Updated title",
    //   "isRead": true
    // }
    links.put(":linkID") { req async throws -> Link in
        // Read the id from the URL.
        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid linkID")
        }

        // Find the existing link in the database.
        //
        // We need to fetch it first because updating means:
        // 1. find the existing row
        // 2. change some properties
        // 3. save it again
        guard let link = try await Link.find(linkID, on: req.db) else {
            throw Abort(.notFound)
        }

        // Decode the update request body.
        //
        // Every property on UpdateLinkRequest is optional.
        // This allows the client to update only the fields that changed.
        let data = try req.content.decode(UpdateLinkRequest.self)

        // Only update the title if the client included a new title.
        if let title = data.title {
            link.title = title
        }

        // Only update the URL if the client included a new URL.
        if let url = data.url {
            link.url = url
        }

        // Only update the note if the client included a new note.
        //
        // Important:
        // With this simple version, leaving "note" out means "do not change it."
        // Later, we may improve this to support explicitly clearing the note.
        if let note = data.note {
            link.note = note
        }

        // Only update isRead if the client included it.
        //
        // This lets us mark a link as read or unread.
        if let isRead = data.isRead {
            link.isRead = isRead
        }

        // Save the updated model back to the database.
        try await link.save(on: req.db)

        // Return the updated link as JSON.
        return link
    }

    // MARK: - Delete a Link

    // This route deletes a link.
    //
    // DELETE /api/links/:linkID
    links.delete(":linkID") { req async throws -> HTTPStatus in
        // Read the id from the URL.
        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid linkID")
        }

        // Find the link before deleting it.
        //
        // If it does not exist, return 404.
        guard let link = try await Link.find(linkID, on: req.db) else {
            throw Abort(.notFound)
        }

        // Delete the link from the database.
        try await link.delete(on: req.db)

        // Return 204 No Content.
        //
        // This is a common response for successful DELETE requests.
        // It means the delete worked, but there is no response body.
        return .noContent
    }
}
```

There is a lot going on here, but hopefully the comments around each piece of code help explain what's happening for the `links` paths. Now we have everything in place, our database is running, and our routes are set up. We can now run our app by hitting Command + R. With our app running on localhost 8080, we can have a little fun. Let's test our routes!

First let's test our create link route. Let's go to our terminal and run the following curl command:

```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Vapor Docs",
    "url": "https://docs.vapor.codes",
    "note": "Read the Fluent section next"
  }'
``` 

We saved our first link!! We can check this by going to this route (http://127.0.0.1:8080/api/links) in our browser. 

We should see something like this returned in our browser:

```json
  [
    {
      "title": "Vapor Docs",
      "url": "https://docs.vapor.codes",
      "note": "Read the Fluent section next",
      "isRead": false,
      "id": "89084AC3-75A4-4A25-BA4E-8EFEEE55B378",
      "createdAt": "2026-05-13T21:03:39Z"
    }
  ]
```
Nice!! Now let's test our update route! If we add the following code, we should update the isRead value to true:

```bash
curl -X PUT http://localhost:8080/api/links/89084AC3-75A4-4A25-BA4E-8EFEEE55B378 \
  -H "Content-Type: application/json" \
  -d '{
    "isRead": true
  }'
```

If we refresh our browser, we should see:

```json
  [
    {
      "createdAt": "2026-05-13T21:03:39Z",
      "id": "89084AC3-75A4-4A25-BA4E-8EFEEE55B378",
      "url": "https://docs.vapor.codes",
      "title": "Vapor Docs",
      "note": "Read the Fluent section next",
      "isRead": true
    }
  ]
```

Finally let's test our delete route:

```bash
curl -X DELETE http://localhost:8080/api/links/89084AC3-75A4-4A25-BA4E-8EFEEE55B378
```

Now if we reload, we should see an empty array:

```json
[]
```

Congrats! You now have a genuinely stateful server-side app doing some real CRUD work. You are writing to a database, reading back real records, updating them, and deleting them through HTTP! I think it's time to add backend Swift engineer to your resume 😉.

## In this post, we:

- introduced Fluent as Vapor’s ORM
- created a Link model
- created a matching migration
- connected the app to Postgres
- registered the migration
- added request DTOs
- built real CRUD endpoints

## What’s next?

In Part 3, we’ll make this backend multi-user by adding:

- a User model
- password hashing
- signup and login
- authentication-protected routes
- ownership so each user only sees their own links

Our LinkVault app will stop being a single-user CRUD service and start becoming a multi-user backend. I have been so excited learning and building this tutorial out! Thanks for following along, and until next time, happy coding! 🤘
