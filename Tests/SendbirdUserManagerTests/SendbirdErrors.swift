//
//  SendbirdErrors.swift
//
//
//  Created by TAE SU LEE on 8/8/24.
//

import Foundation

enum SendbirdError: Error {
    case request(RequestError)
    case response(ResponseError)
    case network(NetworkError)
    case validation(ValidationError)
    case decoding(DecodingError)
    case unknown(String)
    
    enum RequestError: Error {
        case createFailure(String)
        case invalidRequest(String)
    }
    
    enum ResponseError: Error {
        case empty(String)
    }
    
    enum NetworkError: Error {
        case invalidResponse(String)
        case invalidStatusCode(Int)
        case invalidData(String)
        case tooManyRequests(String)
        case combined([Error])
    }
    
    enum ValidationError: Error {
        case tooManyUsers(String)
        case invalidNickname(String)
    }
    
    enum DecodingError: Error {
        case decodingFailure(String)
    }
}
