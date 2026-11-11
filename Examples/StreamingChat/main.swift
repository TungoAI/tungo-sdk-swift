// Streams one chat answer to the terminal.
//
//   TUNGO_API_KEY=tg_... swift run TungoStreamingChatExample co_... "Show the receivables for October"

import Foundation
import TungoSDK

let arguments = ProcessInfo.processInfo.arguments

guard arguments.count > 2 else {
    print("usage: StreamingChat <company id> <message>")
    exit(2)
}
let client = TungoClient(companyID: arguments[1])
do {
    let stream = try await client.streamChat(arguments[2])
    var turn = ChatAccumulator()
    for try await event in stream {
        turn.add(event)
        if case .text(let text) = event {
            FileHandle.standardOutput.write(Data(text.delta.utf8))
        }
    }
    print("\n--\nstop reason: \(turn.stopReason ?? "-"), cost: \(TungoMoney.formatTiyn(turn.costTiyn ?? 0))")
    if let error = turn.error { throw error }
} catch {
    print("Error:", error.localizedDescription)
    exit(1)
}
