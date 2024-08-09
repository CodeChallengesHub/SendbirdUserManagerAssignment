//
//  MockUserManager.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

class MockUserManager: SBUserManager {
    let networkClient: SBNetworkClient
    let userStorage: SBUserStorage
    
    private var applicationId: String = ""
    private var apiToken: String = ""
    
    init(networkClient: SBNetworkClient, userStorage: SBUserStorage) {
        self.networkClient = networkClient
        self.userStorage = userStorage
    }
    
    /// Sendbird Application ID 및 API Token을 사용하여 SDK을 초기화합니다
    /// Init은 앱이 launching 될 때마다 불러야 합니다
    /// 만약 init의 sendbird application ID가 직전의 init에서 전달된 sendbird application ID와 다르다면 앱 내에 저장된 모든 데이터는 삭제되어야 합니다
    /// - Parameters:
    ///    - applicationId: Sendbird의 Application ID
    ///    - apiToken: 해당 Application에서 발급된 API Token
    func initApplication(applicationId: String, apiToken: String) {
        self.applicationId = applicationId
        self.apiToken = apiToken
    }
    
    /// UserCreationParams를 사용하여 새로운 유저를 생성합니다.
    /// Profile URL은 임의의 image URL을 사용하시면 됩니다
    /// 생성 요청이 성공한 뒤에 userStorage를 통해 캐시에 추가되어야 합니다
    /// - Parameters:
    ///    - params: User를 생성하기 위한 값들의 struct
    ///    - completionHandler: 생성이 완료된 뒤, user객체와 에러 여부를 담은 completion Handler
    func createUser(params: UserCreationParams, completionHandler: ((UserResult) -> Void)?) {
        do {
            let request = try UserRequest<SBUser>(
                applicationId: applicationId,
                apiToken: apiToken,
                requestType: .createUser(params)
            )
            networkClient.request(request: request) { result in
                completionHandler?(result)
            }
        } catch {
            completionHandler?(.failure(error))
        }
    }
    
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
        
        dispatchGroup.notify(queue: .main) {
            if errors.isEmpty {
                // users 배열에서 nil을 제거하고 결과 반환
                completionHandler?(.success(users.compactMap { $0 }))
            } else {
                completionHandler?(.failure(SendbirdError.network(.combined(errors))))
            }
        }
    }
    
    /// 특정 User의 nickname 또는 profileURL을 업데이트합니다
    /// 업데이트 요청이 성공한 뒤에 캐시에 upsert 되어야 합니다
    func updateUser(params: UserUpdateParams, completionHandler: ((UserResult) -> Void)?) {
        do {
            let request = try UserRequest<SBUser>(
                applicationId: applicationId,
                apiToken: apiToken,
                requestType: .updateUser(params.userId, params)
            )
            
            networkClient.request(request: request) { result in
                completionHandler?(result)
            }
        } catch {
            completionHandler?(.failure(error))
        }
    }
    
    /// userId를 통해 특정 User의 정보를 가져옵니다
    /// 캐시에 해당 User가 있으면 캐시된 User를 반환합니다
    /// 캐시에 해당 User가 없으면 /GET API 호출하고 캐시에 저장합니다
    func getUser(userId: String, completionHandler: ((UserResult) -> Void)?) {
        do {
            let request = try UserRequest<SBUser>(
                applicationId: applicationId,
                apiToken: apiToken,
                requestType: .getUserById(userId)
            )
            networkClient.request(request: request) { result in
                completionHandler?(result)
            }
        } catch {
            completionHandler?(.failure(error))
        }
    }
    
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
            networkClient.request(request: request) { result in
                switch result {
                case .success(let success):
                    if !success.users.isEmpty {
                        completionHandler?(.success(success.users))
                    } else {
                        completionHandler?(.failure(SendbirdError.response(.empty("No users found matching the provided nickname."))))
                    }
                case .failure(let failure):
                    completionHandler?(.failure(failure))
                }
            }
        } catch {
            completionHandler?(.failure(error))
        }
    }
}
