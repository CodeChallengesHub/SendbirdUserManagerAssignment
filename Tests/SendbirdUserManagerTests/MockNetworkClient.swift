//
//  MockNetworkClient.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

/**
 `URLRequestProvider` 프로토콜은 네트워크 요청을 구성하는 데 필요한 필수 요소를 정의합니다.
 
 이 프로토콜을 구현함으로써 각 요청이 URL, HTTP 메서드, 요청 바디, 헤더 등을 명확하게 규격화할 수 있습니다.
 
 - Properties:
   - url: 요청할 URL
   - method: HTTP 메서드 (GET, POST 등)
   - body: 요청의 본문 데이터
   - headers: 요청의 헤더 정보
   - parseResponse: 서버 응답 데이터를 파싱하는 메서드
 */
protocol URLRequestProvider {
    var url: URL { get }
    var method: MethodType { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    func parseResponse(_ data: Data) throws -> Any
}

/**
 `MethodType` 열거형은 HTTP 메서드의 타입을 정의합니다.
 
 - GET: 데이터 조회 요청
 - POST: 데이터 생성 요청
 - PATCH: 데이터 일부 업데이트 요청
 - PUT: 데이터 전체 업데이트 요청
 */
enum MethodType: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
}

typealias UserID = String
typealias Nickname = String

/**
 `UserRequestType` 열거형은 Sendbird User API의 다양한 요청 타입을 정의합니다.
 
 각 케이스는 특정한 API 요청을 나타내며, 이를 통해 HTTP 메서드, URL 경로, 요청 본문 및 헤더 등을 관리할 수 있습니다.
 
 - createUser: 새로운 사용자 생성 요청
 - updateUser: 기존 사용자 정보 업데이트 요청
 - getUserById: 특정 사용자 ID로 사용자 조회 요청
 - getUserByNickname: 특정 닉네임으로 사용자 조회 요청
 */
enum UserRequestType {
    case createUser(UserCreationParams)
    case updateUser(UserID, UserUpdateParams)
    case getUserById(UserID)
    case getUserByNickname(Nickname)
    
    /**
     요청 타입에 따른 HTTP 메서드를 반환합니다.
     */
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
    
    /**
     요청 타입에 따른 URL 경로를 반환합니다.
     */
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
    
    /**
     요청 타입에 따른 요청 본문 데이터를 반환합니다.
     */
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
    
    /**
     요청 타입에 따른 URL 쿼리 파라미터를 반환합니다.
     */
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
    
    /**
     요청 타입에 따른 HTTP 헤더를 반환합니다.
     */
    var headers: [String: String] {
        return [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }
}

/**
 `UserRequest` 구조체는 Sendbird User API에 대한 HTTP 요청을 구성하고 관리합니다.
 
 이 구조체는 제네릭 타입 T를 사용하여 다양한 API 응답을 처리할 수 있으며, API 요청의 URL, 메서드, 본문 및 헤더를 설정하고 응답 데이터를 파싱합니다.
 
 - Parameters:
   - applicationId: Sendbird Application ID
   - apiToken: API 토큰
   - requestType: User API 요청 타입
 */
struct UserRequest<T: Decodable>: Request, URLRequestProvider {
    typealias Response = T
    
    let requestUrl: URL
    let applicationId: String
    let apiToken: String
    let requestType: UserRequestType
    
    /**
     UserRequest 구조체의 초기화 메서드. URL, API 토큰, 요청 타입을 기반으로 HTTP 요청을 구성합니다.
     
     - Parameters:
       - applicationId: Sendbird Application ID
       - apiToken: API 토큰
       - requestType: User API 요청 타입
     - Throws: URL이 유효하지 않을 경우 오류를 발생시킵니다.
     */
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
    
    /**
     서버 응답 데이터를 제네릭 타입 T로 디코딩하여 반환합니다.
     
     - Parameters:
       - data: 서버로부터 받은 응답 데이터
     - Returns: 디코딩된 응답 객체
     - Throws: 디코딩 중 발생한 오류를 던집니다.
     */
    func parseResponse(_ data: Data) throws -> Any {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw error
        }
    }
}

/**
 `MockNetworkClient` 클래스는 Sendbird User API와의 상호작용을 처리하는 네트워크 클라이언트로,
 요청의 속도 제한을 관리하고 요청 및 응답에 대한 로그를 출력합니다.
 
 이 클래스는 `TokenLeakyBucketRateLimiter`를 사용하여 요청이 초당 1회로 제한되도록 구현되었으며,
 최대 10개의 요청을 대기시킬 수 있습니다.
 
 또한, 모든 네트워크 요청과 응답에 대한 상세한 로그를 출력하여,
 개발 및 테스트 과정에서 API 동작을 쉽게 추적하고 디버깅할 수 있도록 돕습니다.
 로그에는 요청의 URL, 메서드, 헤더, 바디 내용과 응답의 상태 코드, 헤더, 바디 내용이 포함됩니다.
 */
class MockNetworkClient: SBNetworkClient {
    private let session: URLSession
    private let rateLimiter: TokenLeakyBucketRateLimiter
    
    init(session: URLSession = .shared) {
        self.session = session
        self.rateLimiter = TokenLeakyBucketRateLimiter(bucketCapacity: 10, leakInterval: 1)
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("MockNetworkClient: [\(timestamp)] \(message)")
    }
    
    /**
     네트워크 요청을 실행합니다. TokenLeakyBucketRateLimiter를 통해 요청의 속도 제한을 관리하며, 성공 시 요청을 보내고 실패 시 에러를 반환합니다.
     
     - Parameters:
     - request: 실행할 네트워크 요청
     - completionHandler: 요청이 완료된 후 호출되는 클로저. 성공 시 디코딩된 응답 객체를 반환하고, 실패 시 에러를 반환합니다.
     */
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
    
    /**
     실제 네트워크 요청을 생성하고 실행하는 메서드입니다. 요청을 URLRequest로 변환하여 URLSession을 통해 실행합니다.
     
     - Parameters:
     - request: 실행할 네트워크 요청
     - completionHandler: 요청이 완료된 후 호출되는 클로저. 성공 시 디코딩된 응답 객체를 반환하고, 실패 시 에러를 반환합니다.
     */
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
        log("--> \(urlRequest.httpMethod ?? "N/A") \(urlRequest.url?.absoluteString ?? "")")
        log("Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        if let httpBody = urlRequest.httpBody {
            log("HttpBody: \(String(data: httpBody, encoding: .utf8) ?? "N/A")")
        } else {
            log("HttpBody: N/A")
        }
        
        let task = session.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.failure(SendbirdError.network(.invalidResponse("Expected HTTPURLResponse but received different type"))))
                return
            }
            
            // 응답 로그
            self.log("<-- \(httpResponse.statusCode) \(response?.url?.absoluteString ?? "")")
            if let data = data, let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                self.log("Response: \(responseString)")
            } else {
                self.log("Response: N/A")
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
