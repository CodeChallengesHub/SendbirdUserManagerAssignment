//
//  Models+Codable.swift
//
//
//  Created by TAE SU LEE on 8/8/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

/**
 Models+Codable.swift
 
 이 파일은 서버 요청에 필요한 모델들을 Codable로 변환하여 JSON 인코딩 및 디코딩 작업을 수행할 수 있도록 설계되었습니다.
 이를 통해 서버와의 통신 시 데이터 변환 작업이 간편해지고, 코드의 가독성과 유지보수성이 향상됩니다.
 
 주요 구성 요소:
 - CodingKeys: JSON의 키와 모델의 프로퍼티를 매핑하기 위해 사용됩니다.
 - UserCreationParams & UserUpdateParams: 서버 요청에 필요한 데이터를 JSON 형태로 인코딩합니다.
 - SBUser: 서버 응답을 객체로 변환하기 위해 JSON 데이터를 디코딩합니다.
 - SBUsersResponse: [SBUser]와 같은 배열 형태의 응답을 처리하기 위해 사용됩니다.
 - Encodable extension: 모든 Encodable 객체를 딕셔너리로 변환할 수 있는 편의 메서드를 제공합니다.
 */

/// JSON의 키와 모델의 프로퍼티를 매핑하기 위해 사용됩니다.
private enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case nickname = "nickname"
    case profileURL = "profile_url"
}

/// Encodable을 채택하여 JJSON 인코딩이 가능하도록 설계했습니다.
extension UserCreationParams: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(profileURL, forKey: .profileURL)
    }
}

/// Encodable을 채택하여 JJSON 인코딩이 가능하도록 설계했습니다.
extension UserUpdateParams: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(profileURL, forKey: .profileURL)
    }
}

/// Decodable을 채택하여 JSON 데이터를 쉽게 객체로 변환할 수 있게 했습니다.
extension SBUser: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userId = try container.decode(String.self, forKey: .userId)
        let nickname = try container.decode(String.self, forKey: .nickname)
        let profileURL = try container.decode(String.self, forKey: .profileURL)
        
        self.init(userId: userId, nickname: nickname, profileURL: profileURL)
    }
}


/**
 `SBUsersResponse` 구조체는 `[SBUser]`와 같은 배열 형태의 응답을 처리하기 위해 설계되었습니다.
 */
struct SBUsersResponse: Decodable {
    let users: [SBUser]
}

/**
 `Encodable` 프로토콜을 채택한 모든 객체를 딕셔너리 형태로 변환하기 위한 확장입니다.
 이 메서드는 JSON 인코딩 후 이를 딕셔너리로 변환하여 반환합니다.
 */
extension Encodable {
    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] } ?? [:]
    }
}
