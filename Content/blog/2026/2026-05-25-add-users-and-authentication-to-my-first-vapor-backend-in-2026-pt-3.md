---
title: Add Users and Authentication to My First Vapor Backend in 2026 Pt. 3
date: 2026-05-05 13:21
tags: Swift, ServerSideSwift, Vapor
---
# Add Users and Authentication to My First Vapor Backend in 2026 Pt. 3

In Part 2 of this ongoing series about building out my first server-side Swift app, we turned LinkVault from a simple Vapor app into a real database-backed API. We added a Link model, created a migration, connected to Postgres, and built CRUD routes for saving and managing links.

That gave us a working backend, but it still has one major problem: every link belongs to nobody. The goal for this post is to make LinkVault multi-user.

By the end of this post, we will have:

- a User model
- a UserToken model
- password hashing
- signup
- login
- bearer-token authentication
- protected link routes
- links that are associated to a specific user

We will be adding these routes:

```
POST /api/auth/signup
POST /api/auth/login
GET  /api/me
```

Then we will protect our existing links API:

```
POST   /api/links
GET    /api/links
GET    /api/links/:linkID
PATCH  /api/links/:linkID
DELETE /api/links/:linkID
```

Once we are done with Part 3, a user will only be able to see and manage their own saved links.

That is the big shift in our project. We are moving from a database-backed CRUD API to a real user-owned backend API.

## Why are we using bearer tokens? ##

First, what the hell is a bearer token? 🧸

***A bearer token is a security token used to grant access to a protected resource, like an API or a server. The name implies that "whoever bears the token" is granted access. Possession alone is enough to unlock the data; no additional passwords or cryptographic signatures are required for each request.***

## How does it work ##

- Authentication: A client (e.g., your app) logs into a server using credentials.
- Token Issuance: The server verifies the credentials and issues a unique, secure string of characters (often a JSON Web Token or JWT).
- Access: To retrieve protected data, the client sends this token along with every HTTP request in the Authorization header.

The best way to think about using a bearer token is like a concert ticket: anyone holding the physical ticket is allowed into the venue, regardless of who they actually are.

We are going to use a simple bearer-token setup for authentication.

The flow looks like this:

```
User signs up or logs in
        ↓
Server creates a token
        ↓
Client stores the token
        ↓
Client sends the token in the Authorization header
        ↓
Server uses the token to identify the user
```

The request header will look like this:

```
Authorization: Bearer your-bearer-token-here
```

For this tutorial, we will use database-backed bearer tokens, not JWTs... yet.

This setup means that our user tokens are stored in Postgres, and our tokens can be deleted later for logout/revocation. We are using this because it's a little easier to understand for a beginner (me).

Now let's start by creating our User model. Let's go to our Models folder and add a `User.swift` file.

Next, let's add the following code:
```swift
import Vapor
import Fluent

final class User: Model, Content, Authenticatable, @unchecked Sendable {
    // The database table name.
    static let schema = "users"

    // The user's primary key.
    @ID(key: .id)
    var id: UUID?

    // The email address the user logs in with.
    @Field(key: "email")
    var email: String

    // The user's display name.
    @Field(key: "name")
    var name: String

    // The hashed password.
    //
    // Important:
    // Never store the user's raw password in the database.
    @Field(key: "password_hash")
    var passwordHash: String

    // When the user was created.
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        email: String,
        name: String,
        passwordHash: String
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.passwordHash = passwordHash
    }
}
```

The important part here is:

```swift
@Field(key: "password_hash")
var passwordHash: String
```

We are not storing the user’s password. We are storing a hash of the password. **Never store a user's password!**

Vapor’s [password API](https://docs.vapor.codes/security/passwords/) is designed to hash and verify passwords securely, and the docs note that this API supports asynchronous password hashing.

Next, let's add the `UserToken.swift` file to our Models folder. Then let's add the following code:

```swift
import Vapor
import Fluent

final class UserToken: Model, Content, Authenticatable, @unchecked Sendable {
    static let schema = "user_tokens"

    @ID(key: .id)
    var id: UUID?

    // Store the random token value.
    @Field(key: "value")
    var value: String

    // Connect this token to a user.
    @Parent(key: "user_id")
    var user: User

    // Store when the token was created.
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        value: String,
        userID: User.IDValue
    ) {
        self.id = id
        self.value = value
        self.$user.id = userID
    }
}
```

What this model does is give us the one-to-many relationship between the user and the tokens. A user can have many tokens, but each token belongs to one user.

That relationship is represented in the code like this:

```swift
@Parent(key: "user_id")
var user: User
```

Next, we need to create a migration for our user. Let's go to our migration folder and create a `CreateUser.swift` file. Inside that file, we will add the following code:

```swift
import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .id()
            .field("email", .string, .required)
            .field("name", .string, .required)
            .field("password_hash", .string, .required)
            .field("created_at", .datetime)
            .unique(on: "email")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users").delete()
    }
}
```

Nothing really new here that we haven't seen before when creating migrations. One important line to point out is:
```swift
.unique(on: "email")
```

This prevents two users from signing up with the same email in our database.

Next, let's make a migration for our `UserToken`. Let's create a `CreateUserToken.swift` file in our migrations folder. Add the following code to our `CreateUserToken.swift` file:

```swift
import Fluent

struct CreateUserToken: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("user_tokens")
            .id()
            .field("value", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "value")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("user_tokens").delete()
    }
}
```

The important thing to point out here is this line connects the token to the user:
```swift
.references("users", "id", onDelete: .cascade)
```

The `onDelete: .cascade` part means if a user is deleted, their tokens are deleted too. Nice!

Right now our `Link` model doesn't belong to any user. Let's head back to our `Link` model and fix this by adding a User to our `Link`.

Add the following code to our `Link` model and let's update our init:

```swift
@Parent(key: "user_id")
    var user: User
```

So now our `Link` model should look something like this:

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

  @Parent(key: "user_id")
  var user: User

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  init() {}

  init(
    id: UUID? = nil,
    title: String,
    url: String,
    note: String? = nil,
    isRead: Bool = false,
    userID: User.IDValue
  ) {
    self.id = id
    self.title = title
    self.url = url
    self.note = note
    self.isRead = isRead
    self.$user.id = userID
  }
}
```

Great! But now if we try to build, we will get errors because every one of our links needs a user. Calm down, no worries, this is good. It forces us to create links only when we know which user owns them. This is exactly what we want.

Because we changed the `Link` model, the database also needs to change.

In a real production project where migrations have already been shipped to our users, we usually add a new migration instead of editing old migrations. But because this tutorial is still early and you may be rebuilding the database locally, I’ll show the simpler way to fix this.

Let's go back to our `CreateLink.swift` and update it too:

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
    .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
    .field("created_at", .datetime)
    .create()
  }

  func revert(on database: any Database) async throws {
    try await database.schema("links").delete()
  }
}
```
The big thing to note here is:
```swift
  .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
```

Now each link is linked (no pun intended) to a user through their user ID.

Next, we need to register our newly created migrations to our app. Let's move over to our `configure.swift` file.

```swift
  app.migrations.add(CreateUser())
  app.migrations.add(CreateLink())
  app.migrations.add(CreateUserToken())
```

Something to note here is that the order does matter. We need to create users before links and user_tokens, because both of those tables reference users.

Your `configure.swift` should include something like this:

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

    app.migrations.add(CreateUser())
    app.migrations.add(CreateLink())
    app.migrations.add(CreateUserToken())

    // register routes
    try routes(app)
}
```

### Signing up and logging in

Now we need to make request types for signing up and logging in. Let's make some DTOs for `SignupRequest` and `LoginRequest`.

```swift
import Vapor

struct SignupRequest: Content {
    let email: String
    let name: String
    let password: String
}
```

```swift
 import Vapor

struct LoginRequest: Content {
    let email: String
    let password: String
}
```

Nothing crazy in the code above. We are just creating two types: one for signup and one for login. Next, let's make an auth response DTO to handle when we successfully sign in.

```swift
import Vapor

struct AuthResponse: Content {
    let token: String
    let user: UserResponse
}

struct UserResponse: Content {
    let id: UUID
    let email: String
    let name: String
}

extension User {
    func asPublicResponse() throws -> UserResponse {
        guard let id else {
            throw Abort(.internalServerError)
        }

        return UserResponse(
            id: id,
            email: email,
            name: name
        )
    }
}
```

This is important to note: we do not want to return the full `User` model from auth routes because it includes `passwordHash`. Instead, we return this safe public response type that doesn't give away our user's password hash. Your data model shouldn't always be your public API response type.

## Token generator! ##

Now let's create the login token we will use for our user.

What we need to do is generate a random bearer token and store it in the database. The client will send this token in the Authorization header on future requests.
The token needs to be long, random, and unpredictable because anyone with the token can act as that user. Below we will generate 32 cryptographically secure random bytes and Base64-encode them into a string that can safely travel in an HTTP header.

In our app, let's create a new folder called Utilities and add a file called `TokenGenerator.swift` to it. Then let's add the following code:

```swift
import Foundation

#if canImport(Security)
import Security
#endif

enum TokenGenerator {
    static func generate() -> String {
        [UInt8].random(count: 32).base64
    }
}

private extension Array where Element == UInt8 {
    static func random(count: Int) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)

#if canImport(Security)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "Unable to generate secure random bytes")
#elseif os(Linux)
        guard let file = FileHandle(forReadingAtPath: "/dev/urandom") else {
            preconditionFailure("Unable to open /dev/urandom")
        }
        let data = file.readData(ofLength: count)
        precondition(data.count == count, "Unable to generate secure random bytes")
        bytes = [UInt8](data)
#else
        preconditionFailure("Secure random byte generation is not supported on this platform")
#endif

        return bytes
    }

    var base64: String {
        Data(self).base64EncodedString()
    }
}

```

This version works on macOS and Linux. That matters because a Vapor app may run locally on your Mac while Postgres runs in Docker, and later the app itself might run in a Linux container.


## Creating a bearer authenticator

Next, we need to make a way for our app to take a bearer token and turn it into a logged-in user. Let's make an Auth folder and then add a `UserTokenAuthenticator.swift` file. Then let's add the following code:

```swift
import Vapor
import Fluent

struct UserTokenAuthenticator: AsyncBearerAuthenticator {
    typealias User = LinkVault.User

    func authenticate(
        bearer: BearerAuthorization,
        for request: Request
    ) async throws {
        // Look up the token in the database.
        guard let token = try await UserToken.query(on: request.db)
            .filter(\.$value == bearer.token)
            .with(\.$user)
            .first()
        else {
            // If the token does not exist, do not authenticate anyone.
            return
        }

        // If the token exists, load its user and log that user in
        // for the current request.
        request.auth.login(token.user)
    }
}
```

The authenticator does one job and processes the authentication like this:

Read `Authorization: Bearer <token>`
        ↓
Find matching UserToken in Postgres
        ↓
Load the related User
        ↓
Log the User into request.auth

That makes the user available later by calling this method:

```swift
try req.auth.require(User.self)
```

## Add signup, login, and /me routes ##

We are close to the end now. Let's add some auth routes to our routes file above our link routes.

```swift
import Vapor
import Fluent

func routes(_ app: Application) throws {
    app.get("health") { req async in
        ["status": "ok"]
    }

    let api = app.grouped("api")
    let auth = api.grouped("auth")

    // MARK: - Signup

    auth.post("signup") { req async throws -> AuthResponse in
        let data = try req.content.decode(SignupRequest.self)

        let normalizedEmail = data.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let existingUser = try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first()

        guard existingUser == nil else {
            throw Abort(.conflict, reason: "An account with this email already exists.")
        }

        let passwordHash = try await req.password.async.hash(data.password)

        let user = User(
            email: normalizedEmail,
            name: data.name,
            passwordHash: passwordHash
        )

        try await user.save(on: req.db)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        let tokenValue = TokenGenerator.generate()
        let token = UserToken(value: tokenValue, userID: userID)

        try await token.save(on: req.db)

        return AuthResponse(
            token: tokenValue,
            user: try user.asPublicResponse()
        )
    }

    // MARK: - Login

    auth.post("login") { req async throws -> AuthResponse in
        let data = try req.content.decode(LoginRequest.self)

        let normalizedEmail = data.email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let user = try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        let passwordIsValid = try await req.password.async.verify(
            data.password,
            created: user.passwordHash
        )

        guard passwordIsValid else {
            throw Abort(.unauthorized, reason: "Invalid email or password.")
        }

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        let tokenValue = TokenGenerator.generate()
        let token = UserToken(value: tokenValue, userID: userID)

        try await token.save(on: req.db)

        return AuthResponse(
            token: tokenValue,
            user: try user.asPublicResponse()
        )
    }

    // MARK: - Protected Routes

    let protected = api.grouped(UserTokenAuthenticator())

    protected.get("me") { req async throws -> UserResponse in
        let user = try req.auth.require(User.self)
        return try user.asPublicResponse()
    }

    // Link routes will go below this line.
}
```

Our routes.swift file should look something like this:

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

    let api = app.grouped("api")
    let auth = api.grouped("auth")

      // MARK: - Signup

      auth.post("signup") { req async throws -> AuthResponse in
          let data = try req.content.decode(SignupRequest.self)

          let normalizedEmail = data.email
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased()

          let existingUser = try await User.query(on: req.db)
              .filter(\.$email == normalizedEmail)
              .first()

          guard existingUser == nil else {
              throw Abort(.conflict, reason: "An account with this email already exists.")
          }

          let passwordHash = try await req.password.async.hash(data.password)

          let user = User(
              email: normalizedEmail,
              name: data.name,
              passwordHash: passwordHash
          )

          try await user.save(on: req.db)

          guard let userID = user.id else {
              throw Abort(.internalServerError)
          }

          let tokenValue = TokenGenerator.generate()
          let token = UserToken(value: tokenValue, userID: userID)

          try await token.save(on: req.db)

          return AuthResponse(
              token: tokenValue,
              user: try user.asPublicResponse()
          )
      }

      // MARK: - Login

      auth.post("login") { req async throws -> AuthResponse in
          let data = try req.content.decode(LoginRequest.self)

          let normalizedEmail = data.email
              .trimmingCharacters(in: .whitespacesAndNewlines)
              .lowercased()

          guard let user = try await User.query(on: req.db)
              .filter(\.$email == normalizedEmail)
              .first()
          else {
              throw Abort(.unauthorized, reason: "Invalid email or password.")
          }

          let passwordIsValid = try await req.password.async.verify(
              data.password,
              created: user.passwordHash
          )

          guard passwordIsValid else {
              throw Abort(.unauthorized, reason: "Invalid email or password.")
          }

          guard let userID = user.id else {
              throw Abort(.internalServerError)
          }

          let tokenValue = TokenGenerator.generate()
          let token = UserToken(value: tokenValue, userID: userID)

          try await token.save(on: req.db)

          return AuthResponse(
              token: tokenValue,
              user: try user.asPublicResponse()
          )
      }

      // MARK: - Protected Routes

      let protected = api.grouped(UserTokenAuthenticator())

      protected.get("me") { req async throws -> UserResponse in
          let user = try req.auth.require(User.self)
          return try user.asPublicResponse()
      }


    // Link Routes

    // This creates a route group with the shared path "/api/links".
    //
    // Instead of writing:
    // app.get("api", "links")
    // app.post("api", "links")
    // app.delete("api", "links", ":linkID")
    //
    // We can group the common path once and define routes inside it.
    let links = protected.grouped("links")

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
        let user = try req.auth.require(User.self)

        // Decode the incoming JSON body into our request DTO.
        //
        // CreateLinkRequest is not the database model.
        // It is a small type that describes the JSON we expect from the client.
        let data = try req.content.decode(CreateLinkRequest.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        // Create a new Fluent model from the decoded request data.
        //
        // We set isRead to false because a newly saved link should start unread.
        let link = Link(
            title: data.title,
            url: data.url,
            note: data.note,
            isRead: false,
            userID: userID
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
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        // Start a Fluent query for the Link model.
        try await Link.query(on: req.db)
            // Only return links that belong to the logged-in user.
            .filter(\.$user.$id == userID)
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
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        // Read the "linkID" route parameter from the URL.
        //
        // This corresponds to the ":linkID" part of the route.
        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid linkID")
        }

        // Ask Fluent to find a Link with this id that belongs to this user.
        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound)
        }

        // Return the found link as JSON.
        return link
    }

    // MARK: - Update a Link

    // This route updates an existing link.
    //
    // PATCH /api/links/:linkID
    //
    // The request body can contain any fields we want to update:
    //
    // {
    //   "title": "Updated title",
    //   "isRead": true
    // }
    links.patch(":linkID") { req async throws -> Link in
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

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
        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .first()
        else {
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
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError)
        }

        // Read the id from the URL.
        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid linkID")
        }

        // Find the link before deleting it.
        //
        // If it does not exist, return 404.
        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .first()
        else {
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

There are a few important things to mention with the code above.

Signup hashes the password when a user is first signing up. This line hashes the password:

```swift
let passwordHash = try await req.password.async.hash(data.password)
```

That is the only value we store in the database in regard to the user's password. We never save `data.password`.


Our login route will verify the password. This is the line that checks the submitted password against the stored hash:

```swift
let passwordIsValid = try await req.password.async.verify(
    data.password,
    created: user.passwordHash
)
```

If it returns false, we return:
```swift
throw Abort(.unauthorized)
```

Protected routes use the authenticator. This line creates a protected group:

```swift
let protected = api.grouped(UserTokenAuthenticator())
```

Any route added to protected will run through the bearer token authenticator first.

Then inside the route, we can require the logged-in user:

```swift
let user = try req.auth.require(User.self)
```

Nice! Now that we have our protected routes, let's make our link routes protected. Now our link routes should look like this:

```swift
  // Link Routes

  let links = protected.grouped("links")

  // MARK: - Create a Link

  links.post { req async throws -> Link in
    let user = try req.auth.require(User.self)
    let data = try req.content.decode(CreateLinkRequest.self)

    guard let userID = user.id else {
      throw Abort(.internalServerError)
    }

    let link = Link(
      title: data.title,
      url: data.url,
      note: data.note,
      isRead: false,
      userID: userID
    )

    try await link.save(on: req.db)
    return link
  }

  // MARK: - List Links

  links.get { req async throws -> [Link] in
    let user = try req.auth.require(User.self)

    guard let userID = user.id else {
      throw Abort(.internalServerError)
    }

    return try await Link.query(on: req.db)
      .filter(\.$user.$id == userID)
      .sort(\.$createdAt, .descending)
      .all()
  }

  // MARK: - Get One Link

  links.get(":linkID") { req async throws -> Link in
    let user = try req.auth.require(User.self)

    guard let userID = user.id else {
      throw Abort(.internalServerError)
    }

    guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
      throw Abort(.badRequest)
    }

    guard let link = try await Link.query(on: req.db)
      .filter(\.$id == linkID)
      .filter(\.$user.$id == userID)
      .first()
    else {
      throw Abort(.notFound)
    }

    return link
  }

  // MARK: - Update a Link

  links.patch(":linkID") { req async throws -> Link in
    let user = try req.auth.require(User.self)

    guard let userID = user.id else {
      throw Abort(.internalServerError)
    }

    guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
      throw Abort(.badRequest)
    }

    guard let link = try await Link.query(on: req.db)
      .filter(\.$id == linkID)
      .filter(\.$user.$id == userID)
      .first()
    else {
      throw Abort(.notFound)
    }

    let data = try req.content.decode(UpdateLinkRequest.self)

    if let title = data.title {
      link.title = title
    }

    if let url = data.url {
      link.url = url
    }

    if let note = data.note {
      link.note = note
    }

    if let isRead = data.isRead {
      link.isRead = isRead
    }

    try await link.save(on: req.db)
    return link
  }

  // MARK: - Delete a Link

  links.delete(":linkID") { req async throws -> HTTPStatus in
    let user = try req.auth.require(User.self)

    guard let userID = user.id else {
      throw Abort(.internalServerError)
    }

    guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
      throw Abort(.badRequest)
    }

    guard let link = try await Link.query(on: req.db)
      .filter(\.$id == linkID)
      .filter(\.$user.$id == userID)
      .first()
    else {
      throw Abort(.notFound)
    }

    try await link.delete(on: req.db)
    return .noContent
  }
```

This is the most important change in Part 3.

In Part 2, we used:

```swift
Link.find(id, on: req.db)
```

But now we use:

```swift
  guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
    throw Abort(.badRequest)
  }

  guard let link = try await Link.query(on: req.db)
    .filter(\.$id == linkID)
    .filter(\.$user.$id == userID)
    .first()
```

Why? Because we do not just want to find a link by ID. We want to find a link by ID and make sure it belongs to the current user. That prevents User A from accessing User B’s links.

And that's it! Now let's reset our database and test what we have done!

Because we changed the schema, we need to reset our local database.

The simplest way to do this is to run the following lines in our terminal:

```bash
swift run App migrate --revert
swift run App migrate
```

We also want to reset our Docker database volume. We need to run the following lines in our terminal as well:

```bash
docker compose down -v
docker compose up -d
swift run App migrate
```

Be careful with:

```bash
docker compose down -v
```

That deletes the local Postgres volume for this project.

This is okay right now for our database, but this is definitely not something you want to run casually on anything important.

Great! Let's run our app and test it out! We will start by running our project either from Xcode, or we can run this command in terminal:

```bash
swift run
```

Next, let's open up a new terminal session and create a user! Let's run the following command (feel free to add whatever name, password, or email):

```bash
curl -X POST http://localhost:8080/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "tom@example.com",
    "name": "Tom",
    "password": "password123"
  }'
```
If everything works and your app and Docker are running properly, you should see something like this print out in our terminal:

```json
   {
     "token":"pST5ro9twjAdVIsR5MZ3bMCat8TZjDM4z7ZP8D1vh\/U=",
     "user": {
       "name":"Tom",
       "email":"tom@example.com",
       "id":"BB2564B0-D89C-4789-BE93-4C997F003756"
     }
   }
```

Nice! We made a user. Let's now log in as said user:

```bash
curl http://localhost:8080/api/auth/login -X POST -H "Content-Type: application/json" -d '{"email": "tom@example.com", "password": "password123"}'
```

And your response should be:
```json
  {
    "user":{
      "name":"Tom",
      "email":"tom@example.com",
      "id":"BB2564B0-D89C-4789-BE93-4C997F003756"
    },"token":"e4zI2HPR6olzTsff4sm2PnwZCvomXfbF3mqoCNUat\/Y="
  }
```

Now we can see if our protected `/me` route works. Let's add the code below and make sure to replace `YOUR_TOKEN_HERE` with your token:

```bash
curl http://localhost:8080/api/me \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

```bash
curl http://localhost:8080/api/me \
  -H "Authorization: Bearer e4zI2HPR6olzTsff4sm2PnwZCvomXfbF3mqoCNUat/Y="
```
With our response:

```json
  {
    "id":"BB2564B0-D89C-4789-BE93-4C997F003756",
    "email":"tom@example.com",
    "name":"Tom"
  }
```

AMAZING!!! Now to bring it home, let's create a link.

```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "title": "Vapor Authentication Docs",
    "url": "https://docs.vapor.codes/security/authentication/",
    "note": "Read this before Part 4"
  }'
```

```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer e4zI2HPR6olzTsff4sm2PnwZCvomXfbF3mqoCNUat/Y=" \
  -d '{
    "title": "Vapor Authentication Docs",
    "url": "https://docs.vapor.codes/security/authentication/",
    "note": "Read this before Part 4"
  }'
```

With the response we should be getting:

```json
  {
    "url":"https:\/\/docs.vapor.codes\/security\/authentication\/",
    "user": {
      "id":"BB2564B0-D89C-4789-BE93-4C997F003756"
    },
    "createdAt":"2026-06-03T20:25:33Z",
    "id":"0E0C74C8-5D2F-451C-9520-8320CF23D405",
    "title":"Vapor Authentication Docs",
    "note":"Read this before Part 4",
    "isRead":false
  }
```

This is the coolest part in my opinion! Being able to play around with our routes now and see our data move around is awesome! Do yourself a favor and keep playing with all the routes we created!

Ok, we did a lot in this part, but we added the most important foundation for a real app backend, which is users and authentication.

Check list of what we did:

* created a User model
* hashed passwords instead of storing raw passwords in our database
* created database-backed bearer tokens
* built signup and login endpoints
* protected routes with an authenticator
* required the logged-in user with req.auth.require(User.self)
* connected links to users
* prevented one user from accessing another user’s data

This is a huge milestone in our app.

LinkVault is no longer just a CRUD API. It is now a multi-user backend! Pat yourself on the back!

In the next post we are going to clean up some things and make it more production-ready by adding:

* request validation
* better error responses
* password length checks
* email validation
* duplicate email handling polish
* safer response models
* a better folder structure with controllers

Right now, most of our logic is inside routes.swift. That was useful for learning, but production Vapor apps usually benefit from moving routes into controllers as the project grows. Happy coding and I'll see you in the next post 🤘🤘🤘
