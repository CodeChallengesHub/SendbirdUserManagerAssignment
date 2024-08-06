//
//  MockNetworkClient.swift
//
//
//  Created by TAE SU LEE on 8/6/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation
import SendbirdUserManager

class MockNetworkClient: SBNetworkClient {
    func request<R: Request>(
        request: R,
        completionHandler: @escaping (Result<R.Response, Error>) -> Void
    ) {
        
    }
}
