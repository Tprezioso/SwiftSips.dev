---
title: Add Background Jobs and Metadata Fetching to My First Vapor Backend in 2026 pt. 6
date: 2026-08-29 00:05
tags: Swift, ServerSideSwift, Vapor
---
# Add Background Jobs and Metadata Fetching to My First Vapor Backend in 2026 pt. 6

When we last left our hero, we had added collections, tags, relationships, filtering, and pagination to our LinkVault Vapor project.
Our app has become way more than a basic CRUD API. Users can organize their saved links, filter them by collection or tag, and page through their data.
Now we are going to add some background work... but what does that mean? Let me give you an example that we are going to add to our app.
Right now, when a user saves a link, we store exactly what they send us:
- title
- URL
- note
- read/unread status
- optional collection
- optional tags

That works, but real saved-link apps usually do more. When someone saves a URL, the backend can fetch metadata about that page, such as:
- page title
- description
- Open Graph image
- site name
- favicon
- fetched timestamp

But fetching metadata means making an external HTTP request. That can be slow. The target website might be down. The response might take several seconds. The HTML might be large or malformed. We do not want the user’s `POST /api/links` request waiting on all of that.

Instead, we want something like this:
```
User saves a link
        ↓
API saves the link immediately
        ↓
API dispatches a background job
        ↓
API returns a response to the user
        ↓
Worker fetches metadata separately
        ↓
Worker updates the link later
```

This is the goal for this post. We are going to:
- add metadata fields to the Link model
- create a migration for those fields
- add Redis to our local development setup
- add Vapor Queues
- create a metadata-fetching job
- dispatch that job when a link is created
- run a queue worker
- verify that the worker updates the link in the background

This is another big step into making LinkVault feel more production-ready. But why do background jobs matter?
When building APIs, it is tempting to do everything directly inside the request handler.

For example, when a user creates a link, we could:
1. Receive request
2. Save the link
3. Fetch metadata from the website
4. Parse the HTML
5. Update our link
6. Return the response

That sounds simple, but it creates a bad user experience. If the website is slow, our API is slow. If the website is down, our create-link endpoint might fail. If the metadata parsing gets more complicated, our route handler becomes harder to maintain.

A better approach is:
1. Do the important request work immediately.
2. Move slower, non-critical work into the background.

For our app, the most important request work is saving the link. Fetching metadata is useful, but it does not need to block the response. That makes it a perfect use case for a queue.

We can start implementing this by updating our `Link` model with some new metadata fields.

Our `Link` model should now look something like this:

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

    @OptionalParent(key: "collection_id")
    var collection: Collection?

    @Siblings(
        through: LinkTag.self,
        from: \.$link,
        to: \.$tag
    )
    var tags: [Tag]

    // MARK: - New metadata fields
    @OptionalField(key: "metadata_title")
    var metadataTitle: String?

    @OptionalField(key: "metadata_description")
    var metadataDescription: String?

    @OptionalField(key: "metadata_image_url")
    var metadataImageURL: String?

    @OptionalField(key: "metadata_site_name")
    var metadataSiteName: String?

    @OptionalField(key: "metadata_status")
    var metadataStatus: String?

    @OptionalField(key: "metadata_fetched_at")
    var metadataFetchedAt: Date?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        title: String,
        url: String,
        note: String? = nil,
        isRead: Bool = false,
        userID: User.IDValue,
        collectionID: Collection.IDValue? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.note = note
        self.isRead = isRead
        self.$user.id = userID
        self.$collection.id = collectionID
    }
}
```

Besides the new metadata variables, the `metadataStatus` field will help us track where the link is in the metadata process.

For now, we will use simple string values:
```
fetching
fetched
failed
```

Later, we should improve this with a Swift enum, but strings are enough for right now.

Next we need to make a migration for our new metadata fields. Let's go to our `Migrations` folder and make an `AddMetadataToLink.swift` file with the following:
```swift
import Fluent

struct AddMetadataToLink: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("links")
            .field("metadata_title", .string)
            .field("metadata_description", .string)
            .field("metadata_image_url", .string)
            .field("metadata_site_name", .string)
            .field("metadata_status", .string)
            .field("metadata_fetched_at", .datetime)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("links")
            .deleteField("metadata_title")
            .deleteField("metadata_description")
            .deleteField("metadata_image_url")
            .deleteField("metadata_site_name")
            .deleteField("metadata_status")
            .deleteField("metadata_fetched_at")
            .update()
    }
}
```

This migration updates the existing links table instead of creating a new table. That makes sense because metadata belongs directly to a link.

Now we need to update our `configure.swift` file with our new migration. Our list of migrations should look something like this:

```swift
app.migrations.add(CreateUser())
app.migrations.add(CreateLink())
app.migrations.add(CreateUserToken())

app.migrations.add(CreateCollection())
app.migrations.add(CreateTag())
app.migrations.add(AddCollectionToLink())
app.migrations.add(CreateLinkTag())

app.migrations.add(AddMetadataToLink())
```

We also want to go to our terminal and run our migration:
```bash
swift run LinkVault migrate
```

At this point, the database has columns ready for metadata, but nothing is filling them in yet. That is what the background job will do.

Now let's update the public response so clients can see the fetched metadata. Let's go to `LinkResponse.swift` and add the following code:
```swift
import Vapor

struct LinkResponse: Content {
    let id: UUID
    let title: String
    let url: String
    let note: String?
    let isRead: Bool
    let collection: CollectionResponse?
    let tags: [TagResponse]
    let metadataTitle: String?
    let metadataDescription: String?
    let metadataImageURL: String?
    let metadataSiteName: String?
    let metadataStatus: String?
    let metadataFetchedAt: Date?
    let createdAt: Date?
}

extension Link {
    func asPublicResponse() throws -> LinkResponse {
        guard let id else {
            throw Abort(.internalServerError, reason: "Link is missing an id.")
        }

        return LinkResponse(
            id: id,
            title: title,
            url: url,
            note: note,
            isRead: isRead,
            collection: try $collection.value.flatMap { $0 }?.asPublicResponse(),
            tags: try $tags.value?.map { try $0.asPublicResponse() } ?? [],
            metadataTitle: metadataTitle,
            metadataDescription: metadataDescription,
            metadataImageURL: metadataImageURL,
            metadataSiteName: metadataSiteName,
            metadataStatus: metadataStatus,
            metadataFetchedAt: metadataFetchedAt,
            createdAt: createdAt
        )
    }
}
```

Now with this in place a link response can show both the user-provided information and the background-fetched metadata. So now a first response after creating a link might look like this:
```json
{
  "id": "LINK_ID",
  "title": "Vapor Queues",
  "url": "https://docs.vapor.codes/advanced/queues/",
  "note": "Read this later",
  "isRead": false,
  "tags": [],
  "createdAt": "2026-09-04T..."
}
```

Notice there are no metadata keys at all yet. They are still nil, and Swift's synthesized `Codable` conformance leaves nil optionals out of the JSON entirely instead of writing them as `null`. After our worker runs, those fields will appear. Next we need to make a queue for this background work and we will need a queue driver to handle the Vapor queues. For this tutorial we are going to use Redis.
If you are using the Docker setup from earlier in this series, we are going to update our `docker-compose.yml` file to include Redis. Alongside the services that are already in the `services:` block, add:
```yaml
  redis:
    image: redis:7
    container_name: linkvault-redis
    ports:
      - "6379:6379"
```

Then we will run:
```bash
docker compose up -d redis
```

This command will create and start `linkvault-redis`, and we can check that it is working by running the command `docker compose ps`.
You should see both Postgres and Redis running. Just a reminder: Postgres stores our app data, and Redis will temporarily hold background jobs until a worker processes them.

Next we need to add Redis to our `Package.swift` file. In our package dependencies let's add the following:

```swift
.package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0")
```

Next we need to add the queues driver to our app target:
```swift
.product(name: "QueuesRedisDriver", package: "queues-redis-driver")
```

Now that we have this in our package we need to resolve our packages. There are many ways to do this, but we can do it from the terminal like this:
```bash
swift package resolve
```

Now we need to configure our queues, so let's head over to our `configure.swift` file, import our new `QueuesRedisDriver`, and add the following code:
```swift
try app.queues.use(
    .redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379")
)
```

We are also going to register the job we are going to create:
```swift
app.queues.add(FetchLinkMetadataJob())
```

Our `configure.swift` should look something like this now:
```swift
import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import QueuesRedisDriver

public func configure(_ app: Application) async throws {

  app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
    hostname: Environment.get("DATABASE_HOST") ?? "localhost",
    port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
    username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
    password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
    database: Environment.get("DATABASE_NAME") ?? "vapor_database",
    tls: .prefer(try .init(configuration: .clientDefault)))
  ), as: .psql)

  try app.queues.use(
    .redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379")
  )

  app.migrations.add(CreateUser())
  app.migrations.add(CreateLink())
  app.migrations.add(CreateUserToken())

  app.migrations.add(CreateCollection())
  app.migrations.add(CreateTag())
  app.migrations.add(AddCollectionToLink())
  app.migrations.add(CreateLinkTag())

  app.migrations.add(AddMetadataToLink())

  app.queues.add(FetchLinkMetadataJob())

  try routes(app)
}
```

The important ideas here are that we:
- Configure the queue driver.
- Register the jobs the app knows how to process.
- Run a worker to actually process those jobs.

If the worker is not running, jobs can be dispatched, but nothing will process them yet. We now need to make a job payload.
A queue job needs a payload, and this payload is the data we send into the job. For our metadata job, we only need the link id. Let's create a new folder called `Jobs` and add a new Swift file called `FetchLinkMetadataPayload.swift`.
```swift
import Foundation

struct FetchLinkMetadataPayload: Codable {
    let linkID: UUID
}
```

Our `FetchLinkMetadataPayload` must conform to `Codable` because the queue driver needs to serialize it before storing it in Redis. We will keep this payload intentionally small.
Instead of sending the full link into the job, we send the id and let the worker reload the latest version from the database. That is usually a better pattern because the database remains the source of truth. Next we will create a parser for our metadata.
In our `Utilities` folder let's add an `HTMLMetadataParser.swift` file with the following code:
```swift
import Foundation

struct LinkMetadata {
    let title: String?
    let description: String?
    let imageURL: String?
    let siteName: String?
}

enum HTMLMetadataParser {
    static func parse(_ html: String) -> LinkMetadata {
        LinkMetadata(
            title: firstMatch(
                in: html,
                patterns: [
                    #"<meta\s+property=["']og:title["']\s+content=["']([^"']+)["']"#,
                    #"<title[^>]*>(.*?)</title>"#
                ]
            ),
            description: firstMatch(
                in: html,
                patterns: [
                    #"<meta\s+property=["']og:description["']\s+content=["']([^"']+)["']"#,
                    #"<meta\s+name=["']description["']\s+content=["']([^"']+)["']"#
                ]
            ),
            imageURL: firstMatch(
                in: html,
                patterns: [
                    #"<meta\s+property=["']og:image["']\s+content=["']([^"']+)["']"#
                ]
            ),
            siteName: firstMatch(
                in: html,
                patterns: [
                    #"<meta\s+property=["']og:site_name["']\s+content=["']([^"']+)["']"#
                ]
            )
        )
    }

    private static func firstMatch(
        in html: String,
        patterns: [String]
    ) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else {
                continue
            }

            let range = NSRange(html.startIndex..<html.endIndex, in: html)

            guard let match = regex.firstMatch(in: html, range: range),
                  let captureRange = Range(match.range(at: 1), in: html)
            else {
                continue
            }

            return String(html[captureRange])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
}
```

This parser is intentionally simple. HTML parsing can get much more complicated in real production systems, but for this tutorial, the goal is to teach the background job flow. Our parser looks for:
```
og:title
<title>
og:description
description
og:image
og:site_name
```

That gives us enough metadata to make saved links feel richer.

Now let's go on to making the job to get our metadata.
In our `Jobs` folder we need to create `FetchLinkMetadataJob.swift`.
```swift
import Vapor
import Fluent
import Queues

struct FetchLinkMetadataJob: AsyncJob {
    typealias Payload = FetchLinkMetadataPayload

    func dequeue(
        _ context: QueueContext,
        _ payload: FetchLinkMetadataPayload
    ) async throws {
        guard let link = try await Link.find(payload.linkID, on: context.application.db) else {
            context.logger.info("Link not found for metadata job: \(payload.linkID)")
            return
        }

        link.metadataStatus = "fetching"
        try await link.save(on: context.application.db)

        do {
            let response = try await context.application.client.get(URI(string: link.url))

            guard response.status == .ok else {
                link.metadataStatus = "failed"
                link.metadataFetchedAt = Date()
                try await link.save(on: context.application.db)
                return
            }

            guard let body = response.body,
                  let html = body.getString(
                    at: body.readerIndex,
                    length: body.readableBytes
                  )
            else {
                link.metadataStatus = "failed"
                link.metadataFetchedAt = Date()
                try await link.save(on: context.application.db)
                return
            }

            let metadata = HTMLMetadataParser.parse(html)

            link.metadataTitle = metadata.title
            link.metadataDescription = metadata.description
            link.metadataImageURL = metadata.imageURL
            link.metadataSiteName = metadata.siteName
            link.metadataStatus = "fetched"
            link.metadataFetchedAt = Date()

            try await link.save(on: context.application.db)
        } catch {
            link.metadataStatus = "failed"
            link.metadataFetchedAt = Date()
            try await link.save(on: context.application.db)

            context.logger.error("Metadata fetch failed for link \(payload.linkID): \(error)")

            throw error
        }
    }

    func error(
        _ context: QueueContext,
        _ error: Error,
        _ payload: FetchLinkMetadataPayload
    ) async throws {
        context.logger.error("Metadata job failed for link \(payload.linkID): \(error)")
    }
}
```

This job does a few important things. First, it reloads the link from the database:
```swift
guard let link = try await Link.find(payload.linkID, on: context.application.db) else {
    return
}
```

Then it marks the metadata status as fetching:
```swift
link.metadataStatus = "fetching"
try await link.save(on: context.application.db)
```

Then it makes an HTTP request to the saved URL:
```swift
let response = try await context.application.client.get(URI(string: link.url))
```

If the request succeeds, it parses the HTML and saves metadata back to the link. If anything fails, it marks the metadata status as failed. This gives us a useful state machine:
```
fetching
   ↓
fetched
```
or:
```
fetching
   ↓
failed
```

That is much better than having no idea what happened. Now we are going to need to update our `LinkController` to dispatch our metadata job.
In the create method, after saving the link and attaching tags, dispatch the metadata job.

Find this section:
```swift
try await link.save(on: req.db)
```

After the link is saved and after tags are attached, add:
```swift
try await req.queue.dispatch(
    FetchLinkMetadataJob.self,
    .init(linkID: try link.requireID()),
    maxRetryCount: 3
)
```

Our create function should look something like this:
```swift
func create(req: Request) async throws -> LinkResponse {
        try CreateLinkRequest.validate(content: req)

        let user = try req.auth.require(User.self)
        let data = try req.content.decode(CreateLinkRequest.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        if let collectionID = data.collectionID {
            let collectionExists = try await Collection.query(on: req.db)
                .filter(\.$id == collectionID)
                .filter(\.$user.$id == userID)
                .first() != nil

            guard collectionExists else {
                throw Abort(.badRequest, reason: "Collection does not exist.")
            }
        }

        let link = Link(
            title: data.title.trimmingCharacters(in: .whitespacesAndNewlines),
            url: data.url,
            note: data.note?.trimmingCharacters(in: .whitespacesAndNewlines),
            isRead: false,
            userID: userID,
            collectionID: data.collectionID
        )

        try await link.save(on: req.db)

        if let tagIDs = data.tagIDs {
            let tags = try await Tag.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$id ~~ tagIDs)
                .all()

            guard tags.count == Set(tagIDs).count else {
                throw Abort(.badRequest, reason: "One or more tags do not exist.")
            }

            try await link.$tags.attach(tags, on: req.db)
        }

        try await req.queue.dispatch(
          FetchLinkMetadataJob.self,
          .init(linkID: try link.requireID()),
          maxRetryCount: 3
        )

        let savedLink = try await Link.query(on: req.db)
            .filter(\.$id == link.requireID())
            .with(\.$collection)
            .with(\.$tags)
            .first()

        guard let savedLink else {
            throw Abort(.internalServerError, reason: "Saved link could not be reloaded.")
        }

        return try savedLink.asPublicResponse()
    }
```

Now, every time a user creates a link, the API saves it immediately and dispatches a background job. The user does not have to wait for metadata fetching to finish. That is the main architectural improvement in this post.

Great! Now let's test all that we have done.

We will want to open two terminal sessions. In the first one we will want to run the app by running:
```bash
swift run
```

Or by running the app from Xcode. Next we will want to run the queue worker:
```bash
swift run LinkVault queues
```

This worker process listens for queued jobs and processes them. If you create a link while the worker is running, you should see logs from the metadata job. If the worker is not running, the app can still dispatch jobs to Redis, but those jobs will wait until a worker starts. That separation is important.
In production, the web process and worker process are often separate processes:
```
web process     handles HTTP requests
worker process  handles background jobs
```

That lets our API stay responsive while workers handle slower work. So now that we have our app and queues running in our terminal let's test it out.
Let's start by logging in to get our token:
```bash
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" -d '{ "email": "tom@example.com", "password": "password123" }'
```

Next with the token we get back we are going to want to create a new link to save:
```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "title": "Vapor Queues",
    "url": "https://docs.vapor.codes/advanced/queues/",
    "note": "Background jobs let us move slow work out of the request."
  }'

#  We are returned
{
    "title":"Vapor Queues",
    "note":"Background jobs let us move slow work out of the request.",
    "tags":[],
    "id":"B2A9D57A-A1D3-4ED0-B222-AE249246DC1C",
    "createdAt":"2026-09-04T01:34:02Z",
    "isRead":false,
    "url":"https:\/\/docs.vapor.codes\/advanced\/queues\/"
}
```

In our Jobs terminal we should see our metadata job start and print out something like this:
```bash
[129/129] Applying LinkVault
Build of product 'LinkVault' complete! (7.36s)
[ INFO ] Starting jobs worker [queue: default]
[ INFO ] Dequeing and running job [attempt: 1, job-id: F9A599AC-6CBF-47B1-863E-C72681B98B0B, job-name: FetchLinkMetadataJob, queue: default, retries-left: 3]
```

Let's wait a few moments and then fetch our link to see if the metadata is now attached:
```bash
curl http://localhost:8080/api/links \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# With a response of:
[
    {
        "createdAt":"2026-09-04T01:34:02Z",
        "note":"Background jobs let us move slow work out of the request.",
        "metadataImageURL":"https:\/\/docs.vapor.codes\/assets\/og\/en-2x.png",
        "url":"https:\/\/docs.vapor.codes\/advanced\/queues\/",
        "metadataFetchedAt":"2026-09-04T01:34:05Z",
        "id":"B2A9D57A-A1D3-4ED0-B222-AE249246DC1C",
        "metadataTitle":"Queues",
        "metadataSiteName":"Vapor Docs",
        "title":"Vapor Queues",
        "isRead":false,
        "metadataStatus":"fetched",
        "tags":[],
        "metadataDescription":"Vapor Queues (vapor\/queues) is a pure Swift queuing system that allows you to offload task responsibility to a side worker."
    }
]
```

If the worker processed the job successfully, you should see some metadata fields filled in and the status should be:
```json
{
  "metadataStatus": "fetched"
}
```

If fetching failed, you may see:
```json
{
  "metadataStatus": "failed"
}
```

That is still useful because the API now knows the metadata job was attempted. This is worth testing some more. Stop the worker process, but keep the API running.
Now create another link (I will leave this up to you to fill in). The link should still save successfully, and the metadata fields will simply be missing from the response until a worker picks the job up. That is exactly what we want.
The API request should not fail just because the worker is offline. Now start the worker again:
```bash
swift run LinkVault queues
```

The worker should pick up waiting jobs from Redis.
This is the key mental model:
- The API dispatches work.
- Redis stores the work.
- The worker performs the work.

Once that clicks, queues become much easier to get your head around.

This version of implementing background jobs is intentionally simple.
We are not yet handling things like:
- advanced HTML parsing
- relative image URLs
- favicon fallback
- per-domain rate limits
- robots.txt
- metadata refresh scheduling
- duplicate job prevention
- custom retry policies per failure type
- a separate metadata table

Those are all possible future improvements, but for this tutorial we are going to keep it relatively simple.
Great, what's next? In the next part we will be writing tests! Wait, don't go!
This is an important part of writing any software, and although it might not be the most exciting, it is still important to learn how we can write tests for our requests. So until next time (maybe next month, who knows if I will have time with these kids 🤷🏻‍♂️) happy coding!
