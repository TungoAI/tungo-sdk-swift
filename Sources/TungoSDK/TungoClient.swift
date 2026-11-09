import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SSEEvent: Sendable, Equatable {
    public let event: String
    public let raw: String
}

public struct TungoError: Error, Sendable {
    public let status: Int
    public let code: String
    public let message: String
    public let hint: String?
    public let requestId: String?

    public init(status: Int, code: String, message: String, hint: String? = nil, requestId: String? = nil) {
        self.status = status
        self.code = code
        self.message = message
        self.hint = hint
        self.requestId = requestId
    }
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

    /// Проверяет контрольный разряд 12-значного БИН/ИИН Республики Казахстан (модуль 11, 2 прохода).
    public static func isValidBinIin(_ value: String) -> Bool {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count == 12 else { return false }
        var digits: [Int] = []
        digits.reserveCapacity(12)
        for ch in s {
            guard let d = ch.wholeNumberValue else { return false }
            digits.append(d)
        }
        let w1 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
        var sum1 = 0
        for i in 0..<11 { sum1 += digits[i] * w1[i] }
        var rem = sum1 % 11
        if rem == 10 {
            let w2 = [3, 4, 5, 6, 7, 8, 9, 10, 11, 1, 2]
            var sum2 = 0
            for i in 0..<11 { sum2 += digits[i] * w2[i] }
            rem = sum2 % 11
        }
        return rem < 10 && rem == digits[11]
    }
}

public final class TungoClient: @unchecked Sendable {
    public let apiKey: String?
    public let baseUrl: String
    public let workspaceId: String?
    public let companyId: String?
    public let maxRetries: Int

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
        baseUrl: String = ProcessInfo.processInfo.environment["TUNGO_BASE_URL"] ?? "https://api.tungo.kz",
        workspaceId: String? = ProcessInfo.processInfo.environment["TUNGO_WORKSPACE_ID"],
        companyId: String? = ProcessInfo.processInfo.environment["TUNGO_COMPANY_ID"],
        maxRetries: Int = 3
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        self.workspaceId = workspaceId
        self.companyId = companyId
        self.maxRetries = max(0, maxRetries)
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
    public func ask(prompt: String, companyId: String? = nil, dialogId: String? = nil) async throws -> [String: Any] {
        var params: [String: String] = [:]
        if let c = companyId { params["co"] = c }
        var body: [String: Any] = ["message": prompt, "stream": false]
        if let d = dialogId, !d.isEmpty { body["dialog_id"] = d }
        return try await chat.create(body: body, params: params)
    }

    /// Ожидает завершения запуска сценария автоматизации (state in done | error | cancelled | skipped).
    public func waitForRun(runId: String, companyId: String? = nil, pollIntervalMs: UInt64 = 1000, timeoutMs: UInt64 = 120_000) async throws -> [String: Any] {
        var params: [String: String] = [:]
        if let c = companyId { params["co"] = c }
        let start = DispatchTime.now().uptimeNanoseconds
        while true {
            let run = try await automations.getRun(runId: runId, params: params)
            let state = (run["state"] as? String) ?? ""
            if ["done", "error", "cancelled", "skipped"].contains(state) {
                return run
            }
            let elapsedMs = (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if elapsedMs >= timeoutMs {
                throw TungoError(status: 408, code: "timeout", message: "waitForRun превысил таймаут \(timeoutMs) мс для \(runId)")
            }
            try await Task.sleep(nanoseconds: pollIntervalMs * 1_000_000)
        }
    }

    /// Ожидает завершения пакетной задачи (running == false).
    public func waitForBatch(batchId: String, companyId: String? = nil, pollIntervalMs: UInt64 = 1500, timeoutMs: UInt64 = 300_000) async throws -> [String: Any] {
        var params: [String: String] = [:]
        if let c = companyId { params["co"] = c }
        let start = DispatchTime.now().uptimeNanoseconds
        while true {
            let job = try await batches.get(id: batchId, params: params)
            let running = (job["running"] as? Bool) ?? false
            if !running {
                return job
            }
            let elapsedMs = (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if elapsedMs >= timeoutMs {
                throw TungoError(status: 408, code: "timeout", message: "waitForBatch превысил таймаут \(timeoutMs) мс для \(batchId)")
            }
            try await Task.sleep(nanoseconds: pollIntervalMs * 1_000_000)
        }
    }

    public static func parseSse(_ raw: String) -> [SSEEvent] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        var out: [SSEEvent] = []
        for frame in normalized.components(separatedBy: "\n\n") {
            let trimmed = frame.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            var ev = "message"
            var dataLines: [String] = []
            for line in frame.components(separatedBy: "\n") {
                if line.isEmpty || line.hasPrefix(":") { continue }
                if line.hasPrefix("event:") {
                    ev = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    var v = String(line.dropFirst(5))
                    if v.hasPrefix(" ") { v = String(v.dropFirst()) }
                    dataLines.append(v)
                }
            }
            if dataLines.isEmpty { continue }
            out.append(SSEEvent(event: ev, raw: dataLines.joined(separator: "\n")))
        }
        return out
    }

    private func buildUrl(path: String, query: [String: String]) throws -> URL {
        guard var comp = URLComponents(string: baseUrl + path) else {
            throw TungoError(status: 0, code: "invalid_url", message: "Некорректный URL: \(baseUrl + path)")
        }
        if !query.isEmpty {
            comp.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        guard let url = comp.url else {
            throw TungoError(status: 0, code: "invalid_url", message: "Некорректный URL: \(baseUrl + path)")
        }
        return url
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
        let url = try buildUrl(path: path, query: query)
        let idempKey = idempotent ? UUID().uuidString : nil
        let canRetry = retrySafe || idempotent || method == "GET" || method == "HEAD" || method == "OPTIONS"
        let limit = canRetry ? maxRetries : 0

        for attempt in 0...limit {
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("tungo-sdk-swift/0.1.0", forHTTPHeaderField: "User-Agent")
            if auth != "none", let key = apiKey, !key.isEmpty {
                req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            if let ik = idempKey {
                req.setValue(ik, forHTTPHeaderField: "Idempotency-Key")
            }
            if let b = body {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: b)
            }

            let (data, resp) = try await URLSession.shared.data(for: req)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 200
            if status >= 200 && status < 300 {
                if data.isEmpty { return [:] }
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return obj
                }
                return ["data": String(data: data, encoding: .utf8) ?? ""]
            }
            if attempt < limit && (status == 429 || status == 502 || status == 503 || status == 504) {
                let delayNs = UInt64(300_000_000 * (1 << attempt))
                try await Task.sleep(nanoseconds: delayNs)
                continue
            }
            var code = "api_error"
            var msg = String(data: data, encoding: .utf8) ?? "HTTP \(status)"
            var hint: String? = nil
            var reqId: String? = nil
            if let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                reqId = parsed["request_id"] as? String
                let errObj = (parsed["error"] as? [String: Any]) ?? parsed
                if let c = errObj["code"] as? String { code = c }
                if let m = errObj["message"] as? String { msg = m }
                hint = (errObj["hint"] as? String) ?? (parsed["hint"] as? String)
            }
            throw TungoError(status: status, code: code, message: msg, hint: hint, requestId: reqId)
        }
        return [:]
    }

    public func requestStream(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?,
        auth: String
    ) async throws -> [SSEEvent] {
        let url = try buildUrl(path: path, query: query)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("tungo-sdk-swift/0.1.0", forHTTPHeaderField: "User-Agent")
        if auth != "none", let key = apiKey, !key.isEmpty {
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: b)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 200
        let raw = String(data: data, encoding: .utf8) ?? ""
        if status < 200 || status >= 300 {
            throw TungoError(status: status, code: "api_error", message: raw)
        }
        return Self.parseSse(raw)
    }
}
