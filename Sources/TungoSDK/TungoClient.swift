import Foundation

public struct SSEEvent: Sendable, Equatable {
    public let event: String
    public let raw: String
}

public struct TungoError: Error, Sendable {
    public let status: Int
    public let code: String
    public let message: String
}

public enum TungoMoney {
    public static func toTiyn(_ amount: Double) -> Int64 {
        Int64((amount * 100.0).rounded())
    }

    public static func toTenge(_ tiyn: Int64) -> Double {
        Double(tiyn) / 100.0
    }

    public static func formatTiyn(_ tiyn: Int64, currency: String = "KZT") -> String {
        let symbol: String
        switch currency.trimmingCharacters(in: .whitespaces).uppercased() {
        case "", "KZT": symbol = "₸"
        case "USD": symbol = "$"
        case "EUR": symbol = "€"
        case "RUB": symbol = "₽"
        default: symbol = currency.uppercased()
        }
        let neg = tiyn < 0
        let absVal = abs(tiyn)
        let wholeStr = String(absVal / 100)
        let frac = absVal % 100
        var grouped = ""
        for (i, ch) in wholeStr.enumerated() {
            if i > 0 && (wholeStr.count - i) % 3 == 0 {
                grouped.append(" ")
            }
            grouped.append(ch)
        }
        let sign = neg ? "-" : ""
        return String(format: "%@%@,%02lld %@", sign, grouped, frac, symbol)
    }
}

public final class TungoClient: @unchecked Sendable {
    public let apiKey: String?
    public let baseUrl: String
    public let workspaceId: String?
    public let companyId: String?

    public var workspaces: WorkspacesResource { WorkspacesResource(client: self) }
    public var companies: CompaniesResource { CompaniesResource(client: self) }
    public var platform: PlatformResource { PlatformResource(client: self) }
    public var apiKeys: ApiKeysResource { ApiKeysResource(client: self) }
    public var webhooks: WebhooksResource { WebhooksResource(client: self) }
    public var chat: ChatResource { ChatResource(client: self) }
    public var proposals: ProposalsResource { ProposalsResource(client: self) }
    public var feed: FeedResource { FeedResource(client: self) }
    public var batches: BatchesResource { BatchesResource(client: self) }
    public var esf: EsfResource { EsfResource(client: self) }
    public var forms: FormsResource { FormsResource(client: self) }
    public var onec: OnecResource { OnecResource(client: self) }
    public var automations: AutomationsResource { AutomationsResource(client: self) }

    public init(
        apiKey: String? = ProcessInfo.processInfo.environment["TUNGO_API_KEY"],
        baseUrl: String = ProcessInfo.processInfo.environment["TUNGO_BASE_URL"] ?? "https://api.tungo.ai",
        workspaceId: String? = ProcessInfo.processInfo.environment["TUNGO_WORKSPACE_ID"],
        companyId: String? = ProcessInfo.processInfo.environment["TUNGO_COMPANY_ID"]
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        self.workspaceId = workspaceId
        self.companyId = companyId
    }

    public func resolveCompanyId(_ explicit: String? = nil) throws -> String {
        if let e = explicit, !e.isEmpty { return e }
        if let c = companyId, !c.isEmpty { return c }
        throw TungoError(status: 0, code: "missing_company_id", message: "Не указан companyId")
    }

    public func resolveWorkspaceId(_ explicit: String? = nil) throws -> String {
        if let e = explicit, !e.isEmpty { return e }
        if let w = workspaceId, !w.isEmpty { return w }
        throw TungoError(status: 0, code: "missing_workspace_id", message: "Не указан workspaceId")
    }

    /// Быстрый синхронный запрос к ИИ-бухгалтеру (stream = false).
    public func ask(prompt: String, companyId: String? = nil) async throws -> [String: Any] {
        var params: [String: String] = [:]
        if let c = companyId { params["co"] = c }
        return try await chat.create(body: ["message": prompt, "stream": false], params: params)
    }

    public func request(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?,
        auth: String,
        idempotent: Bool,
        retrySafe: Bool
    ) async throws -> [String: Any] {
        [:]
    }

    public func requestStream(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?,
        auth: String
    ) async throws -> [SSEEvent] {
        []
    }
}
