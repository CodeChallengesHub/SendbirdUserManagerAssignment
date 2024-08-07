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

// NetworkError 정의
enum NetworkError: Error {
    case invalidResponse
    case invalidData
    case invalidUrl
    case decodingError
}

struct UserRequest: Request, URLRequestProvider {
    typealias Response = SBUser
    
    private let requestUrl: URL
    private let apiToken: String
    private let bodyData: Data
    
    init?(applicationId: String, apiToken: String, params: UserCreationParams) {
        guard let url = URL(string: "https://api-\(applicationId).sendbird.com/v3/users") else { return nil }
        self.requestUrl = url
        self.apiToken = apiToken
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: params.toDictionary(), options: [])
            self.bodyData = jsonData
        } catch {
            return nil
        }
    }
    
    var url: URL { requestUrl }
    var method: MethodType { .post }
    var body: Data? { bodyData }
    var headers: [String : String] {
        [
            "Api-Token": apiToken,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
    var mockResponse: Data?
    
    func parseResponse(_ data: Data) throws -> Any {
        guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = jsonDict["user_id"] as? String,
              let nickname = jsonDict["nickname"] as? String else {
            throw NetworkError.decodingError
        }
        let profileURL = jsonDict["profile_url"] as? String
        return SBUser(userId: userId, nickname: nickname, profileURL: profileURL)
    }
}

class MockNetworkClient: SBNetworkClient {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func request<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    ) {
        guard let urlRequestProvider = request as? URLRequestProvider else {
            completionHandler(.failure(NetworkError.invalidData))
            return
        }
        
        var urlRequest = URLRequest(url: urlRequestProvider.url)
        urlRequest.httpMethod = urlRequestProvider.method.rawValue
        urlRequestProvider.headers.forEach { urlRequest.addValue($1, forHTTPHeaderField: $0) }
        if let body = urlRequestProvider.body {
            urlRequest.httpBody = body
        }
        
        // 요청 로그
        print("NetworkClient --> \(urlRequest.httpMethod ?? "N/A") \(urlRequestProvider.url.absoluteString)")
        print("NetworkClient Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        print("NetworkClient HttpBody: \(String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "N/A")")
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            // 응답 로그
            if let httpResponse = response as? HTTPURLResponse {
                print("NetworkClient <-- \(httpResponse.statusCode) \(response?.url?.absoluteString ?? "")")
                if let data = data {
                    print("NetworkClient Response: \(String(data: data, encoding: .utf8) ?? "")")
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completionHandler(.failure(NetworkError.invalidResponse))
                return
            }
            
            guard let data = data else {
                completionHandler(.failure(NetworkError.invalidData))
                return
            }
            
            do {
                if let response = try urlRequestProvider.parseResponse(data) as? R.Response {
                    completionHandler(.success(response))
                } else {
                    completionHandler(.failure(NetworkError.decodingError))
                }
            } catch {
                completionHandler(.failure(NetworkError.decodingError))
            }
        }
        
        task.resume()
    }
}
