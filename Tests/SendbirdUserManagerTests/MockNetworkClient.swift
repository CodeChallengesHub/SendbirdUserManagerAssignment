//
//  MockNetworkClient.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

protocol URLRequestProvider {
    var url: URL { get }
    var method: MethodType { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    var mockResponse: Data? { get }
    func parseResponse(_ data: Data) throws -> Any
}

enum MethodType: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
}

typealias UserID = String
typealias Nickname = String

enum UserRequestType {
    case createUser(UserCreationParams)
    case updateUser(UserID, UserUpdateParams)
    case getUserById(UserID)
    case getUserByNickname(Nickname)
    
    var method: MethodType {
        switch self {
        case .createUser:
            return .post
        case .updateUser:
            return .put
        case .getUserById, .getUserByNickname:
            return .get
        }
    }
    
    var path: String {
        switch self {
        case .createUser, .getUserByNickname:
            return "/v3/users"
        case .updateUser(let userId, _):
            return "/v3/users/\(userId)"
        case .getUserById(let userId):
            return "/v3/users/\(userId)"
        }
    }
    
    var body: Data? {
        switch self {
        case .createUser(let params):
            return try? JSONSerialization.data(withJSONObject: params.toDictionary(), options: [])
        case .updateUser(_, let params):
            return try? JSONSerialization.data(withJSONObject: params.toDictionary(), options: [])
        case .getUserById, .getUserByNickname:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .createUser, .updateUser, .getUserById:
            return nil
        case .getUserByNickname(let nickname):
            return [
                .init(name: "limit", value: "100"),
                .init(name: "nickname", value: nickname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
            ]
        }
    }
    
    var headers: [String: String] {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
    
    var mockResponse: Data? {
        return nil
    }
}

struct UserRequest<T: Decodable>: Request, URLRequestProvider {
    typealias Response = T
    
    let requestUrl: URL
    let applicationId: String
    let apiToken: String
    let requestType: UserRequestType
    
    init(applicationId: String, apiToken: String, requestType: UserRequestType) throws {
        let urlString = "https://api-\(applicationId).sendbird.com" + requestType.path
        var urlComponents = URLComponents(string: urlString)
        urlComponents?.queryItems = requestType.queryItems
        guard let url = urlComponents?.url else {
            throw SendbirdError.request(.createFailure("Failed to create UserRequest due to invalid URL: \(urlComponents?.url?.absoluteString ?? urlString)"))
        }
        self.requestUrl = url
        self.applicationId = applicationId
        self.apiToken = apiToken
        self.requestType = requestType
    }
    
    var url: URL { requestUrl }
    var method: MethodType { requestType.method }
    var body: Data? { requestType.body }
    var headers: [String: String] {
        requestType.headers.merging([ "Api-Token": apiToken ]) { (_, new) in new }
    }
    var mockResponse: Data? { requestType.mockResponse }
    func parseResponse(_ data: Data) throws -> Any {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SendbirdError.decoding(.decodingFailure(error.localizedDescription))
        }
    }
}

class MockNetworkClient: SBNetworkClient {
    private let session: URLSession
    private let rateLimiter: TokenBucketRateLimiter
    
    init(session: URLSession = .shared) {
        self.session = session
        self.rateLimiter = TokenBucketRateLimiter(maxTokens: 10)
    }
    
    func request<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    ) {
        rateLimiter.executeRequest { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.sendRequest(request: request, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
    
    private func sendRequest<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    ) {
        guard let request = request as? URLRequestProvider else {
            completionHandler(.failure(SendbirdError.request(.invalidRequest("Request does not conform to URLRequestProvider protocol."))))
            return
        }
        
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        request.headers.forEach { urlRequest.addValue($1, forHTTPHeaderField: $0) }
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        // 요청 로그
        print("NetworkClient --> \(urlRequest.httpMethod ?? "N/A") \(urlRequest.url?.absoluteString ?? "")")
        print("NetworkClient Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let httpBody = urlRequest.httpBody {
            print("NetworkClient HttpBody: \(String(data: httpBody, encoding: .utf8) ?? "N/A")")
        } else {
            print("NetworkClient HttpBody: N/A")
        }
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(SendbirdError.network(.invalidResponse("Expected HTTPURLResponse but received different type"))))
                return
            }
            
            // 응답 로그
            print("NetworkClient <-- \(httpResponse.statusCode) \(response?.url?.absoluteString ?? "")")
            if let data = data, let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("NetworkClient Response: \(responseString)")
            } else {
                print("NetworkClient Response: N/A")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completionHandler(.failure(SendbirdError.network(.invalidStatusCode(httpResponse.statusCode))))
                return
            }
            
            guard let data = data else {
                completionHandler(.failure(SendbirdError.network(.invalidData("No data received from the server."))))
                return
            }
            
            do {
                if let response = try request.parseResponse(data) as? R.Response {
                    completionHandler(.success(response))
                } else {
                    let responseDataString = String(data: data, encoding: .utf8) ?? "Unable to decode data"
                    completionHandler(.failure(SendbirdError.network(.invalidData("Failed to parse response: \(responseDataString)"))))
                }
            } catch {
                completionHandler(.failure(error))
            }
        }
        
        task.resume()
    }
}
