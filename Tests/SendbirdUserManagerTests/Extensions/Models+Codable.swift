//
//  Models+Codable.swift
//
//
//  Created by TAE SU LEE on 8/8/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

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
