//
//  MockUserStorage.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

/**
 `MockUserStorage` 클래스는 Sendbird SDK에서 사용자 데이터를 캐싱하고, 스레드 안전성을 보장하기 위해 설계되었습니다.
 
 이 클래스는 사용자 데이터에 대한 CRUD 작업을 제공하며, 내부적으로 `concurrent` 큐와 `barrier`를 사용하여 성능과 데이터 일관성을 동시에 유지합니다.
 
 - 중요한 설계 결정:
   - `concurrent` 큐와 `barrier`를 사용하여, 읽기 작업은 동시에 수행할 수 있게 하고, 쓰기 작업은 안전하게 처리합니다.
   - `clearAllUsers()` 메서드를 통해, 애플리케이션 ID가 변경될 때 모든 캐시 데이터를 제거할 수 있습니다.
 
 이 클래스는 SBUserStorage 프로토콜을 준수하며, 스레드 안전한 방식으로 사용자 데이터를 관리합니다.
 */
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
