import OpenAPIRuntime
import Foundation
import HTTPTypes

public final actor LoggingMiddleware {
    public struct LoggingPolicy: OptionSet {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        public static let body                 = LoggingPolicy(rawValue: 1 << 0)
        public static let requestHeaders       = LoggingPolicy(rawValue: 1 << 1)
        public static let responceHeaders      = LoggingPolicy(rawValue: 1 << 2)
        
        public static let brief: LoggingPolicy = []
        public static let full: LoggingPolicy  = [.body, .requestHeaders, .responceHeaders]
    }
    
    private let bodyLoggingPolicy: BodyLoggingPolicy
    private let loggingPolicy: LoggingPolicy

    public init(loggingPolicy: LoggingPolicy = .full, bodyLoggingPolicy: BodyLoggingPolicy = .upTo(maxBytes: 2048)) {
        self.loggingPolicy = loggingPolicy
        self.bodyLoggingPolicy = bodyLoggingPolicy
    }
}

extension LoggingMiddleware: ClientMiddleware {
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let (requestBodyToLog, requestBodyForNext) = try await bodyLoggingPolicy.process(body)
        log(request, requestBodyToLog)
        do {
            let (response, responseBody) = try await next(request, requestBodyForNext, baseURL)
            let (responseBodyToLog, responseBodyForNext) = try await bodyLoggingPolicy.process(responseBody)
            log(request, response, responseBodyToLog)
            return (response, responseBodyForNext)
        } catch {
            log(request, failedWith: error)
            throw error
        }
    }
}

extension LoggingMiddleware: ServerMiddleware {
    public func intercept(
        _ request: HTTPTypes.HTTPRequest,
        body: OpenAPIRuntime.HTTPBody?,
        metadata: OpenAPIRuntime.ServerRequestMetadata,
        operationID: String,
        next: @Sendable (HTTPTypes.HTTPRequest, OpenAPIRuntime.HTTPBody?, OpenAPIRuntime.ServerRequestMetadata)
            async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?)
    ) async throws -> (HTTPTypes.HTTPResponse, OpenAPIRuntime.HTTPBody?) {
        let (requestBodyToLog, requestBodyForNext) = try await bodyLoggingPolicy.process(body)
        log(request, requestBodyToLog)
        do {
            let (response, responseBody) = try await next(request, requestBodyForNext, metadata)
            let (responseBodyToLog, responseBodyForNext) = try await bodyLoggingPolicy.process(responseBody)
            log(request, response, responseBodyToLog)
            return (response, responseBodyForNext)
        } catch {
            log(request, failedWith: error)
            throw error
        }
    }
}

extension LoggingMiddleware {
    func log(_ request: HTTPRequest, _ requestBody: BodyLoggingPolicy.BodyLog) {
        print("Request: \(request.method) \(request.scheme ?? "")\(request.path ?? "<nil>")")
        if loggingPolicy.contains(.requestHeaders)  {
            print("Headers:")
            request.headerFields.forEach { print("\($0.name)=\($0.value)") }
        }
        if loggingPolicy.contains(.body), requestBody != .none {
            print("Body:")
            print(requestBody)
        }
    }

    func log(_ request: HTTPRequest, _ response: HTTPResponse, _ responseBody: BodyLoggingPolicy.BodyLog) {
        print("Response: \(response.status) \(request.method) \(request.scheme ?? "")\(request.path ?? "<nil>")")
        if loggingPolicy.contains(.responceHeaders)  {
            print("Headers:")
            response.headerFields.forEach { print("\($0.name)=\($0.value)") }
        }
        if loggingPolicy.contains(.body), responseBody != .none {
            print("Body:")
            print(responseBody)
        }
    }

    func log(_ request: HTTPRequest, failedWith error: any Error) {
        print("Request \(request.method) \(request.path ?? "<nil>") error: \(error.localizedDescription)")
    }
}

public enum BodyLoggingPolicy {
    /// Never log request or response bodies.
    case never
    /// Log request and response bodies that have a known length less than or equal to `maxBytes`.
    case upTo(maxBytes: Int)

    enum BodyLog: Equatable, CustomStringConvertible {
        /// There is no body to log.
        case none
        /// The policy forbids logging the body.
        case redacted
        /// The body was of unknown length.
        case unknownLength
        /// The body exceeds the maximum size for logging allowed by the policy.
        case tooManyBytesToLog(Int64)
        /// The body can be logged.
        case complete(Data)

        var description: String {
            switch self {
            case .none: return "<none>"
            case .redacted: return "<redacted>"
            case .unknownLength: return "<unknown length>"
            case .tooManyBytesToLog(let byteCount): return "<\(byteCount) bytes>"
            case .complete(let data):
                if let string = String(data: data, encoding: .utf8) { return string }
                return String(describing: data)
            }
        }
    }

    func process(_ body: HTTPBody?) async throws -> (bodyToLog: BodyLog, bodyForNext: HTTPBody?) {
        switch (body?.length, self) {
        case (.none, _): return (.none, body)
        case (_, .never): return (.redacted, body)
        case (.unknown, _): return (.unknownLength, body)
        case (.known(let length), .upTo(let maxBytesToLog)) where length > maxBytesToLog:
            return (.tooManyBytesToLog(length), body)
        case (.known, .upTo(let maxBytesToLog)):
            let bodyData = try await Data(collecting: body!, upTo: maxBytesToLog)
            return (.complete(bodyData), HTTPBody(bodyData))
        }
    }
}
