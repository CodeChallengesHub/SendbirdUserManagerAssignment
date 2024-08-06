//
//  Models.swift
//  
//
//  Created by Sendbird
//

import Foundation

/// User를 생성할때 사용되는 parameter입니다.
/// - Parameters:
///   - userId: 생성될 user id
///   - nickname: 해당 user의 nickname
///   - profileURL: 해당 user의 profile로 사용될 image url
public struct UserCreationParams {
    public let userId: String
    public let nickname: String
    public let profileURL: String?
}

/// User를 update할때 사용되는 parameter입니다.
/// - Parameters:
///   - userId: 업데이트할 User의 ID
///   - nickname: 새로운 nickname
///   - profileURL: 새로운 image url
public struct UserUpdateParams {
    public let userId: String
    public let nickname: String?
    public let profileURL: String?
}

/// Sendbird의 User를 나타내는 객체입니다
public struct SBUser {
    public init(userId: String, nickname: String? = nil, profileURL: String? = nil) {
        self.userId = userId
        self.nickname = nickname
        self.profileURL = profileURL
    }

    public var userId: String
    public var nickname: String?
    public var profileURL: String?
}
