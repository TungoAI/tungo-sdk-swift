// Verifies a webhook read from standard input.
//
//   TUNGO_WEBHOOK_SECRET=whsec_... swift run TungoVerifyWebhookExample <webhook-id> <webhook-timestamp> <webhook-signature> < body.json

import Foundation
import TungoSDK

let arguments = ProcessInfo.processInfo.arguments

guard arguments.count == 4 else {
    print("usage: VerifyWebhook <webhook-id> <webhook-timestamp> <webhook-signature> < body")
    exit(2)
}
let body = FileHandle.standardInput.readDataToEndOfFile()
let headers = [
    "webhook-id": arguments[1],
    "webhook-timestamp": arguments[2],
    "webhook-signature": arguments[3],
]
do {
    let event = try TungoClient().verifyWebhook(body: body, headers: headers)
    print("verified:", event.typeTag ?? "unknown event")
} catch let error as WebhookVerificationError {
    print("rejected (\(error.reason.rawValue)):", error.message)
    exit(1)
}
