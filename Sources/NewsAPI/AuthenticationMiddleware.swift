//
//  AuthenticationMiddleware.swift
//  GeoDBCitiesAPI
//
//  Created by Dmitriy Borovikov on 17.09.2024.
//

import Foundation
import OpenAPIRuntime
import HTTPTypes

extension HTTPField.Name {
    public static var rapidapiKey: Self { .init("x-rapidapi-key")! }
}

public struct AuthenticationMiddleware: ClientMiddleware {
    private let token: String
    
    public init(token: String) {
        self.token = token
    }
    
    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.rapidapiKey] = token
        return try await next(request, body, baseURL)
    }
}
