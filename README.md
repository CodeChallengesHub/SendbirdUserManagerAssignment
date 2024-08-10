
> 과제를 진행하면서 각 코드 작성에 대해 어떤 의도로 구현했는지 공유하고자 합니다. 파일별로 상세하게 설명했으며, 과제를 검토하는 데 있어 이해를 돕고자 합니다. 이를 통해 코드를 설계하고 구현한 이유를 명확히 전달하고자 하였으며, 각 코드의 목적과 기능을 쉽게 파악할 수 있도록 했습니다. 검토 과정에서 이 자료가 유용하길 바랍니다.

## 목차
[1. MockUserStorage.swift](#1-mockuserstorageswift)<br>
&ensp;[1-1. Thread Safe하게 코드를 구현하는 방법](#1-1-thread-safe하게-코드를-구현하는-방법)<br>
&ensp;[1-2. Concurrent Queue + Barrier 선택 이유](#1-2-concurrent-queue--barrier-선택-이유)<br>
&ensp;[1-3. clearAllUsers() 메서드 추가](#1-3-clearallusers-메서드-추가)<br>
[2. MockUserManager.swift](#2-mockusermanagerswift)<br>
&ensp;[2-1. createUsers(params:completionHandler:)](#2-1-createusersparamscompletionhandler)<br>
&ensp;[2-2. getUsers(nicknameMatches:completionHandler:)](#2-2-getusersnicknamematchescompletionhandler)<br>
[3. MockNetworkClient.swift](#3-mocknetworkclientswift)<br>
&ensp;[3-1. URLRequestProvider](#3-1-urlrequestprovider)<br>
&ensp;[3-2. UserRequestType](#3-2-userrequesttype)<br>
&ensp;[3-3. UserRequest](#3-3-userrequest)<br>
&ensp;[3-4. MockNetworkClient](#3-4-mocknetworkclient)<br>
[4. Models+Codable.swift](#4-modelscodableswift)<br>
[5. TokenLeakyBucketRateLimiter.swift](#5-tokenleakybucketratelimiterswift)<br>
&ensp;[5-1. 다양한 Rate Limiting 알고리즘](#5-1-다양한-rate-limiting-알고리즘)<br>
&ensp;[5-2. LeakyBucketRateLimiter 구현](#5-2-leakybucketratelimiter-구현)<br>
&ensp;[5-3. LeakyBucketRateLimiter 고도화](#5-3-leakybucketratelimiter-고도화)<br>
[6. SendbirdError.swift](#6-sendbirderrorswift)<br>


## 1. MockUserStorage.swift
> - Platform API 응답을 in-memory cache를 통해 SDK 내에 캐싱해야 합니다
> - SDK는 스레드 안전하지 않은 방식으로 사용될 수 있습니다

위 조건을 만족하기 위해 MockUserStorage를 Thread Safe하게 구현했습니다. 캐싱 작업은 여러 스레드에서 동시에 접근할 수 있기 때문에, 데이터의 무결성과 일관성을 유지하기 위해 동기화 처리가 필요합니다.

### 1-1. Thread Safe하게 코드를 구현하는 방법
1. Serial Dispatch Queue (GCD)
- 개념: 단일 스레드에서 작업을 순차적으로 처리하여 데이터 경합 방지
- 사용 방법: DispatchQueue(label: "com.example.serialQueue")
- 장점: 구현이 간단하고 직렬화된 접근 보장
- 단점: 병렬 처리가 불가능해 읽기 작업이 많을 경우 성능 저하 발생 가능

2. Concurrent Dispatch Queue + Barrier (GCD)
- 개념: 읽기 작업은 동시 처리, 쓰기 작업은 배리어를 통해 단일 스레드 처리
- 사용 방법: DispatchQueue(label: "com.example.concurrentQueue", attributes: .concurrent)과 queue.async(flags: .barrier)
- 장점: 동시 읽기 작업의 성능을 최적화하면서도, 쓰기 작업의 안전성 보장
- 단점: 구현이 다소 복잡할 수 있음

3. NSLock
- 개념: 명시적으로 락을 사용해 여러 스레드가 자원에 접근할 때 상호 배제를 보장
- 사용 방법: let lock = NSLock()과 lock.lock(), lock.unlock()
- 장점: 직관적이고 간단한 구현
- 단점: 락 관리 실수로 인해 데드락이나 성능 저하 발생 가능

4. Actor (Swift Concurrency)
- 개념: Swift의 actor를 사용해 스레드 안전성 보장
- 사용 방법: actor MyActor { ... }
- 장점: Swift의 새로운 동시성 모델로, 간결하게 스레드 안전성 확보
- 단점: 모든 작업이 직렬로 처리되므로 동시 읽기 작업의 성능 이점을 살리지 못하며, Swift 5.5 이상에서만 사용 가능

5. Dispatch Semaphore
- 개념: 세마포어를 사용하여 제한된 수의 스레드만 자원에 접근할 수 있게 제어
- 사용 방법: let semaphore = DispatchSemaphore(value: 1)과 semaphore.wait(), semaphore.signal()
- 장점: 복잡한 동기화 시나리오에서 유연하게 사용할 수 있음
- 단점: 세마포어를 사용하여 동시 접근을 제어할 수 있지만, 세마포어는 단순히 동기화 목적이며, 동시성 작업의 이점을 살리지 못함. 모든 작업을 직렬화시키는 경향이 있어, 읽기 작업이 많은 경우 성능이 떨어질 수 있음

### 1-2. Concurrent Queue + Barrier 선택 이유
1. 동시성 및 성능 최적화
- Concurrent Queue는 다수의 스레드가 동시에 읽기 작업을 수행할 수 있어 성능을 극대화합니다.
- 특히, 읽기 작업이 빈번하고 동시 접근이 필요한 경우 성능이 크게 향상됩니다.
2. 쓰기 작업의 안전성
- Barrier를 사용해 쓰기 작업이 진행될 때 다른 읽기 또는 쓰기 작업을 차단해 데이터 일관성을 보장합니다.
- 이 방식은 읽기와 쓰기 작업이 혼재된 상황에서 안전하게 동작합니다.

### 1-3. clearAllUsers() 메서드 추가
> 만약 init의 sendbird application ID가 직전의 init에서 전달된 sendbird application ID와 다르다면 앱 내에 저장된 모든 데이터는 삭제되어야 합니다

이 요구사항을 충족하기 위해, SBUserStorage에 clearAllUsers() 메서드를 추가했습니다. 이를 통해 Application ID가 변경될 때 캐시된 데이터를 안전하게 삭제할 수 있습니다.

```swift
import Foundation
import SendbirdUserManager

class MockUserStorage: SBUserStorage {
    private let queue = DispatchQueue(label: "com.sendbird.MockUserStorage", attributes: .concurrent)
    private var userCache: [String: SBUser] = [:]
    
    func upsertUser(_ user: SBUser) {
        queue.async(flags: .barrier) {
            self.userCache[user.userId] = user
        }
    }
    
    /// 현재 저장되어있는 모든 유저를 반환합니다
    func getUsers() -> [SBUser] {
        queue.sync {
            return Array(userCache.values)
        }
    }
    
    /// 현재 저장되어있는 유저 중 nickname을 가진 유저들을 반환합니다
    func getUsers(for nickname: String) -> [SBUser] {
        queue.sync {
            return userCache.values.filter { $0.nickname == nickname }
        }
    }
    
    /// 현재 저장되어있는 유저들 중에 지정된 userId를 가진 유저를 반환합니다.
    func getUser(for userId: String) -> (SBUser)? {
        queue.sync {
            return userCache[userId]
        }
    }
    
    // 모든 데이터를 초기화하는 메서드 추가
    func clearAllUsers() {
        queue.async(flags: .barrier) {
            self.userCache.removeAll()
        }
    }
}
```

## 2. MockUserManager.swift
구현 의도의 이해를 돕기 위해, 로직이 상대적으로 복잡한 createUsers(params:completionHandler:)와 getUsers(nicknameMatches:completionHandler:) 메서드에 대한 설명을 추가로 작성했습니다.

### 2-1. createUsers(params:completionHandler:)
> - Restriction: 해당 함수를 한 번 호출하여 생성할 수 있는 사용자의 최대 수는 10명으로 제한해야 합니다. 즉, 해당 함수를 통해서 10명의 사용자를 한 번에 만들 수 있습니다. 10명을 초과하는 사용자를 생성하도록 함수가 호출되면 에러 또는 제한을 만들어주어야 합니다. 12명의 사용자를 생성하고 싶다면 10명의 생성을 먼저 요청하고 2명은 따로 요청할 수 있게 만들어야 합니다.
> - 부분적으로 User 생성이 성공한 경우에는 성공한 유저만 저장합니다
> - 부분적 성공은 실패 처리를 해야하고, 성공한 유저와 성공하지 않은 유저를 구분해주어야 합니다

1. 유저 생성 요청의 최대 허용 개수는 10개입니다. 요청된 params 배열의 개수가 10개를 초과할 경우, 즉시 에러를 반환하고 더 이상의 처리를 하지 않습니다.
2. 비동기로 실행되는 유저 생성 요청을 모두 완료할 때까지 기다리기 위해 DispatchGroup을 사용합니다. 이로 인해 모든 요청이 끝나기 전까지 콜백이 호출되지 않게 합니다.
3. 생성 요청의 순서를 보장하기 위해, users 배열을 nil로 채워서 params의 개수와 동일한 크기로 미리 생성합니다. 이후 생성된 유저는 이 배열의 동일한 인덱스에 저장됩니다.
3. params.enumerated()를 사용해 요청의 순서를 추적하고, 이를 통해 각 요청에 대응하는 유저가 생성되면 해당 인덱스에 유저를 저장합니다. 이를 통해 요청 순서를 유지합니다.
4. 모든 요청이 완료된 후, users 배열에서 nil 값을 제거하여 생성된 유저만 남긴 후, 이 유저들을 캐시에 저장합니다.
5. 요청 중 하나라도 에러가 발생했다면, 전체 작업이 실패로 간주되며, 모든 에러를 합쳐서 반환합니다. 에러가 발생하지 않았다면, 성공한 유저들을 반환합니다.

```swift
    /// UserCreationParams List를 사용하여 새로운 유저들을 생성합니다.
    /// 한 번에 생성할 수 있는 사용자의 최대 수는 10명로 제한해야 합니다
    /// Profile URL은 임의의 image URL을 사용하시면 됩니다
    /// 생성 요청이 성공한 뒤에 userStorage를 통해 캐시에 추가되어야 합니다
    /// - Parameters:
    ///    - params: User를 생성하기 위한 값들의 struct
    ///    - completionHandler: 생성이 완료된 뒤, user객체와 에러 여부를 담은 completion Handler
    func createUsers(params: [UserCreationParams], completionHandler: ((UsersResult) -> Void)?) {
        let maxUserCount = 10
        guard params.count <= maxUserCount else {
            let errorMessage = "Too many users to create. The maximum allowed number of users is \(maxUserCount), but \(params.count) were provided."
            completionHandler?(.failure(SendbirdError.validation(.tooManyUsers(errorMessage))))
            return
        }
        
        var users: [SBUser?] = Array(repeating: nil, count: params.count) // 요청 순서를 유지하기 위한 배열
        var errors: [Error] = []
        let dispatchGroup = DispatchGroup()
        
        for (index, param) in params.enumerated() {
            dispatchGroup.enter()
            do {
                let request = try UserRequest<SBUser>(
                    applicationId: applicationId,
                    apiToken: apiToken,
                    requestType: .createUser(param)
                )
                self.networkClient.request(request: request) { result in
                    switch result {
                    case .success(let user):
                        users[index] = user // 요청 순서에 맞게 결과 저장
                    case .failure(let error):
                        errors.append(error)
                    }
                    dispatchGroup.leave()
                }
            } catch {
                errors.append(error)
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            // users 배열에서 nil을 제거하고 결과 반환
            let users = users.compactMap { $0 }
            users.forEach { user in
                self.userStorage.upsertUser(user)
            }
            if errors.isEmpty {
                completionHandler?(.success(users))
            } else {
                completionHandler?(.failure(SendbirdError.network(.combined(errors))))
            }
        }
    }
```

### 2-2. getUsers(nicknameMatches:completionHandler:)
> - Nickname을 필터로 사용하여 해당 nickname을 가진 User 목록을 가져옵니다
> - GET API 호출하고 캐시에 저장합니다

1. nicknameMatches가 빈 값이거나 공백만 있는 경우, 유효하지 않은 요청으로 간주하고 에러를 반환합니다.
2. 서버로부터 응답을 성공적으로 받으면, 해당 사용자 목록을 캐시에 저장하고 결과를 호출자에게 반환합니다.
3. 만약 응답에 실패하면, 실패한 이유를 포함한 에러를 호출자에게 반환합니다.

```swift
    /// Nickname을 필터로 사용하여 해당 nickname을 가진 User 목록을 가져옵니다
    /// GET API를 호출하고 캐시에 저장합니다
    /// Get users API를 활용할 때 limit은 100으로 고정합니다
    func getUsers(nicknameMatches: String, completionHandler: ((UsersResult) -> Void)?) {
        guard !nicknameMatches.trimmingCharacters(in: .whitespaces).isEmpty else {
            completionHandler?(.failure(SendbirdError.validation(.invalidNickname("Nickname cannot be empty or consist only of whitespace."))))
            return
        }
        do {
            let request = try UserRequest<SBUsersResponse>(
                applicationId: applicationId,
                apiToken: apiToken,
                requestType: .getUserByNickname(nicknameMatches)
            )
            networkClient.request(request: request) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let success):
                    let users = success.users
                    if !users.isEmpty {
                        users.forEach { user in
                            self.userStorage.upsertUser(user)
                        }
                    }
                    completionHandler?(.success(users))
                case .failure(let failure):
                    completionHandler?(.failure(failure))
                }
            }
        } catch {
            completionHandler?(.failure(error))
        }
    }
```

## 3. MockNetworkClient.swift
### 3-1. URLRequestProvider
NetworkClient.swift에서 제공된 Request 프로토콜만으로는 다양한 API 요청을 규격화하기에 어려움이 있어, URLRequestProvider 프로토콜을 추가로 작성했습니다. 이 프로토콜을 통해 URL, HTTP 메서드, 요청 바디, 헤더 등을 설정하고, 응답 파싱 로직을 정의할 수 있습니다.
```swift
public protocol Request {
    associatedtype Response
}
```

```swift
protocol URLRequestProvider {
    var url: URL { get }
    var method: MethodType { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    func parseResponse(_ data: Data) throws -> Any
}

enum MethodType: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
}
```
URLRequestProvider 프로토콜을 통해 각 요청에 필요한 정보를 명확히 규격화할 수 있으며, 이를 통해 다양한 API 요청을 일관된 방식으로 처리할 수 있게 됩니다.

### 3-2. UserRequestType
UserRequestType을 추가해 User API를 확장성 있게 다룰 수 있도록 했습니다. 이 enum은 각 API 요청 유형을 명확히 구분하고, 필요한 정보를 효율적으로 관리할 수 있게 합니다.
그리고 case getUserById(String)으로 작성할 경우 어떤 값이 들어와야 하는지 모호할 수 있지만, typealias를 통해 case getUserById(UserID)로 명확하게 사용할 수 있도록 했습니다.

이와 같은 설계를 통해 코드의 가독성과 유지보수성을 높였습니다.
```swift
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
}
```
이 enum은 각 API 요청의 메서드 타입, 경로, 요청 바디, 쿼리 파라미터, 헤더 등을 명확히 정의하여, 다양한 요청을 하나의 구조 안에서 관리할 수 있게 해줍니다. 이를 통해 확장성과 유지보수성을 크게 개선할 수 있습니다.

### 3-3. UserRequest
UserRequest 구조체는 Request 및 URLRequestProvider 프로토콜을 채택하여, Sendbird API와의 상호작용을 위한 HTTP 요청을 구성하고 관리하는 역할을 합니다. 이 구조체는 제네릭 타입 T를 사용하여 다양한 API 응답을 처리할 수 있게 설계되었습니다.
```swift
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
    func parseResponse(_ data: Data) throws -> Any {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SendbirdError.decoding(.decodingFailure(error.localizedDescription))
        }
    }
}
```
주요 기능
1. 제네릭 타입 T 사용:
- 이 구조체는 제네릭 타입 T를 사용하여, 다양한 응답 타입을 처리할 수 있습니다. T는 Decodable 프로토콜을 채택한 타입이어야 하며, 응답 데이터를 해당 타입으로 디코딩하여 반환합니다.
2. API 요청 구성:
- UserRequestType을 사용하여 API 요청의 경로, 메서드, 바디, 헤더 등을 설정합니다. 이를 통해 다양한 User API 요청을 단일 구조체로 처리할 수 있습니다.
3. URL 생성 및 검증:
- 초기화 시 URLComponents를 사용하여 URL을 생성하고, URL이 유효하지 않으면 예외를 발생시켜 요청이 잘못된 URL로 인해 실패하지 않도록 합니다.
4. 응답 파싱:
- parseResponse 메서드를 통해 서버에서 받은 JSON 데이터를 제네릭 타입 T로 디코딩하며, 디코딩 중 발생하는 오류를 처리하여 호출자에게 전달합니다.

이 구조체는 확장성과 유지보수성을 고려하여 설계되었으며, 다양한 User API 요청을 일관된 방식으로 처리할 수 있도록 돕습니다.

### 3-4. MockNetworkClient
TokenLeakyBucketRateLimiter를 사용하여 최대 10개의 요청을 대기시키고, API 요청이 초당 1회로 제한되도록 구현했습니다. 이를 통해 요청의 효율적인 관리를 가능하게 했습니다.

또한, 모든 네트워크 요청 및 응답에 대한 상세한 로그를 출력하여 디버깅 및 모니터링에 도움을 주도록 했습니다. 요청의 URL, 메서드, 헤더, 바디 내용과 응답의 상태 코드, 헤더, 바디 내용을 로그로 남기도록 구성해 개발과 테스트 과정에서 API의 동작을 쉽게 추적할 수 있게 했습니다.

```swift
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
```

## 4. Models+Codable.swift
서버 요청에 필요한 UserCreationParams, UserUpdateParams를 json으로 변환해서 사용하기 위해 Encodable을 채택하도록 구현했습니다.
또한, 서버 응답을 객체로 변환하기 위해서 SBUser에 Decodable를 채택하게 했고 [SBUser]가 내려올 경우를 대비해 SBUsersResponse를 추가해서 손쉽게 객체로 변환할 수 있게 했습니다.

```swift
private enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case nickname = "nickname"
    case profileURL = "profile_url"
}

extension UserCreationParams: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(profileURL, forKey: .profileURL)
    }
}

extension UserUpdateParams: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(profileURL, forKey: .profileURL)
    }
}
    
extension SBUser: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userId = try container.decode(String.self, forKey: .userId)
        let nickname = try container.decode(String.self, forKey: .nickname)
        let profileURL = try container.decode(String.self, forKey: .profileURL)
        
        self.init(userId: userId, nickname: nickname, profileURL: profileURL)
    }
}

struct SBUsersResponse: Decodable {
    let users: [SBUser]
}

extension Encodable {
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] } ?? [:]
    }
}
```

## 5. TokenLeakyBucketRateLimiter.swift
> - 서버로 보내는 모든 API 요청은 1초에 1번을 초과하면 안됩니다. API rate limit이 1req/sec 보다 큰 값이라 API가 성공할 수 있더라도 SDK 에서 rate limit 제한과 에러를 만들어서 1req/sec 을 초과하지 않도록 만들어야 합니다
> - Rate limit 알고리즘은 어떤 방식을 사용해도 무방합니다
> - 외부 3rd party를 사용하여 기능을 추가해도 무방합니다
> - Partial local rate limit: 초당 1명의 user를 생성해야합니다. 절대 초당 1명 이상의 User를 생성해서는 안됩니다. 예를 들면 createUsers() request로 5개의 UserCreationParams list가 넘어왔다면 1초에 1개의 UserCreationParams를 user creation API 요청을 주어, 총 5번의 요청을 1초 간격으로 요청해야 합니다. 이때 총 소요시간은 5초 (performance에 따라 그 이상) 걸려야 합니다.

### 5-1. 다양한 Rate Limiting 알고리즘
다음은 트래픽 제어를 위한 다양한 Rate Limiting 알고리즘의 정리입니다:
1. Token Bucket (토큰 버킷)
- 원리: 일정한 시간 간격으로 버킷에 토큰이 추가. 요청이 들어올 때마다 토큰을 소비. 버킷에 토큰이 남아있지 않으면 요청을 대기시키거나 거부
- 특징: 유연한 트래픽 제어가 가능하며, 짧은 시간 동안 burst 트래픽을 허용
- 적용 예: API 요청이나 네트워크 트래픽 제어에서 자주 사용

2. Leaky Bucket (누출 버킷)
- 원리: 요청이 버킷에 쌓이고 일정한 속도로 하나씩 처리. 버킷이 가득 차면 초과하는 요청은 거부되거나 대기
- 특징: 균일한 속도로 요청을 처리하여 트래픽의 균일성을 유지. 폭발적인 트래픽을 억제
- 적용 예: 네트워크 트래픽 관리와 QoS(Quality of Service) 보장

3. Fixed Window Counter (고정 윈도우 카운터)
- 원리: 고정된 시간 윈도우 내에서 허용된 최대 요청 수를 설정. 윈도우가 끝나면 카운터가 초기화되고 새로운 요청이 허용
- 특징: 구현이 간단하며, 일정 시간 동안의 요청을 효과적으로 제한
- 적용 예: 간단한 API Rate Limiting

4. Sliding Window Log (슬라이딩 윈도우 로그)
- 원리: 모든 요청의 타임스탬프를 기록. 현재 시점을 기준으로 설정된 시간 범위 내의 요청 개수를 세어 요청을 제한
- 특징: 보다 세밀한 제어가 가능하며, 윈도우 경계 문제를 해결
- 적용 예: 정확한 요청 제한이 필요한 시스템

5. Sliding Window Counter (슬라이딩 윈도우 카운터)
- 원리: Fixed Window Counter와 비슷하지만, 시간 윈도우를 슬라이딩 방식으로 적용. 윈도우가 이동하면서 요청 개수를 지속적으로 관리
- 특징: 윈도우 경계 문제를 줄이며, 요청의 균일한 분배를 보장
- 적용 예: 보다 균등하게 트래픽을 분산해야 하는 경우

### 5-2. LeakyBucketRateLimiter 구현
과제의 조건에 가장 적합한 알고리즘으로 Leaky Bucket을 선택하여 구현했습니다. Leaky Bucket 알고리즘에 따라, 요청이 들어오면 큐에 담고, 1초 후에 실행되도록 설계했습니다.

```swift
class LeakyBucketRateLimiter {
    private let bucketCapacity: Int
    private let leakInterval: TimeInterval
    private var isProcessing: Bool = false
    private let queue = DispatchQueue(label: "com.sendbird.TokenBucketRateLimiter")
    private var requestQueue: [(Result<Void, Error>) -> Void] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("LeakyBucketRateLimiter: [\(timestamp)] \(message)")
    }

    init(bucketCapacity: Int, leakInterval: TimeInterval = 1.0) {
        self.bucketCapacity = bucketCapacity
        self.leakInterval = leakInterval
        log("Initialized with capacity: \(bucketCapacity), leak interval: \(leakInterval) seconds")
    }

    func executeRequest(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if self.requestQueue.count < self.bucketCapacity {
                self.requestQueue.append(completionHandler)
                self.log("Request added to queue. Queue size: \(self.requestQueue.count)")
                
                if !self.isProcessing {
                    self.isProcessing = true
                    self.processNextRequest()
                }
            } else {
                self.log("Bucket full. Request rejected.")
                completionHandler(.failure(SendbirdError.network(.tooManyRequests("Rate limit exceeded: Bucket capacity (\(self.bucketCapacity)) reached"))))
            }
        }
    }

    private func processNextRequest() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.requestQueue.isEmpty else {
                self.log("No more requests to process. Stopping.")
                self.isProcessing = false
                return
            }
            
            self.queue.asyncAfter(deadline: .now() + 1.0) {
                let completionHandler = self.requestQueue.removeFirst()
                completionHandler(.success(()))
                self.log("Processing request. Remaining queue size: \(self.requestQueue.count)")
                self.processNextRequest()
            }
        }
    }
}
```

그러나 1초 후에 실행하는 구조는 비효율적이라 판단하여, 요청이 들어오는 즉시 실행되도록 변경을 고려했습니다.

하지만 이러한 구조로 변경할 경우, testRateLimitCreateUser() 테스트에서 11개의 요청이 모두 큐에 담기기 전에 일부 요청이 먼저 처리되어, 모든 요청이 큐에 담기지 못해 실패할 수 있습니다. 이 문제를 해결하기 위해, Token Bucket의 토큰 개념을 도입하여 사용했고, 정확히 1초마다 실행되도록 고도화했습니다.

### 5-3. LeakyBucketRateLimiter 고도화
다음과 같이 고도화해서 TokenLeakyBucketRateLimiter로 클래스명을 수정했습니다.
1. 모든 요청을 즉시 큐에 추가합니다.
2. 첫 번째 요청은 즉시 처리합니다(0초에 시작).
3. 이후의 요청들은 정확히 1초(leakInterval) 간격으로 큐에서 꺼내어 처리합니다.

```swift
class TokenLeakyBucketRateLimiter {
    private let bucketCapacity: Int
    private let leakInterval: TimeInterval
    private var availableTokens: Int
    private var lastRefillTime: Date
    private var isProcessing: Bool = false
    private let queue = DispatchQueue(label: "com.sendbird.TokenBucketRateLimiter")
    private var requestQueue: [(Result<Void, Error>) -> Void] = []
    private var timer: DispatchSourceTimer?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("LeakyBucketRateLimiter: [\(timestamp)] \(message)")
    }

    init(bucketCapacity: Int, leakInterval: TimeInterval = 1.0) {
        self.bucketCapacity = bucketCapacity
        self.leakInterval = leakInterval
        self.availableTokens = bucketCapacity
        self.lastRefillTime = Date()
        log("Initialized with capacity: \(bucketCapacity), leak interval: \(leakInterval) seconds")
    }
    
    deinit {
        stopTimer()
    }
    
    func executeRequest(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            refillTokens()
            
            if self.availableTokens > 0 {
                self.availableTokens -= 1
                self.requestQueue.append((completionHandler))
                self.log("Token consumed. Available tokens: \(self.availableTokens)")
                
                if !self.isProcessing {
                    self.startProcessing()
                }
            } else {
                self.log("Bucket full. Request rejected. (max \(self.bucketCapacity) reached)")
                completionHandler(.failure(SendbirdError.network(.tooManyRequests("Rate limit exceeded: Bucket capacity (\(self.bucketCapacity)) reached"))))
            }
        }
    }
    
    private func refillTokens() {
        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = Int(timeElapsed)
        if tokensToAdd > 0 {
            availableTokens = min(bucketCapacity, availableTokens + tokensToAdd)
            lastRefillTime = now
            log("Tokens refilled. Available tokens: \(availableTokens)")
        }
    }
    
    private func startProcessing() {
        isProcessing = true
        processNextRequest() // 첫 번째 요청 즉시 처리
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + leakInterval, repeating: leakInterval)
        timer?.setEventHandler { [weak self] in
            self?.processNextRequest()
        }
        timer?.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func processNextRequest() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.requestQueue.isEmpty else {
                self.handleEmptyQueue()
                return
            }
            
            let completionHandler = self.requestQueue.removeFirst()
            self.log("Processing request. Remaining queue size: \(requestQueue.count)")
            completionHandler(.success(()))
            
            // 요청 처리 후 큐가 비었는지 다시 확인
            if self.requestQueue.isEmpty {
                self.handleEmptyQueue()
            }
        }
    }
    
    private func handleEmptyQueue() {
        log("No more requests to process. Stopping.")
        isProcessing = false
        stopTimer()
    }
}
```

## 6. SendbirdError.swift
Sendbird SDK에서 발생할 수 있는 다양한 오류를 정의하고 관리합니다.
```swift
enum SendbirdError: Error {
    case request(RequestError) // 요청 생성 및 처리와 관련된 오류
    case network(NetworkError) // 네트워크 통신과 관련된 오류
    case validation(ValidationError) // 입력 값 검증과 관련된 오류
    case decoding(DecodingError) // 데이터 디코딩과 관련된 오류
    case unknown(String) // 알 수 없는 오류

    // 세부 오류 유형 정의
    enum RequestError: Error {
        case createFailure(String) // 요청 생성 실패 오류
        case invalidRequest(String) // 잘못된 요청 오류
    }

    enum NetworkError: Error {
        case invalidResponse(String) // 유효하지 않은 응답 오류
        case invalidStatusCode(Int) // 유효하지 않은 상태 코드 오류
        case invalidData(String) // 유효하지 않은 데이터 오류
        case tooManyRequests(String) // 너무 많은 요청 오류
        case combined([Error]) // 여러 네트워크 오류를 결합한 오류
    }

    enum ValidationError: Error {
        case tooManyUsers(String) // 한번에 최대 생성 가능한 사용자 수 초과 오류
        case invalidNickname(String) // 유효하지 않은 닉네임 오류
    }

    enum DecodingError: Error {
        case decodingFailure(String) // 데이터 디코딩 실패 오류
    }
}
```

감사합니다.