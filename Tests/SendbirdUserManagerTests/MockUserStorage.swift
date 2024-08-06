//
//  MockUserStorage.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

class MockUserStorage: SBUserStorage {
    func upsertUser(_ user: SBUser) {
        
    }
    
    /// 현재 저장되어있는 모든 유저를 반환합니다
    func getUsers() -> [SBUser] {
        return []
    }
    
    /// 현재 저장되어있는 유저 중 nickname을 가진 유저들을 반환합니다
    func getUsers(for nickname: String) -> [SBUser] {
        return []
    }
    
    /// 현재 저장되어있는 유저들 중에 지정된 userId를 가진 유저를 반환합니다.
    func getUser(for userId: String) -> (SBUser)? {
        return nil
    }
}
