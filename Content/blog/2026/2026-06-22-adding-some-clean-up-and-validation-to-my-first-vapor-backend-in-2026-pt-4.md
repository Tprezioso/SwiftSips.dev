---
title: Adding Some Clean Up and Validation to My First Vapor Backend in 2026 pt. 4
date: 2026-07-05 20:37
tags: Swift, ServerSideSwift, Vapor
---
# Adding Some Clean Up and Validation to My First Vapor Backend in 2026 pt. 4

In the last post we focused mostly on getting our backend up and running. We added users, password hashing, bearer tokens, protected routes, and user-owned data. At this point, our LinkVault app works. Our users can sign up, log in, create links, and only see their own data. But there is one issue you might have noticed. `routes.swift` is getting a little messy. This is bad for our code base but a great sign that we need to reorganize some code.
In this part, we are going to clean up our API and make it feel more like a production-ready Vapor project.
By the end of this post, we will:
- Add validation to request DTOs
- Add public response DTOs
- Make token generation safer
- Move auth logic into an AuthController
- Move link logic into a LinkController
- Shrink routes.swift
- Test that everything still works

Let's get started by first adding validations to our request DTOs. Right now the problem is our request DTOs tell Vapor how to decode incoming JSON but never validate if the decoded values are correct. 
For example, our signup request has an email, a name, and a password. But it does not yet describe what makes those values valid. That means a request like this could still reach our route logic:
```json
{
    "email": "not-an-email", 
    "name": "", 
    "password": "123" 
}
```

This is no bueno. Before we create users or save links, we should validate the request body and make sure the incoming data follows the rules that our API expects. 
The flow should look something like this:
```
Validate the request
        ↓
Decode the request
        ↓
Use the decoded data
```

Let’s start by updating our Sign up request DTO since this should be where we start.

```swift
import Vapor 

struct SignupRequest: Content, Validatable {
    let email: String
    let name: String
    let password: String

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email, required: true )
        validations.add("name", as: String.self, is: !.empty && .count(2...50), required: true )
        validations.add("password", as: String.self, is: .count(8...128), required: true )
    }
}
```

There are two important protocols here: `Content` and `Validatable`. `Content` we have seen before and this just tells Vapor how to decode the JSON body into this Swift type. `Validatable` is a new one that lets this type describe its own validation rules.
For signup, we are saying:
- email must be a valid email address
- name must not be empty and must be between 2 and 50 characters
- password must be between 8 and 128 characters
These are still simple rules, but they already make the API much safer than blindly accepting whatever the client sends. Next, let’s update our login request.

```swift
struct LoginRequest: Content, Validatable {
  let email: String
  let password: String

  static func validations(_ validations: inout Validations) {
    validations.add("email", as: String.self, is: .email, required: true)
    validations.add("password", as: String.self, is: !.empty, required: true)
  }
}
```

For login the rules are a little simpler. We need a valid email and a non-empty password. We do not need to enforce the full signup password rule here because the user may already have an account. The login route should verify the submitted password against the stored password hash.
Now let’s add validation to our link request DTOs.
```swift
import Vapor

struct CreateLinkRequest: Content, Validatable {
  let title: String
  let url: String
  let note: String?
  
  static func validations(_ validations: inout Validations) {
    validations.add("title", as: String.self, is: !.empty && .count(1...120), required: true)
    validations.add("url", as: String.self, is: .url, required: true)
    validations.add("note", as: String.self, is: .count(...500), required: false)
  }
}
```

I think we are starting to get the hang of this. In the above validations func we are requiring that: 
- title is required
- title cannot be empty
- title cannot be longer than 120 characters
- url is required
- url must be a URL
- note is optional
- note cannot be longer than 500 characters 

Next, let’s update the UpdateLinkRequest type for partial updates.
```swift
struct UpdateLinkRequest: Content, Validatable {
    let title: String?
    let url: String?
    let note: String?
    let isRead: Bool?

    static func validations(_ validations: inout Validations) {
        validations.add(
            "title",
            as: String.self,
            is: !.empty && .count(1...120),
            required: false
        )

        validations.add(
            "url",
            as: String.self,
            is: .url,
            required: false
        )

        validations.add(
            "note",
            as: String.self,
            is: .count(...500),
            required: false
        )

        validations.add(
            "isRead",
            as: Bool.self,
            required: false
        )
    }
}
```

The update request is different because every property is optional. That is because our update endpoint uses PATCH, which means the client can send only the fields it wants to change.
For example, this should be valid:
```json
{  
    "isRead": true
}
```

And this should also be valid:
```json
{
  "title": "Updated title"
}
```

The validation rules still apply if the fields are included, but the fields are not required.
This gives us a nice balance with create requests requiring the important fields, update requests allow partial changes, and both still validating the data they receive.
Now let’s add some public response DTOs. You will remember that in part 3 we were careful not to return the full `User` model from auth `routes` because the model contains `passwordHash`. That was the right call. Now we need to apply the same idea to links.

Right now, returning the Link model directly may not seem dangerous. But as the project grows, the model may gain internal fields that we do not want to expose.
For example, later we might add:
- userID
- metadataStatus
- deletedAt
- internalNotes

If our API returns database models directly, we may accidentally expose internal details to the client. A better pattern is:
```
Model = database representation
Response DTO = public API representation
```

So let’s create a public response type for links. Let’s head over to our DTOs folder and add a LinkResponse.swift file.
```swift
import Vapor

struct LinkResponse: Content {
  let id: UUID
  let title: String
  let url: String
  let note: String?
  let isRead: Bool
  let createdAt: Date?
}

extension Link {
  func asPublicResponse() throws -> LinkResponse {
    guard let id else { throw Abort(.internalServerError, reason: "Link is missing an id.") }

    return LinkResponse(id: id, title: title, url: url, note: note, isRead: isRead, createdAt: createdAt)
  }
}
```

This gives us one clear place to define what a link looks like when it leaves our API. The `Link` model can keep being focused on persistence, relationships, and database behavior. The `LinkResponse` type can be focused on what the client is allowed to see. This is one of those patterns that may feel like extra work early on, but it pays off quickly as the app grows. 

Next, let’s make our token generator a little bit safer. In Part 3 of this series, we created a helper for generating bearer tokens.
The idea was simple:
```
Generate secure random bytes
        ↓
Base64 encode them
        ↓
Store the token in the database
        ↓
Return the token to the client
```

That token is what the client sends on future requests:
```
Authorization: Bearer YOUR_TOKEN_HERE
```
Since anyone with the token can act as that user, we want the token to be random, hard to guess, and generated safely.
Let’s update the token generator so it throws an error if secure random generation fails. Let’s navigate to our Auth folder and then to our `TokenGenerator.swift` file.
```swift
import Foundation
import Vapor
#if canImport(Security)
import Security
#endif

enum TokenGenerator {
    static func generate() throws -> String {
       try [UInt8].secureRandom(count: 32).base64
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

  static func secureRandom(count: Int) throws -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: count)
    let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
    guard status == errSecSuccess else {
      throw Abort(
        .internalServerError,
        reason: "Failed to generate secure token."
      )
    }
    return bytes
  }

    var base64: String {
        Data(self).base64EncodedString()
    }
}
```

Above we are just switching out our random token generation to make a secure token generation. When you build now you will get some errors but all we need to do is go to our `routes.swift` and add a try in front of our token generator since now it can throw an error. 
That means any route that creates a token now needs to use:
```swift
let tokenValue = try TokenGenerator.generate()
```
instead of:
```swift
let tokenValue = TokenGenerator.generate()
```
This is a small change, but it makes the security-sensitive part of our API more explicit. If token generation fails, we should not silently continue. We should stop the request and return an internal server error.
Now that we have validation and safer token generation, let’s start cleaning up `routes.swift`. Right now, routes.swift knows way too much.
It knows how to sign up users, how to log in users, how to create tokens, and how to hash passwords.
That was fine while we were learning and getting things setup, but as the app grows, it is better to move related route logic into controllers.

A controller is just a type that groups related request handlers together. Let’s navigate to our Controllers folder and create `AuthController.swift`.

Then let’s add the following code to it:
```swift
import Vapor
import Fluent

struct AuthController: RouteCollection {
  func boot(routes: any RoutesBuilder) throws {
    let auth = routes.grouped("auth")

    auth.post("signup", use: signup)

    auth.post("login", use: login)
  }

  func signup(req: Request) async throws -> AuthResponse {
    try SignupRequest.validate(content: req)

    let data = try req.content.decode(SignupRequest.self)
    let normalizedEmail = data.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let existingUser = try await User.query(on: req.db).filter(\.$email == normalizedEmail).first()

    guard existingUser == nil else {
      throw Abort(.conflict, reason: "An account with this email already exists.")
    }

    let passwordHash = try await req.password.async.hash(data.password)

    let user = User(
      email: normalizedEmail,
      name: data.name.trimmingCharacters(
        in: .whitespacesAndNewlines
      ),
      passwordHash: passwordHash
    )

    try await user.save(
      on: req.db
    )

    guard let userID = user.id else {
      throw Abort(.internalServerError, reason: "User was saved without an id.")
    }

    let tokenValue = try TokenGenerator.generate()

    let token = UserToken(
      value: tokenValue,
      userID: userID
    )

    try await token.save(on: req.db
    )
    return AuthResponse(
      token: tokenValue,
      user: try user.asPublicResponse()
    )
  }

  func login(req: Request) async throws -> AuthResponse {
    try LoginRequest.validate(content: req)

    let data = try req.content.decode(LoginRequest.self)

    let normalizedEmail = data.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    guard let user = try await User.query(on: req.db).filter(\.$email == normalizedEmail).first() else {
      throw Abort(.unauthorized, reason: "Invalid email or password.")
    }

    let passwordIsValid = try await req.password.async.verify(data.password, created: user.passwordHash)

    guard passwordIsValid else {
      throw Abort(.unauthorized, reason: "Invalid email or password.")
    }

    guard let userID = user.id else {
      throw Abort(.internalServerError, reason: "User is missing an id.")
    }

    let tokenValue = try TokenGenerator.generate()

    let token = UserToken(
      value: tokenValue,
      userID: userID
    )

    try await token.save(on: req.db)

    return AuthResponse(
      token: tokenValue,
      user: try user.asPublicResponse()
    )
  }
}
```

There are two important things to point out here. First, the controller conforms to `RouteCollection`. That means this type knows how to register its own routes. Second, the controller has a boot method:
```swift
func boot(routes: any RoutesBuilder) throws
```

Inside boot, we define the auth route group:

```swift
let auth = routes.grouped("auth")
```

Then we register the routes:
```swift
auth.post("signup", use: signup)
auth.post("login", use: login)
```
This preserves the same auth behavior we previously had. Now, instead of putting signup and login directly in routes.swift, we can let AuthController own that part of the API. We will fix the `routes.swift` later but for now let’s make our new LinkController.
Our link routes currently contain the main CRUD behavior for the project. That makes them a perfect candidate for a controller. Let’s navigate to our Controllers folder and make a `LinkController.swift`. Let’s add the following code to our new LinkController.
```swift
import Vapor
import Fluent

struct LinkController: RouteCollection {
  func boot(routes: any RoutesBuilder) throws {
    routes.post(use: create)
    routes.get(use: list)
    routes.get(":linkID", use: get)
    routes.patch(":linkID", use: update)
    routes.delete(":linkID", use: delete)
  }
  
  func create(req: Request) async throws -> LinkResponse {
    try CreateLinkRequest.validate(content: req)
    let user = try req.auth.require(User.self)
    let data = try req.content.decode(CreateLinkRequest.self)
    guard let userID = user.id else { throw Abort(.internalServerError, reason: "Authenticated user is missing an id.") }
    let link = Link(title: data.title.trimmingCharacters(in: .whitespacesAndNewlines), url: data.url, note: data.note?.trimmingCharacters(in: .whitespacesAndNewlines), isRead: false, userID: userID )

    try await link.save(on: req.db)
    return try link.asPublicResponse()
  }

  func list(req: Request) async throws -> [LinkResponse] {
    let user = try req.auth.require(User.self)
    guard let userID = user.id else { throw Abort(.internalServerError, reason: "Authenticated user is missing an id.") }
    let links = try await Link.query(on: req.db).filter(\.$user.$id == userID).sort(\.$createdAt, .descending).all()
    return try links.map { try $0.asPublicResponse() }
  }

  func get(req: Request) async throws -> LinkResponse {
    let user = try req.auth.require(User.self)
    guard let userID = user.id else { throw Abort(.internalServerError, reason: "Authenticated user is missing an id.") }
    guard let linkID = req.parameters.get("linkID", as: UUID.self) else { throw Abort(.badRequest, reason: "Invalid link id.") }
    guard let link = try await Link.query(on: req.db).filter(\.$id == linkID).filter(\.$user.$id == userID).first() else { throw Abort(.notFound, reason: "Link not found.") }

    return try link.asPublicResponse()
  }
  func update(req: Request) async throws -> LinkResponse {
    try UpdateLinkRequest.validate(content: req)
    let user = try req.auth.require(User.self)
    guard let userID = user.id else { throw Abort(.internalServerError, reason: "Authenticated user is missing an id.") }
    guard let linkID = req.parameters.get("linkID", as: UUID.self) else { throw Abort(.badRequest, reason: "Invalid link id.") }
    guard let link = try await Link.query(on: req.db).filter(\.$id == linkID).filter(\.$user.$id == userID).first() else { throw Abort(.notFound, reason: "Link not found.") }

    let data = try req.content.decode(UpdateLinkRequest.self)

    if let title = data.title {
      link.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let url = data.url {
      link.url = url
    }

    if let note = data.note {
      link.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    if let isRead = data.isRead {
      link.isRead = isRead
    }

    try await link.save(on: req.db)
    return try link.asPublicResponse()
  }

  func delete(req: Request) async throws -> HTTPStatus {
    let user = try req.auth.require(User.self)
    guard let userID = user.id else { throw Abort(.internalServerError, reason: "Authenticated user is missing an id.") }
    guard let linkID = req.parameters.get("linkID", as: UUID.self) else { throw Abort(.badRequest, reason: "Invalid link id.") }
    guard let link = try await Link.query(on: req.db).filter(\.$id == linkID).filter(\.$user.$id == userID).first() else { throw Abort(.notFound, reason: "Link not found.") }
    try await link.delete(on: req.db)

    return .noContent
  }
}
```

This controller now owns the full link lifecycle:
```
- POST   /api/links
- GET    /api/links
- GET    /api/links/:linkID
- PATCH  /api/links/:linkID
- DELETE /api/links/:linkID
```
The routes are registered in boot:
```swift
func boot(routes: any RoutesBuilder) throws {
    routes.post(use: create)
    routes.get(use: list)
    routes.get(":linkID", use: get)
    routes.patch(":linkID", use: update)
    routes.delete(":linkID", use: delete)
}
```

Now the get, update, and delete routes all use the same important safety pattern:
```swift
.filter(\.$id == req.parameters.get("linkID"))
.filter(\.$user.$id == userID)
```
This means we do not just find a link by id. We find a link by id and make sure it belongs to the current user. That prevents one user from accessing another user’s data by guessing or copying a link id.
Now that auth and link logic live in controllers, routes.swift can become much smaller.
Replace `routes.swift` with:
```swift
import Vapor
import Fluent

func routes(_ app: Application) throws {
  app.get("health") { req async in
    ["status": "ok"]
  }

  let api = app.grouped("api")
  try api.register(collection: AuthController())

  let protected = api.grouped(UserTokenAuthenticator())

  protected.get("me") { req async throws -> UserResponse in
    let user = try req.auth.require(User.self)
    return try user.asPublicResponse()
  }

  try protected.grouped("links").register(collection: LinkController())

}
```

Now our routes file is cleaner and it helps explain the shape of our API without having the whole implementation living within it. We can read it almost like a table of contents:
```
GET /health
/api/auth/signup
/api/auth/login

Protected by bearer token:
/api/me
/api/links
```

The line:
```swift
try api.register(collection: AuthController())
```

registers the auth routes.
The line:
```swift
let protected = api.grouped(UserTokenAuthenticator())
```

creates a protected group that requires bearer-token authentication.
Then this line:
```swift
try protected
    .grouped("links")
    .register(collection: LinkController())
```

This registers all link routes under the protected /api/links path. That means the controller itself does not need to know that it is mounted under /api/links. It only knows how to handle link behavior once it has been given a route group. This separation keeps the project easier to reason about.

Ok, that was a pretty big refactor. Let’s run our app and test our API to make sure everything is still working. Let’s start by running the project in Xcode or going to the terminal and using `swift run` (Also make sure your docker db is up as well 😉). 
Next, let’s test our API by running this curl command:
```bash
curl -X POST http://localhost:8080/api/auth/signup -H "Content-Type: application/json" -d '{ "email": "not-an-email", "name": "", "password": "123" }'
```

This should give us an error message with something like:
```bash
{
    "error":true,"reason":"email is not a valid email address, name is empty and is less than minimum of 2 character(s), password is less than minimum of 8 character(s)"
}
```

This is exactly what we want. We do not want invalid users in the database.
Now log in with an existing user:
```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d '{ "email": "tom@example.com", "password": "password123" }'

# What the above command returns
{
    "token": "uyd\/3V4LXmtfySj+S5tCjs3EmjRdbKTL7gHFs4SzhTE=",
    "user": {
        "name":"Tom",
        "email":"tom@example.com",
        "id":"208E9BB0-1C13-4577-BE6E-07572BF96D53"
    }
}  
```

Let’s copy this token and then let’s try:

```bash
curl http://localhost:8080/api/links -H "Authorization: Bearer YOUR_TOKEN_HERE"

# What it should look like in our terminal
curl http://localhost:8080/api/links -H "Authorization: Bearer uyd/3V4LXmtfySj+S5tCjs3EmjRdbKTL7gHFs4SzhTE="
```

This should return our array of links. If it’s empty, then let’s test adding a link too.
```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "title": "Vapor Controllers",
    "url": "https://docs.vapor.codes/basics/controllers/",
    "note": "Controllers keep routes.swift clean."
  }'

# What it should look like in our terminal
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer uyd/3V4LXmtfySj+S5tCjs3EmjRdbKTL7gHFs4SzhTE=" \
  -d '{
    "title": "Vapor Controllers",
    "url": "https://docs.vapor.codes/basics/controllers/",
    "note": "Controllers keep routes.swift clean."
  }'

# This should return:
{
    "isRead":false,
    "createdAt":"2026-07-05T17:14:44Z",
    "id":"A650C0A3-E670-46A5-A73C-F15EE7E223B8",
    "title":"Vapor Controllers",
    "url":"https:\/\/docs.vapor.codes\/basics\/controllers\/",
    "note":"Controllers keep routes.swift clean."
}
```

Ok, last, let’s make sure we can’t enter a bad link into our database:
```bash
curl -X POST http://localhost:8080/api/links \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_TOKEN_HERE" \
    -d '{ 
     "title": "", 
     "url": "not-a-url" 
   }'

# This should look something like this 

curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer uyd/3V4LXmtfySj+S5tCjs3EmjRdbKTL7gHFs4SzhTE=" \
  -d '{
    "title": "",
    "url": "https://docs.vapor.codes/basics/controllers/"
  }'
  
# This returns:
{
    "error":true,    
    "reason":"title is empty and is less than minimum of 1 character(s)"
}
```

Nice! We made LinkVault cleaner and safer. We added some validation so bad data does not reach our route logic or database. We added a `LinkResponse` type so we don't return database models directly. We made token generation safer. We moved auth behavior into `AuthController`. We moved link behavior into `LinkController`. And finally, we reduced `routes.swift` to a smaller file that describes the API structure instead of holding all the implementation code. 

In the next post we’ll make LinkVault more useful by adding richer data modeling.
We’ll add:
- collections
- tags
- one-to-many relationships
- many-to-many relationships
- filtering links by collection
- filtering links by tag
- filtering links by read status

That will move the project from a basic saved-links API toward something that feels more like a real product. Happy coding and I'll see you in the next post 👨‍💻
