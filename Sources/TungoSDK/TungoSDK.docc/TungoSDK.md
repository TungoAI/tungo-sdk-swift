# ``TungoSDK``

The official Swift library for the Tungo Platform API.

## Overview

Create one ``TungoClient`` and share it: it is immutable and `Sendable`. Every operation of the API is an
`async throws` method on one of the client's resources and returns a typed, `Codable` and `Sendable` model.

```swift
import TungoSDK

let client = TungoClient(apiKey: "tg_...", companyID: "co_...")

let reply = try await client.ask("What is the VAT on the last sale?")
print(reply.answer)
```

## Topics

### Client

- ``TungoClient``
- ``RequestOptions``
- ``APIResponse``
- ``RateLimit``
- ``TungoTransport``
- ``URLSessionTransport``

### Resources

- ``WorkspacesResource``
- ``CompaniesResource``
- ``PlatformResource``
- ``ApiKeysResource``
- ``WebhooksResource``
- ``ChatResource``
- ``ProposalsResource``
- ``FeedResource``
- ``BatchesResource``
- ``EsfResource``
- ``FormsResource``
- ``OnecResource``
- ``AutomationsResource``

### Errors

- ``TungoError``
- ``APIError``
- ``ConnectionError``
- ``TimeoutError``
- ``DecodeError``
- ``ConfigurationError``
- ``ValidationError``
- ``StreamError``
- ``PaginationError``
- ``WebhookVerificationError``
- ``MoneyError``

### Pagination and streaming

- ``Page``
- ``PageSequence``
- ``EventStream``
- ``ChatStream``
- ``ChatAccumulator``
- ``ChatStreamResult``
- ``ServerSentEvent``
- ``ServerSentEventParser``

### Webhooks and money

- ``TungoWebhooks``
- ``TungoMoney``
- ``TungoKazakhstan``

### JSON building blocks

- ``JSONValue``
- ``Nullable``
- ``TungoEnum``
