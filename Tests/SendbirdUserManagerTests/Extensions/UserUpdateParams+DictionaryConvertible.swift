//
//  UserUpdateParams+DictionaryConvertible.swift
//
//
//  Created by TAE SU LEE on 8/7/24.
//

import Foundation
import SendbirdUserManager

extension UserUpdateParams {
    func toDictionary() -> [String: Any] {
        let dict: [String: Any] = [
            "user_id": userId,
            "nickname": nickname as Any,
            "profile_url": profileURL as Any
        ]
        return dict
    }
}
