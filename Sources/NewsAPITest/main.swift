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
        AuthenticationMiddleware(token: BuildEnvironment.rapidApiKey),
        LoggingMiddleware(loggingPolicy: .full),
    ]
)
#else

let client = Client(
    serverURL: try Servers.server1(),
    transport: URLSessionTransport(),
    middlewares: [
        AuthenticationMiddleware(token: BuildEnvironment.newsApiKey),
//        LoggingMiddleware(loggingPolicy: .full),
    ]
)
#endif

print(try! Servers.server1())

do {
    let response = try await client.getArticles(query: .init(apiKey: BuildEnvironment.newsApiKey,
                                                             resultType: .articles,
                                                             articlesPage: 1,
                                                             articlesCount: 20,
                                                             articlesSortBy: .date,
                                                             articlesSortByAsc: false,
                                                             articleBodyLen: -1,
                                                             conceptUri: ["https://en.wikipedia.org/wiki/Isaac_Newton"],
                                                             lang: [.eng],
                                                             includeArticleBody: false,
                                                             includeArticleLinks: true
                                                            ),
                                                
                                                headers: .init())
            
    switch(response) {
        
    case .ok(let okResponce):
        let pagination = try! okResponce.body.json.value1.articles.value1
        print("Pagination:", pagination)
        let results: [NewsAPI.Components.Schemas.Article] = okResponce.body.json.value1.articles.value2.results
        print("Articles:", results)
    case .undocumented(statusCode: let statusCode, _):
        print("error: \(statusCode)")
    }
//    print(response)
} catch {
    print(error)
}
