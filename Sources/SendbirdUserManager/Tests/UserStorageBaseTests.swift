//
//  UserStorageBaseTests.swift
//  SendbirdUserManager
//
//  Created by Sendbird
//

import Foundation
import XCTest

/// Unit Testing을 위해 제공되는 base test suite입니다.
/// 사용을 위해서는 해당 클래스를 상속받고,
/// `open func userStorage() -> SBUserStorage?`를 override한뒤, 본인이 구현한 SBUserStorage의 인스턴스를 반환하도록 합니다.
open class UserStorageBaseTests: XCTestCase {
    open func userStorage() -> SBUserStorage? { nil }
    
    public func testSetUser() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        storage.upsertUser(user)
        
        XCTAssert(storage.getUser(for: "1")?.userId == "1")
        XCTAssert(storage.getUsers().first?.userId == "1")
    }
    
    
    public func testSetAndGetUser() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        storage.upsertUser(user)
        
        let retrievedUser = storage.getUser(for: user.userId)
        XCTAssertEqual(user.nickname, retrievedUser?.nickname)
    }
    
    public func testGetAllUsers() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let users = [SBUser(userId: "1"), SBUser(userId: "2")]
        
        for user in users {
            storage.upsertUser(user)
        }
        
        let retrievedUsers = storage.getUsers()
        XCTAssertEqual(users.count, retrievedUsers.count)
    }
    
    public func testThreadSafety() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        
        let expectation = self.expectation(description: "Updating storage from multiple threads")
        expectation.expectedFulfillmentCount = 2
        
        let queue1 = DispatchQueue(label: "com.test.queue1")
        let queue2 = DispatchQueue(label: "com.test.queue2")
        
        queue1.async {
            for _ in 0..<1000 {
                storage.upsertUser(user)
            }
            expectation.fulfill()
        }
        
        queue2.async {
            for _ in 0..<1000 {
                _ = storage.getUser(for: user.userId)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    public func testConcurrentWrites() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let expectation = self.expectation(description: "Concurrent writes")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let user = SBUser(userId: "\(i)")
                storage.upsertUser(user)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    public func testConcurrentReads() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        storage.upsertUser(user)
        
        let expectation = self.expectation(description: "Concurrent reads")
        expectation.expectedFulfillmentCount = 10
        
        for _ in 0..<10 {
            DispatchQueue.global().async {
                _ = storage.getUser(for: user.userId)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    public func testMixedReadsAndWrites() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let expectation = self.expectation(description: "Mixed reads and writes")
        expectation.expectedFulfillmentCount = 20
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let user = SBUser(userId: "\(i)")
                storage.upsertUser(user)
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                _ = storage.getUser(for: "\(i)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    public func testPerformanceOfSetUser() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        
        measure {
            for _ in 0..<1_000 {
                storage.upsertUser(user)
            }
        }
    }
    
    public func testPerformanceOfGetUser() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        storage.upsertUser(user)
        
        measure {
            for _ in 0..<1_000 {
                _ = storage.getUser(for: user.userId)
            }
        }
    }
    
    public func testPerformanceOfGetAllUsers() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        for i in 0..<1_000 {
            let user = SBUser(userId: "\(i)")
            storage.upsertUser(user)
        }
        
        measure {
            _ = storage.getUsers()
        }
    }

    
    public func testStress() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let user = SBUser(userId: "1")
        
        for _ in 0..<10_000 {
            storage.upsertUser(user)
            _ = storage.getUser(for: user.userId)
        }
    }
    
    public func testInterleavedSetAndGet() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let expectation = self.expectation(description: "Interleaved set and get")
        expectation.expectedFulfillmentCount = 20
        
        for i in 0..<10 {
            let user = SBUser(userId: "\(i)")
            
            DispatchQueue.global().async {
                storage.upsertUser(user)
                expectation.fulfill()
            }
            
            DispatchQueue.global().async {
                // Here we will wait for a brief moment to let the setUser operation potentially finish.
                // In real scenarios, this delay might not guarantee the order of operations, but for testing purposes it's useful.
                usleep(1000)
                
                let retrievedUser = storage.getUser(for: "\(i)")
                XCTAssertEqual(user.userId, retrievedUser?.userId)
                XCTAssertEqual(user.nickname, retrievedUser?.nickname)
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    public func testBulkSetsAndSingleGet() throws {
        let storage = try XCTUnwrap(self.userStorage())
        
        let setExpectation = self.expectation(description: "Bulk sets")
        setExpectation.expectedFulfillmentCount = 10
        
        let users: [SBUser] = (0..<10).map { SBUser(userId: "\($0)") }
        
        for user in users {
            DispatchQueue.global().async {
                storage.upsertUser(user)
                setExpectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        
        // Now that all set operations have been fulfilled, we retrieve them on a different thread
        DispatchQueue.global().async {
            let retrievedUsers = storage.getUsers()
            
            XCTAssertEqual(users.count, retrievedUsers.count)
            
            for user in users {
                XCTAssertTrue(retrievedUsers.contains(where: { $0.userId == user.userId && $0.nickname == user.nickname }) )
            }
        }
    }
}
