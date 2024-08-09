//
//  TokenBucketRateLimiter.swift
//
//
//  Created by TAE SU LEE on 8/9/24.
//  Copyright © 2024 https://github.com/tsleedev/. All rights reserved.
//

import Foundation

class TokenBucketRateLimiter {
    private let maxTokens: Int
    private var availableTokens: Int
    private var isProcessing: Bool = false
    private let queue = DispatchQueue(label: "com.sendbird.TokenBucketRateLimiter")
    private var requestQueue: [(Result<Void, Error>) -> Void] = []
    private var lastRequestTime: Date?
    private var lastRefillTime: Date

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        print("TokenBucketRateLimiter: [\(timestamp)] \(message)")
    }

    init(maxTokens: Int) {
        self.maxTokens = maxTokens
        self.availableTokens = maxTokens
        self.lastRefillTime = Date()
        log("initialized with max tokens: \(maxTokens)")
    }

    func executeRequest(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.refillTokens()
            
            if self.availableTokens > 0 {
                self.availableTokens -= 1
                self.requestQueue.append((completionHandler))
                self.log("Token consumed. Available tokens: \(self.availableTokens)")
                
                if !self.isProcessing {
                    self.isProcessing = true
                    self.processNextRequest()
                }
            } else {
                self.log("No tokens available. (max \(self.maxTokens) consumed)")
                completionHandler(.failure(SendbirdError.network(.tooManyRequests("Rate limit exceeded: Max \(self.maxTokens) requests"))))
            }
        }
    }
    
    private func refillTokens() {
        let now = Date()
        let timeElapsed = now.timeIntervalSince(lastRefillTime)
        let tokensToAdd = Int(timeElapsed)
        if tokensToAdd > 0 {
            availableTokens = min(maxTokens, availableTokens + tokensToAdd)
            lastRefillTime = now
            log("Tokens refilled. Available tokens: \(availableTokens)")
        }
    }

    private func processNextRequest() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard !self.requestQueue.isEmpty else {
                self.log("No more requests to process. Stopping.")
                self.isProcessing = false
                return
            }
            
            let now = Date()
            if let lastRequest = self.lastRequestTime, now.timeIntervalSince(lastRequest) < 1.0 {
                let delay = 1.0 - now.timeIntervalSince(lastRequest)
                self.log("Waiting for \(delay) seconds before processing next request")
                self.queue.asyncAfter(deadline: .now() + delay) {
                    self.executeNextRequest()
                }
            } else {
                self.executeNextRequest()
            }
        }
    }

    private func executeNextRequest() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let completionHandler = self.requestQueue.first else {
                self.log("No request to execute. Stopping.")
                self.isProcessing = false
                return
            }
            
            self.requestQueue.removeFirst()
            self.lastRequestTime = Date()
            completionHandler(.success(()))
            
            self.queue.asyncAfter(deadline: .now() + 1.0) {
                self.processNextRequest()
            }
        }
    }
}
