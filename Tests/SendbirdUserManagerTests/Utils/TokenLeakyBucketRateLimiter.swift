//
//  TokenLeakyBucketRateLimiter.swift
//
//
//  Created by TAE SU LEE on 8/9/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation

/**
 `TokenLeakyBucketRateLimiter`는 Leaky Bucket과 Token Bucket 개념을 결합한 요청 속도 제한기(Rate Limiter)입니다.
 이 클래스는 과제의 조건에 가장 적합한 Leaky Bucket 알고리즘을 기반으로 하며,
 Token Bucket의 토큰 개념을 도입하여 효율성과 정확성을 개선했습니다.

 주요 특징 및 구현 과정:
 - 초기에는 Leaky Bucket 알고리즘에 따라 요청을 큐에 담고 1초(leakInterval) 후 실행하도록 구현했습니다.
 - 효율성 개선을 위해 구현을 수정하여 다음과 같이 동작하도록 했습니다:
   1. 모든 요청을 즉시 큐에 추가합니다.
   2. 첫 번째 요청은 즉시 처리합니다(0초에 시작).
   3. 이후의 요청들은 정확히 1초(leakInterval) 간격으로 큐에서 꺼내어 처리합니다.
 - 이 방식은 초당 처리 요청 수를 정확히 제한하면서도, 첫 요청에 대해 즉각적인 응답을 제공합니다.
 - Token 개념을 사용하여 요청 처리 가능 여부를 관리합니다.
 - 버킷의 용량(최대 토큰 수)과 토큰 추가 간격을 설정할 수 있어 유연한 속도 제한이 가능합니다.
 */
class TokenLeakyBucketRateLimiter {
    private let bucketCapacity: Int
    private let leakInterval: TimeInterval
    private var availableTokens: Int
    private var lastRefillTime: Date
    private var isProcessing: Bool = false
    private let queue = DispatchQueue(label: "com.sendbird.TokenBucketRateLimiter")
    private var requestQueue: [(Result<Void, Error>) -> Void] = []
    private var timer: DispatchSourceTimer?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("LeakyBucketRateLimiter: [\(timestamp)] \(message)")
    }

    init(bucketCapacity: Int, leakInterval: TimeInterval = 1.0) {
        self.bucketCapacity = bucketCapacity
        self.leakInterval = leakInterval
        self.availableTokens = bucketCapacity
        self.lastRefillTime = Date()
        log("Initialized with capacity: \(bucketCapacity), leak interval: \(leakInterval) seconds")
    }
    
    deinit {
        stopTimer()
    }
    
    func executeRequest(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            refillTokens()
            
            if self.availableTokens > 0 {
                self.availableTokens -= 1
                self.requestQueue.append((completionHandler))
                self.log("Token consumed. Available tokens: \(self.availableTokens)")
                
                if !self.isProcessing {
                    self.startProcessing()
                }
            } else {
                self.log("Bucket full. Request rejected. (max \(self.bucketCapacity) reached)")
                completionHandler(.failure(SendbirdError.network(.tooManyRequests("Rate limit exceeded: Bucket capacity (\(self.bucketCapacity)) reached"))))
            }
        }
    }
    
    private func refillTokens() {
        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = Int(timeElapsed / leakInterval)
        if tokensToAdd > 0 {
            availableTokens = min(bucketCapacity, availableTokens + tokensToAdd)
            lastRefillTime = now
            log("Tokens refilled. Available tokens: \(availableTokens)")
        }
    }
    
    private func startProcessing() {
        isProcessing = true
        processNextRequest() // 첫 번째 요청 즉시 처리
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now() + leakInterval, repeating: leakInterval)
        timer?.setEventHandler { [weak self] in
            self?.processNextRequest()
        }
        timer?.resume()
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    private func processNextRequest() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.requestQueue.isEmpty else {
                self.handleEmptyQueue()
                return
            }
            
            let completionHandler = self.requestQueue.removeFirst()
            self.log("Processing request. Remaining queue size: \(requestQueue.count)")
            completionHandler(.success(()))
            
            // 요청 처리 후 큐가 비었는지 다시 확인
            if self.requestQueue.isEmpty {
                self.handleEmptyQueue()
            }
        }
    }
    
    private func handleEmptyQueue() {
        log("No more requests to process. Stopping.")
        isProcessing = false
        stopTimer()
    }
}
