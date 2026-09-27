---
title: Writing Tests Before Shipping My First Vapor Backend in 2026 pt. 7
date: 2026-09-20 12:01
tags: Swift, ServerSideSwift, Vapor
---
# Writing Tests Before Shipping My First Vapor Backend in 2026 pt. 7

As we are coming to the end of this series, I did want to mention Vapor 5 is in beta and it's right around the corner from being released! Also it's been [10 years of Vapor!](https://blog.vapor.codes/posts/ten-years-of-vapor/) Do yourself a favor and go check out all the cool new things coming out in Vapor 5 and maybe pick up some cool [10 years of Vapor merch](https://store.vapor.codes/). I know I did (#NotSponsored 🤣). 

With the exciting news out of the way, let's jump into testing our Vapor backend before we deploy our project live! 
In the last part we added background jobs to LinkVault.
Our backend now handles quite a bit:
- users and authentication
- user-owned links
- request validation
- collections and tags
- filtering and pagination
- background metadata fetching

At this point, making changes without tests starts becoming risky. A small change to authentication could accidentally expose a protected route, or a change to a query could allow one user to access another user's links. So before we deploy LinkVault, we need to write some tests.

The good news is that we do not need to test every possible line of code in this post. Instead, we are going to focus on the most important behavior:
- Can a user sign up?
- Are protected routes actually protected?
- Can an authenticated user create a link?
- Can one user access another user's data?
- Does invalid input get rejected?

Let's start by adding VaporTesting to our project. Head over to our `Package.swift` file and add the following code to our test target if it isn't there already:
```swift
.testTarget(
            name: "LinkVaultTests",
            dependencies: [
                .target(name: "LinkVault"),
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "XCTQueues", package: "queues"),
            ],
            swiftSettings: swiftSettings
        )
```

Now let's take a look at a basic test example: 
```swift
import Testing
import VaporTesting

@Test
func example() async throws {
    try await withApp(configure: configure) { app in
        // Test the application.
    }
}
```

`withApp` creates the Vapor application that runs our normal configure(_:) function. That means our tests exercise the same routes and configuration that our real application uses.
Awesome, this is exactly what we want, but there is a looming issue we need to fix. We should never run our tests using a production or development database. Our tests will create users, links, collections, and other data. They also need to clean that data up. For our project, the easiest solution is an in-memory SQLite database. Our real app will still use Postgres, but our tests will use SQLite.

Let's set up this test database by first adding Fluent's SQLite driver to `Package.swift` if it is not already there:
```swift
.package(
    url: "https://github.com/vapor/fluent-sqlite-driver.git",
    from: "4.0.0"
)
```

Then add it to the App target:
```swift
.product(
    name: "FluentSQLiteDriver",
    package: "fluent-sqlite-driver"
)
```

We also need to make sure we import `FluentSQLiteDriver` in `configure.swift`:
```swift
import FluentSQLiteDriver
```

Now let's make it so the database configuration uses SQLite when in the testing environment:
```swift
if app.environment == .testing {
      app.databases.use(
          .sqlite(.memory),
          as: .sqlite
      )
  } else {
    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
      hostname: Environment.get("DATABASE_HOST") ?? "localhost",
      port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
      username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
      password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
      database: Environment.get("DATABASE_NAME") ?? "vapor_database",
      tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
  }
```

This gives every test environment a disposable database. When the test ends, the database disappears. Our migrations still define the database structure, so before each test we can create a fresh schema.

Now let's go into our `LinkVaultTests` folder, and then in our `LinkVaultTests.swift` file we will remove the code that might be in there and add the following:
```swift
@testable import LinkVault
import VaporTesting
import Testing
import Fluent
import XCTQueues

@Suite("LinkVault API", .serialized)
struct AppTests {

    private func withTestApp(
        _ test: (Application) async throws -> Void
    ) async throws {
        let app = try await Application.make(.testing)

        do {
            try await configure(app)
            app.queues.use(.test)

            // Build a fresh database from our migrations.
            try await app.autoMigrate()

            try await test(app)

            // Remove everything after the test.
            try await app.autoRevert()

            try await app.asyncShutdown()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()

            throw error
        }
    }
}
```

The first thing you will notice is the `@Suite` at the top of our struct:
```swift
@Suite("LinkVault API", .serialized)
```

This allows us to set up our database to run serially, which makes our cleanup predictable. The next important thing you will notice is our `func withTestApp`. This makes it so that every test will:
```markdown
Create Vapor app
        ↓
Run configure()
        ↓
Run migrations
        ↓
Run test
        ↓
Revert migrations
        ↓
Shut down app
```

This ensures that every test starts with a clean database. This is important since we will reduce the likelihood of a test failing due to another test having left behind data in our test database. 

Next we will test our request validation. Let's start with a simple example. Our signup endpoint should reject invalid input. Add the following code inside the `AppTests` struct:
```swift
  @Test("Signup rejects invalid input")
  func signupRejectsInvalidInput() async throws {
      try await withTestApp { app in
          try await app.testing().test(
              .POST,
              "api/auth/signup",
              beforeRequest: { req in
                  try req.content.encode(
                      SignupRequest(
                          email: "not-an-email",
                          name: "",
                          password: "123"
                      )
                  )
              },
              afterResponse: { res async in
                  #expect(res.status == .badRequest)
              }
          )
      }
  }
```

Here is a simple example of how to write a test for our signup route. Inside of our function we use our `withTestApp` closure to run our setup for the test. Next inside our closure we have our `app.testing().test()` call. 
In here is where we will write what we want to test. You can see in the code above we test that this route call is a `.POST` at the endpoint we want to test and then we have two trailing closures. The first is the `beforeRequest` closure. 
Here we set up what our request might need — in our case, we are encoding our `SignupRequest`. Then we have our `afterResponse` closure where we can test what the response should be. In our case we are just testing that the status of our request is returning an error of `.badRequest`.
This is our first useful safety net. If we accidentally remove email or password validation later, this test can catch it.
This is great! Next we are going to set up another little helper for the rest of our tests. Most of the tests we want to write require the user to be authenticated. So let's make a helper function to have our user repeat the signup request each time. Let's add the following code:

```swift
private func signup(
    app: Application,
    email: String
) async throws -> AuthResponse {
    var authResponse: AuthResponse?

    try await app.testing().test(
        .POST,
        "api/auth/signup",
        beforeRequest: { req in
            try req.content.encode(
                SignupRequest(
                    email: email,
                    name: "Test User",
                    password: "password123"
                )
            )
        },
        afterResponse: { res async throws in
            #expect(res.status == .ok)

            authResponse = try res.content.decode(AuthResponse.self)
        }
    )

    return try #require(authResponse)
}
```

All this function does is run our signup request and return the `AuthResponse`. This way we can run our tests with an authenticated user. In the next few tests we will get an authenticated user like this at the beginning of our tests:
```swift
let auth = try await signup(
    app: app,
    email: "tom@example.com"
)
```

And then we can use:
```swift
auth.token
```

for protected requests. This keeps the actual tests focused on the behavior they are testing instead of repeating setup code.
Let's write one more quick test that will fail when a user makes a request to get the links for a user but is unauthorized.
```swift
@Test("Links require authentication")
func linksRequireAuthentication() async throws {
    try await withTestApp { app in
        try await app.testing().test(
            .GET,
            "api/links"
        ) { res async in
            #expect(res.status == .unauthorized)
        }
    }
}
```

This test is tiny, but it protects an important promise: that `/api/links` is private and needs to be authenticated to get links.
If we accidentally move `LinkController` outside our authenticated route group later, this test should immediately tell us something is wrong. Now let's finally test that our auth helper works and test the happy path for creating a link. Let's add the following code:
```swift
  @Test("Authenticated user can create a link")
  func authenticatedUserCanCreateLink() async throws {
      try await withTestApp { app in
          let auth = try await signup(
              app: app,
              email: "tom@example.com"
          )

          try await app.testing().test(
              .POST,
              "api/links",
              beforeRequest: { req in
                  req.headers.bearerAuthorization = .init(
                      token: auth.token
                  )

                  try req.content.encode(
                      CreateLinkRequest(
                          title: "Vapor Docs",
                          url: "https://docs.vapor.codes",
                          note: "Testing Vapor",
                          collectionID: nil,
                          tagIDs: nil
                      )
                  )
              },
              afterResponse: { res async throws in
                  #expect(res.status == .ok)

                  let link = try res.content.decode(
                      LinkResponse.self
                  )

                  #expect(link.title == "Vapor Docs")
                  #expect(link.url == "https://docs.vapor.codes")
                  #expect(link.isRead == false)
              }
          )
      }
  }
```

There are two things worth noticing here.

First, we add the bearer token:
```swift
req.headers.bearerAuthorization = .init(
    token: auth.token
)
```

That makes the test request behave like an authenticated client. Second, we decode the real API response:
```swift
let link = try res.content.decode(
    LinkResponse.self
)
```

Then we verify the result using Swift Testing's #expect macro. We are testing the whole path with this test:
```markdown
HTTP request
     ↓
Authentication
     ↓
Validation
     ↓
Controller
     ↓
Fluent
     ↓
Database
     ↓
Response DTO
```

Next let's test that users can't access other users' stored links. Authentication alone does not guarantee data isolation. We also need to prove that one authenticated user cannot access another user's links. We are going to test this by creating two users and seeing if User B can get access to the links from User A:
```swift
@Test("Users cannot access another user's links")
func usersCannotAccessOtherUsersLinks() async throws {
    try await withTestApp { app in
        let userA = try await signup(
            app: app,
            email: "user-a@example.com"
        )

        var linkID: UUID?

        try await app.testing().test(
            .POST,
            "api/links",
            beforeRequest: { req in
                req.headers.bearerAuthorization = .init(
                    token: userA.token
                )

                try req.content.encode(
                    CreateLinkRequest(
                        title: "Private Link",
                        url: "https://example.com",
                        note: nil,
                        collectionID: nil,
                        tagIDs: nil
                    )
                )
            },
            afterResponse: { res async throws in
                let link = try res.content.decode(
                    LinkResponse.self
                )

                linkID = link.id
            }
        )

        let userB = try await signup(
            app: app,
            email: "user-b@example.com"
        )

        let id = try #require(linkID)

        try await app.testing().test(
            .GET,
            "api/links/\(id)",
            beforeRequest: { req in
                req.headers.bearerAuthorization = .init(
                    token: userB.token
                )
            },
            afterResponse: { res async in
                #expect(res.status == .notFound)
            }
        )
    }
}
```

Remember the ownership query from our controller:
```swift
.filter(\.$id == req.parameters.get("linkID"))
.filter(\.$user.$id == userID)
```

This test proves that the second filter is doing its job. User B is authenticated. But authentication does not mean User B gets access to every link. If you haven't been running these tests as we were going along, let's run them now. If you are using Xcode, you can hit `Command + U`. This will run our test suite. If you're not using Xcode, we can run the tests by running `swift test` in our terminal.

You should see Swift Package Manager build the project and run the test suite.
At this point, we have tests protecting four critical behaviors:
```markdown
✓ Invalid signup data is rejected

✓ Protected routes require authentication

✓ Authenticated users can create links

✓ Users cannot access another user's links
```


That is not every possible test LinkVault could have. And that is intentional. The goal of this post is not to create hundreds of tests. The goal is to establish a testing pattern that we can continue using as the backend evolves.

From here, we could easily add tests for:
```markdown
duplicate emails
login failures
collections
tags
filtering
pagination
updates
deletes
queue dispatching
metadata jobs
```

But they all follow the same basic pattern we just learned. This was intentionally a shorter post. We added a testing environment with its own disposable database. We learned how to use VaporTesting with Swift Testing. We created a reusable application setup helper. 
And most importantly, we tested the behaviors that would hurt the most if they broke:
- input validation
- authentication
- authenticated writes
- user data isolation

There are many more tests we could write, but we now have the foundation needed to add them. The main lesson is:
- Do not only test that the happy path works.
- Test the boundaries your backend promises to protect.

For our LinkVault app, user ownership is one of those boundaries. So what's next?
Right now our app has:
- Postgres persistence
- authentication
- validation
- controllers
- user ownership
- collections and tags
- filtering and pagination
- background jobs
- tests

There is really only one major step left: running it outside of our Mac!

In Part 8, we'll finish the series by preparing LinkVault for production.

We'll be looking at:
- Docker
- environment variables and secrets
- production Postgres
- production Redis
- running the web server and queue worker
- logging
- health checks
- security and CORS considerations
- deployment

And we will go over a final production-readiness checklist. That will take the project from a local Vapor backend to something we can actually deploy! This is super exciting! Happy coding! 👨‍💻
