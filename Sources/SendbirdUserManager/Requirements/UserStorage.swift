//
//  UserStorage.swift
//  
//
//  Created by Sendbird
//

import Foundation

/// Sendbird User 를 관리하기 위한 storage class입니다
public protocol SBUserStorage {
    /// 해당 User를 저장 또는 업데이트합니다
    func upsertUser(_ user: SBUser)
    
    /// 현재 저장되어있는 모든 유저를 반환합니다
    func getUsers() -> [SBUser]
    /// 현재 저장되어있는 유저 중 nickname을 가진 유저들을 반환합니다
    func getUsers(for nickname: String) -> [SBUser]
    /// 현재 저장되어있는 유저들 중에 지정된 userId를 가진 유저를 반환합니다.
    func getUser(for userId: String) -> (SBUser)?
}
