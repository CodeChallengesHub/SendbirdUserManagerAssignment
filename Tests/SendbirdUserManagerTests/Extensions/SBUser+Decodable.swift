//
//  File.swift
//  
//
//  Created by TAE SU LEE on 8/8/24.
//

import Foundation
import SendbirdUserManager

extension SBUser: Decodable {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case nickname = "nickname"
        case profileURL = "profile_url"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userId = try container.decode(String.self, forKey: .userId)
        let nickname = try container.decode(String.self, forKey: .nickname)
        let profileURL = try container.decode(String.self, forKey: .profileURL)
        
        self.init(userId: userId, nickname: nickname, profileURL: profileURL)
    }
}
