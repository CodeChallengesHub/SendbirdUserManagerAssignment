//
//  SendbirdErrors.swift
//
//
//  Created by TAE SU LEE on 8/8/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation

/**
 `SendbirdError` 열거형은 Sendbird SDK에서 발생할 수 있는 다양한 오류를 정의하고 관리합니다.

 이 열거형은 네 가지 주요 오류 카테고리로 나뉘며, 각각의 카테고리에서 세부적인 오류 유형을 정의합니다.

 - `request`: 요청 생성 및 처리와 관련된 오류를 나타냅니다.
 - `network`: 네트워크 통신과 관련된 오류를 나타냅니다.
 - `validation`: 입력 값 검증과 관련된 오류를 나타냅니다.
 - `decoding`: 서버 응답 데이터를 디코딩하는 과정에서 발생하는 오류를 나타냅니다.
 - `unknown`: 알 수 없는 오류나 특정 카테고리에 속하지 않는 오류를 나타냅니다.
 */
enum SendbirdError: Error {
    case request(RequestError) // 요청 생성 및 처리와 관련된 오류
    case network(NetworkError) // 네트워크 통신과 관련된 오류
    case validation(ValidationError) // 입력 값 검증과 관련된 오류
    case decoding(DecodingError) // 데이터 디코딩과 관련된 오류
    case unknown(String) // 알 수 없는 오류

    // 세부 오류 유형 정의
    enum RequestError: Error {
        case createFailure(String) // 요청 생성 실패 오류
        case invalidRequest(String) // 잘못된 요청 오류
    }

    enum NetworkError: Error {
        case invalidResponse(String) // 유효하지 않은 응답 오류
        case invalidStatusCode(Int) // 유효하지 않은 상태 코드 오류
        case invalidData(String) // 유효하지 않은 데이터 오류
        case tooManyRequests(String) // 너무 많은 요청 오류
        case combined([Error]) // 여러 네트워크 오류를 결합한 오류
    }

    enum ValidationError: Error {
        case tooManyUsers(String) // 한번에 최대 생성 가능한 사용자 수 초과 오류
        case invalidNickname(String) // 유효하지 않은 닉네임 오류
    }

    enum DecodingError: Error {
        case decodingFailure(String) // 데이터 디코딩 실패 오류
    }
}
