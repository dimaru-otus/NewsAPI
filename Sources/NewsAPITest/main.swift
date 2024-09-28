import OpenAPIRuntime
import OpenAPIURLSession
import Foundation
import NewsAPI

#if PROXY_ENABLED
let configuration = URLSessionConfiguration.default
let proxyConfiguration: [AnyHashable : Any] = [
    kCFNetworkProxiesHTTPSEnable as AnyHashable: true,
    kCFNetworkProxiesHTTPSPort as AnyHashable: 1087,
    kCFNetworkProxiesHTTPSProxy as AnyHashable: "172.16.1.6",
]

configuration.connectionProxyDictionary = proxyConfiguration
let client = Client(
    serverURL: try Servers.server1(),
    transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: configuration))),
    middlewares: [
        LoggingMiddleware(loggingPolicy: .full),
    ]
)
#else

let client = Client(
    serverURL: try Servers.server1(),
    transport: URLSessionTransport(),
    middlewares: [
        LoggingMiddleware(loggingPolicy: .brief),
    ]
)
#endif

print(try! Servers.server1())

do {
    let query = Operations.getArticles.Input.Query(
        apiKey: BuildEnvironment.newsApiKey,
        resultType: .articles,
        articlesPage: 1,
        articlesCount: 20,
        articlesSortBy: .date,
        articlesSortByAsc: false,
        articleBodyLen: -1,
        keyword: ["apple", "iphone"],
        lang: [.eng],
        includeArticleBody: true,
        includeArticleImage: true,
        includeArticleLinks: true
    )
    let response = try await client.getArticles(query: query)
            
    switch(response) {
    case .ok(let okResponce):
        let pagination: NewsAPI.Components.Schemas.MultipleItems = try! okResponce.body.json.value1.articles.value1
        print("Pagination:", pagination)
        let results: [NewsAPI.Components.Schemas.Article] = try! okResponce.body.json.value1.articles.value2.results
        print("Articles:", results)
    case .undocumented(let statusCode, let payload):
        print("Request error:", statusCode, "message:", try await String(collecting: payload.body!, upTo: 1024))
    }
} catch {
    switch error {
    case let decodingError as DecodingError:
        print("Decoding error:", decodingError.localizedDescription)
    case let clientError as ClientError:
        print("Underlying:", clientError.underlyingError.localizedDescription)
    default:
        print("Unknown error:", error)
    }
}
