---
title: Add Collections, Tags, Filtering, and Pagination to My First Vapor Backend in 2026 pt. 5
date: 2026-07-27 20:57
tags: Swift, ServerSideSwift, Vapor
---
# Add Collections, Tags, Filtering, and Pagination to My First Vapor Backend in 2026 pt. 5

In the last post we added some validation to our request, created safer response DTOs, moved route logic into controllers, and made our routes.swift much smaller. That was an important step to making the project easier to maintain. Right now, LinkVault can save links for a user, but every link lives in one flat list. That works for a small demo, but real saved-links apps need more structure.

In this part, we are going to add:
- collections for our links
- tags for our links
- one-to-many relationships
- many-to-many relationships
- filtering links by collection
- filtering links by tag
- filtering links by read status
- simple pagination for long lists of our collections

So how is this going to work? Each link can optionally belong to one collection. That gives us this relationship:
```
User has many Collections
A Collection has many Links
A Link optionally belongs to one Collection
```

The second concept we need to implement is a tag. A tag is more flexible than a collection. A link might have multiple tags:
```
swift
backend
vapor
postgres
tutorial
```

And each tag can belong to many links. That gives us this relationship:
```
A Link can have many Tags
A Tag has many Links
```

This is a many-to-many relationship, so we will use a pivot model to connect links and tags.
A quick little definition: 
A pivot model in Vapor's Fluent ORM is an intermediate database model used to bridge a many-to-many (sibling) relationship between two other models by storing both of their foreign keys

Great, let’s start by creating our `Collection` model. Let’s navigate over to our Models folder and create a `Collection.swift` file and add the following code:

```swift
import Vapor
import Fluent

final class Collection: Model, Content, @unchecked Sendable {
    static let schema = "collections"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "user_id")
    var user: User

    @Children(for: \.$collection)
    var links: [Link]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        name: String,
        userID: User.IDValue
    ) {
        self.id = id
        self.name = name
        self.$user.id = userID
    }
}
```

There are two relationship properties here.
First:
```swift
@Parent(key: "user_id")
var user: User
```

This User in our collection model means each collection belongs to only one user.
Second:
```swift
@Children(for: \.$collection)
var links: [Link]

```

This means a collection can have many links.
The `@Children` property does not store a value directly on the collection table. Instead, it points to the `@OptionalParent` or `@Parent` relationship on the child model. In our case, links will have a collection relationship. If you try to build you should see an error. This is because now we need to update our `Link` model. A link should still belong to a user, but it can also optionally belong to a collection.

Let’s update `Link.swift` with the following code:
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

  @Timestamp(key: "created_at", on: .create)
  var createdAt: Date?

  init() {}

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

There are two new relationships here. This one makes collection optional:
```swift
@OptionalParent(key: "collection_id")
var collection: Collection?
```

That means a link may belong to a collection, but it does not have to.
This next one sets up the many-to-many relationship with tags:
```swift
@Siblings(
    through: LinkTag.self,
    from: \.$link,
    to: \.$tag
)
var tags: [Tag]

```

This tells Fluent that links and tags are connected through a pivot model named LinkTag.
We have not created Tag or LinkTag yet, so the project will not compile until we add those next.
First let’s add `Tag.swift` to our Models folder. Next let’s add the following code to our new Tag model:
```swift
import Vapor
import Fluent

final class Tag: Model, Content, @unchecked Sendable {
    static let schema = "tags"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "user_id")
    var user: User

    @Siblings(
        through: LinkTag.self,
        from: \.$tag,
        to: \.$link
    )
    var links: [Link]

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() { }

    init(
        id: UUID? = nil,
        name: String,
        userID: User.IDValue
    ) {
        self.id = id
        self.name = name
        self.$user.id = userID
    }
}
```

A tag belongs to a user because each user should have their own tag namespace. That means my swift tag is different from another user’s swift tag.
The relationship between tags and links is many-to-many:
- A link can have many tags.
- A tag can belong to many links.

That is why Tag also has a @Siblings relationship.
Next let’s create our `LinkTag.swift` in our Models folder and add the following:
```swift
import Vapor
import Fluent

final class LinkTag: Model, @unchecked Sendable {
    static let schema = "link_tags"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "link_id")
    var link: Link

    @Parent(key: "tag_id")
    var tag: Tag

    init() { }

    init(
        id: UUID? = nil,
        linkID: Link.IDValue,
        tagID: Tag.IDValue
    ) {
        self.id = id
        self.$link.id = linkID
        self.$tag.id = tagID
    }
}
```

This table exists only to connect links and tags. If a link has three tags, there will be three rows in `LinkTag`. That is the standard shape of a many-to-many relationship.
Now we need database tables for collections, tags, and the link-tag pivot. Because we are adding new tables and changing the existing links table, we need migrations.
Let’s head over to the Migrations folder and  start by making a `CreateCollection.swift` file:
```swift
import Fluent

struct CreateCollection: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("collections")
            .id()
            .field("name", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "name", "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("collections").delete()
    }
}
```

The unique constraint is important:
```swift
.unique(on: "name", "user_id")
```

This means a single user cannot create two collections with the same name, but two different users can both have a collection named the same thing. Next let’s make `CreateTag.swift`:
```swift
import Fluent

struct CreateTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("tags")
            .id()
            .field("name", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("created_at", .datetime)
            .unique(on: "name", "user_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("tags").delete()
    }
}
```

Tags use the same kind of uniqueness rule:
- one user cannot duplicate tag names
- different users can use the same tag names

Next we will add an `AddCollectionToLink.swift` file with the following code:
```swift
import Fluent

struct AddCollectionToLink: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("links")
            .field("collection_id", .uuid, .references("collections", "id", onDelete: .setNull))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("links")
            .deleteField("collection_id")
            .update()
    }
}
```

This migration updates the existing links table.
Notice that we use:
```swift
onDelete: .setNull
```

That means if a collection is deleted, the links are not deleted. Instead, their `collection_id` becomes NULL. That makes sense for this app. Deleting a folder should not necessarily delete every saved link inside it.
Finally, create a `CreateLinkTag.swift` file:
```swift
import Fluent

struct CreateLinkTag: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("link_tags")
            .id()
            .field("link_id", .uuid, .required, .references("links", "id", onDelete: .cascade))
            .field("tag_id", .uuid, .required, .references("tags", "id", onDelete: .cascade))
            .unique(on: "link_id", "tag_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("link_tags").delete()
    }
}
```

The unique constraint prevents the same tag from being attached to the same link more than once. Now that we have all these new migrations we need to register them in our `configure.swift` file:
```swift
app.migrations.add(CreateUser())
app.migrations.add(CreateUserToken())
app.migrations.add(CreateLink())
// our new migrations
app.migrations.add(CreateCollection())
app.migrations.add(CreateTag())
app.migrations.add(AddCollectionToLink())
app.migrations.add(CreateLinkTag())
```

Remember, order DOES matter!!!
We need:
- users before `collections` and `tags`
- links before `link_tags`
- collections before `collection_id` can reference collections
- `tags` before `link_tags`

If your local database already has the Part 3 migrations applied, you can run:
```bash
swift run LinkVault migrate
```

If you are rebuilding the tutorial database from scratch, make sure the migrations are registered in a valid order before running them. 
Now that the models are created, let’s add DTOs for creating and returning collections, tags, and links. Let’s start with the collections. In our DTOs folder let’s add a `CreateCollectionRequest.swift` and add the following code:
```swift
import Vapor

struct CreateCollectionRequest: Content, Validatable {
    let name: String

    static func validations(_ validations: inout Validations) {
        validations.add(
            "name",
            as: String.self,
            is: !.empty && .count(1...60),
            required: true
        )
    }
}
```

And let’s add a `CollectionResponse.swift` file:
```swift
import Vapor

struct CollectionResponse: Content {
    let id: UUID
    let name: String
    let createdAt: Date?
}

extension Collection {
    func asPublicResponse() throws -> CollectionResponse {
        guard let id else {
            throw Abort(.internalServerError, reason: "Collection is missing an id.")
        }

        return CollectionResponse(
            id: id,
            name: name,
            createdAt: createdAt
        )
    }
}
```

Next let’s do the same with tags and create `CreateTagRequest.swift`:
```swift
import Vapor

struct CreateTagRequest: Content, Validatable {
    let name: String

    static func validations(_ validations: inout Validations) {
        validations.add(
            "name",
            as: String.self,
            is: !.empty && .count(1...40),
            required: true
        )
    }
}
```

and `TagResponse.swift`:
```swift
import Vapor

struct TagResponse: Content {
    let id: UUID
    let name: String
    let createdAt: Date?
}

extension Tag {
    func asPublicResponse() throws -> TagResponse {
        guard let id else {
            throw Abort(.internalServerError, reason: "Tag is missing an id.")
        }

        return TagResponse(
            id: id,
            name: name,
            createdAt: createdAt
        )
    }
}
```

Collections and tags are both user-owned resources, so our controllers will need to use the same ownership pattern we used for links.
Now that our links can belong to a collection and have tags associated with them, we need to update our link DTOs. First let’s start with our `CreateLinkRequest.swift` file:
```swift
import Vapor

struct CreateLinkRequest: Content, Validatable {
    let title: String
    let url: String
    let note: String?
    let collectionID: UUID?
    let tagIDs: [UUID]?

    static func validations(_ validations: inout Validations) {
        validations.add(
            "title",
            as: String.self,
            is: !.empty && .count(1...120),
            required: true
        )

        validations.add(
            "url",
            as: String.self,
            is: .url,
            required: true
        )

        validations.add(
            "note",
            as: String.self,
            is: .count(...500),
            required: false
        )
    }
}
```

Next we need to update `UpdateLinkRequest.swift`:
```swift
import Vapor

struct UpdateLinkRequest: Content, Validatable {
    let title: String?
    let url: String?
    let note: String?
    let isRead: Bool?
    let collectionID: UUID?
    let tagIDs: [UUID]?

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

Now let’s update `LinkResponse.swift`:
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
            collection: try $collection.value?.asPublicResponse(),
            tags: try $tags.value?.map { try $0.asPublicResponse() } ?? [],
            createdAt: createdAt
        )
    }
}
```

There is one important detail here:
```swift
$collection.value
$tags.value
```

Those values are only available if the relationships were loaded in the query.
So when we return links later, we will need to use eager loading with:
```swift
.with(\.$collection)
.with(\.$tags)
```

That tells Fluent to load the related collection and tags along with the link. Now that we have our DTOs set, we need to make a `CollectionController`:
```swift
import Vapor
import Fluent

struct CollectionController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post(use: create)
        routes.get(use: list)
        routes.delete(":collectionID", use: delete)
    }

    func create(req: Request) async throws -> CollectionResponse {
        try CreateCollectionRequest.validate(content: req)

        let user = try req.auth.require(User.self)
        let data = try req.content.decode(CreateCollectionRequest.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        let normalizedName = data.name
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let existingCollection = try await Collection.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$name == normalizedName)
            .first()

        guard existingCollection == nil else {
            throw Abort(.conflict, reason: "A collection with this name already exists.")
        }

        let collection = Collection(
            name: normalizedName,
            userID: userID
        )

        try await collection.save(on: req.db)

        return try collection.asPublicResponse()
    }

    func list(req: Request) async throws -> [CollectionResponse] {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        let collections = try await Collection.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .descending)
            .all()

        return try collections.map { try $0.asPublicResponse() }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        guard let collectionID = req.parameters.get("collectionID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid collection id.")
        }

        guard let collection = try await Collection.query(on: req.db)
            .filter(\.$id == collectionID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Collection not found.")
        }

        try await collection.delete(on: req.db)

        return .noContent
    }
}
```

The CollectionController follows the same pattern as LinkController. Every query is scoped to the authenticated user so that users can only list, create, and delete their own collections. Next let’s create a `TagController.swift` file:

```swift
import Vapor
import Fluent

struct TagController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        routes.post(use: create)
        routes.get(use: list)
        routes.delete(":tagID", use: delete)
    }

    func create(req: Request) async throws -> TagResponse {
        try CreateTagRequest.validate(content: req)

        let user = try req.auth.require(User.self)
        let data = try req.content.decode(CreateTagRequest.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        let normalizedName = data.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let existingTag = try await Tag.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$name == normalizedName)
            .first()

        guard existingTag == nil else {
            throw Abort(.conflict, reason: "A tag with this name already exists.")
        }

        let tag = Tag(
            name: normalizedName,
            userID: userID
        )

        try await tag.save(on: req.db)

        return try tag.asPublicResponse()
    }

    func list(req: Request) async throws -> [TagResponse] {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        let tags = try await Tag.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$name, .ascending)
            .all()

        return try tags.map { try $0.asPublicResponse() }
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        guard let tagID = req.parameters.get("tagID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid tag id.")
        }

        guard let tag = try await Tag.query(on: req.db)
            .filter(\.$id == tagID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Tag not found.")
        }

        try await tag.delete(on: req.db)

        return .noContent
    }
}
```

Again, every route is scoped to the authenticated user. This is especially important for tags because tag names are not globally unique. Two users can both have a swift tag, but they should not see or modify each other’s tags. The next thing we need to tackle is updating the create, list, get, and update methods in `LinkController`.

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

    func list(req: Request) async throws -> [LinkResponse] {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        let isRead = try? req.query.get(Bool.self, at: "isRead")
        let collectionID = try? req.query.get(UUID.self, at: "collectionID")
        let tagID = try? req.query.get(UUID.self, at: "tagID")
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = min((try? req.query.get(Int.self, at: "perPage")) ?? 20, 50)

        var query = Link.query(on: req.db)
            .filter(\.$user.$id == userID)

        if let isRead {
            query = query.filter(\.$isRead == isRead)
        }

        if let collectionID {
            query = query.filter(\.$collection.$id == collectionID)
        }

        if let tagID {
            query = query
                .join(LinkTag.self, on: \Link.$id == \LinkTag.$link.$id)
                .filter(LinkTag.self, \.$tag.$id == tagID)
        }

        let links = try await query
            .with(\.$collection)
            .with(\.$tags)
            .sort(\.$createdAt, .descending)
            .range(((page - 1) * perPage)..<(page * perPage))
            .all()

        return try links.map { try $0.asPublicResponse() }
    }

    func get(req: Request) async throws -> LinkResponse {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid link id.")
        }

        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .with(\.$collection)
            .with(\.$tags)
            .first()
        else {
            throw Abort(.notFound, reason: "Link not found.")
        }

        return try link.asPublicResponse()
    }

    func update(req: Request) async throws -> LinkResponse {
        try UpdateLinkRequest.validate(content: req)

        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid link id.")
        }

        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Link not found.")
        }

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

        if let collectionID = data.collectionID {
            let collectionExists = try await Collection.query(on: req.db)
                .filter(\.$id == collectionID)
                .filter(\.$user.$id == userID)
                .first() != nil

            guard collectionExists else {
                throw Abort(.badRequest, reason: "Collection does not exist.")
            }

            link.$collection.id = collectionID
        }

        try await link.save(on: req.db)

        if let tagIDs = data.tagIDs {
            let tags = try await Tag.query(on: req.db)
                .filter(\.$user.$id == userID)
                .filter(\.$id ~~ tagIDs)
                .all()

            guard tags.count == Set(tagIDs).count else {
                throw Abort(.badRequest, reason: "One or more tags do not exist.")
            }

            try await link.$tags.detachAll(on: req.db)
            try await link.$tags.attach(tags, on: req.db)
        }

        guard let updatedLink = try await Link.query(on: req.db)
            .filter(\.$id == link.requireID())
            .with(\.$collection)
            .with(\.$tags)
            .first()
        else {
            throw Abort(.internalServerError, reason: "Updated link could not be reloaded.")
        }

        return try updatedLink.asPublicResponse()
    }

    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let userID = user.id else {
            throw Abort(.internalServerError, reason: "Authenticated user is missing an id.")
        }

        guard let linkID = req.parameters.get("linkID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid link id.")
        }

        guard let link = try await Link.query(on: req.db)
            .filter(\.$id == linkID)
            .filter(\.$user.$id == userID)
            .first()
        else {
            throw Abort(.notFound, reason: "Link not found.")
        }

        try await link.delete(on: req.db)

        return .noContent
    }
}
```

Ok, there is a lot happening here, so let’s break down the important pieces. When we are creating a link, we first check that the collection belongs to the current user:

```swift
if let collectionID = data.collectionID {
    let collectionExists = try await Collection.query(on: req.db)
        .filter(\.$id == collectionID)
        .filter(\.$user.$id == userID)
        .first() != nil

    guard collectionExists else {
        throw Abort(.badRequest, reason: "Collection does not exist.")
    }
}
```

This prevents a user from attaching a link to someone else’s collection. Then, if the request includes tags, we load only tags that belong to the current user:
```swift
let tags = try await Tag.query(on: req.db)
    .filter(\.$user.$id == userID)
    .filter(\.$id ~~ tagIDs)
    .all()
```

One thing to note about the code above: the `~~` operator comes from Fluent. `~~` means that a value is contained in a collection.
The count check makes sure every submitted tag id was valid:
```swift
guard tags.count == Set(tagIDs).count else {
    throw Abort(.badRequest, reason: "One or more tags do not exist.")
}
```

Then we attach the tags:
```swift
try await link.$tags.attach(tags, on: req.db)
```

We also support query parameters on listing links:
```bash
GET /api/links?isRead=false
GET /api/links?collectionID=...
GET /api/links?tagID=...
GET /api/links?page=1&perPage=20
```

This makes the API much more useful without adding completely new features. Now let’s update our `routes.swift` file:

```swift
import Vapor

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

    try protected
        .grouped("collections")
        .register(collection: CollectionController())

    try protected
        .grouped("tags")
        .register(collection: TagController())

    try protected
        .grouped("links")
        .register(collection: LinkController())
}
```

Now our API has these protected route groups:
```bash
GET    /api/me

POST   /api/collections
GET    /api/collections
DELETE /api/collections/:collectionID

POST   /api/tags
GET    /api/tags
DELETE /api/tags/:tagID

POST   /api/links
GET    /api/links
GET    /api/links/:linkID
PATCH  /api/links/:linkID
DELETE /api/links/:linkID
```

That is a much richer backend than we had at the end of Part 4. Now all we need to do is run our new migrations:
```bash
swift run LinkVault migrate
```

If you are still working locally and run into migration issues because you changed earlier migrations while following the tutorial, you can reset the local Docker database:

```bash
docker compose down -v
docker compose up -d
# or
docker compose build
docker compose up app
docker compose up db
```

Do this if you are having issues with your local Docker database. The -v flag deletes the Docker volume, which means it deletes the local Postgres data for this project. That is fine while learning, but it is not something you ever want to run against a real database.
Now let’s test all of our new routes from our terminal. Let’s first start the app by running it from Xcode or running:
```bash
swift run
```

Log in and copy your token:
```bash
# Sign up
curl -X POST http://localhost:8080/api/auth/signup -H "Content-Type: application/json" -d '{ "email": "tom@example.com", "name":"Tom", "password": "password123" }'

# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "tom@example.com",
    "password": "password123"
  }'

#Create a collection:

curl -X POST http://localhost:8080/api/collections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "Vapor"
  }'
  
  # Response {"createdAt":"2026-08-08T17:33:51Z","id":"7C33F32B-1D14-4173-B6E6-245D95918A59","name":"Vapor"}

#List collections:

curl http://localhost:8080/api/collections \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

# Response [{"createdAt":"2026-08-08T17:33:51Z","id":"7C33F32B-1D14-4173-B6E6-245D95918A59","name":"Vapor"}]
```

Copy the collection id from the response.
```bash
# Create a tag:

curl -X POST http://localhost:8080/api/tags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "swift"
  }'
# Response: {"name":"swift","createdAt":"2026-08-08T17:39:44Z","id":"52630FCD-BC67-4D5A-81EF-8EB8576C5736"}

# Create another tag:

curl -X POST http://localhost:8080/api/tags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "name": "backend"
  }'
# Response: {"createdAt":"2026-08-08T17:40:24Z","id":"794337DA-AFC7-481F-AAEC-8A317FEC2ED5","name":"backend"}

#List tags:

curl http://localhost:8080/api/tags \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
# Response: [{"name":"backend","createdAt":"2026-08-08T17:40:24Z","id":"794337DA-AFC7-481F-AAEC-8A317FEC2ED5"},{"name":"swift","createdAt":"2026-08-08T17:39:44Z","id":"52630FCD-BC67-4D5A-81EF-8EB8576C5736"}]
#Copy the tag ids from the response.
```

Now create a link that belongs to a collection and has tags:
```bash
curl -X POST http://localhost:8080/api/links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "title": "Vapor Fluent Relations",
    "url": "https://docs.vapor.codes/fluent/relations/",
    "note": "Read this before adding more relationship-heavy features.",
    "collectionID": "COLLECTION_ID_HERE",
    "tagIDs": [
      "TAG_ID_HERE",
      "ANOTHER_TAG_ID_HERE"
    ]
  }'
# Response: {"createdAt":"2026-08-08T17:43:40Z","id":"8036CBCD-55EE-4737-9CB2-8768C5B2ED70","url":"https:\/\/docs.vapor.codes\/fluent\/relations\/","title":"Vapor Fluent Relations","note":"Read this before adding more relationship-heavy features.","isRead":false}
```

The response should now include the collection and tags.
```bash
# Filter unread links:

curl "http://localhost:8080/api/links?isRead=false" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
  
 #Response: [{"createdAt":"2026-08-08T17:43:40Z","title":"Vapor Fluent Relations","id":"8036CBCD-55EE-4737-9CB2-8768C5B2ED70","note":"Read this before adding more relationship-heavy features.","url":"https:\/\/docs.vapor.codes\/fluent\/relations\/","isRead":false}]

# Filter by collection:

curl "http://localhost:8080/api/links?collectionID=COLLECTION_ID_HERE" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
# Response: [{"createdAt":"2026-08-08T17:43:40Z","id":"8036CBCD-55EE-4737-9CB2-8768C5B2ED70","url":"https:\/\/docs.vapor.codes\/fluent\/relations\/","title":"Vapor Fluent Relations","note":"Read this before adding more relationship-heavy features.","isRead":false}]

# Filter by tag:

curl "http://localhost:8080/api/links?tagID=TAG_ID_HERE" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
#Response: [{"createdAt":"2026-08-08T17:43:40Z","title":"Vapor Fluent Relations","id":"8036CBCD-55EE-4737-9CB2-8768C5B2ED70","note":"Read this before adding more relationship-heavy features.","url":"https:\/\/docs.vapor.codes\/fluent\/relations\/","isRead":false}]

# Paginate results:

curl "http://localhost:8080/api/links?page=1&perPage=10" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"

#Response: [{"createdAt":"2026-08-08T17:43:40Z","id":"8036CBCD-55EE-4737-9CB2-8768C5B2ED70","url":"https:\/\/docs.vapor.codes\/fluent\/relations\/","title":"Vapor Fluent Relations","note":"Read this before adding more relationship-heavy features.","isRead":false}]
```

This is fantastic! Now we can query links in a much more useful way. Instead of returning one flat list, the API can answer questions like:
- Show me unread links.
- Show me links in this collection.
- Show me links with this tag.
- Show me the next page of saved links.

To summarize this post, we made LinkVault feel much more like a real saved-links product.
- We added collections so users can organize links into folders.
- We added tags so users can label links in a more flexible way.
- We used a one-to-many relationship for collections and links.
- We used a many-to-many relationship for links and tags.
- We created a pivot model with LinkTag.
- We updated migrations to add new tables and relationships.
- We added filtering by collection, tag, and read status.
- We added basic pagination.

Most importantly, we kept user ownership at the center of every query.
That is the pattern we want to keep repeating: authenticate the user, then scope the query to that user. After that we perform the operation.
The authentication tells us who is making the request, and user-scoped queries make sure they can only access their own data.

So what’s next?

In the next post we will work on background jobs and metadata fetching.
When a user saves a link, we should be able to fetch metadata about that URL in the background, such as the page title, description, image URL, and site name. This will introduce us to queues, jobs, and asynchronous backend workflows! Instead of doing every piece of work during the HTTP request, we’ll learn how to move slow work into the background.
Thanks for coming along on the ride with me learning server side swift with Vapor! Happy coding and I'll see you in the next post 👨‍💻