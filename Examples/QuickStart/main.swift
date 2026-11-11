// Lists the companies of the API key and asks one question.
//
//   TUNGO_API_KEY=tg_... swift run TungoQuickStartExample "What is the VAT on the last sale?"

import Foundation
import TungoSDK

let arguments = ProcessInfo.processInfo.arguments

let client = TungoClient()
do {
    let companies = try await client.companies.list()
    print("Companies:", companies)
    if arguments.count > 2 {
        let reply = try await client.ask(arguments[2], companyID: arguments[1])
        print(reply.answer)
    }
} catch let error as APIError {
    print("API error:", error.message)
    exit(1)
} catch {
    print("Error:", error.localizedDescription)
    exit(1)
}
