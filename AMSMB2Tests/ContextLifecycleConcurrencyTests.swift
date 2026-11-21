//
//  ContextLifecycleConcurrencyTests.swift
//  AMSMB2Tests
//
//  libsmb2 links every context into one process-wide list (`active_contexts` in init.c):
//  `smb2_init_context` adds to it and `smb2_destroy_context` removes from it, unlocked. Clients
//  created and released on different threads at the same time corrupt that list, and a later
//  remove walks a dangling pointer — EXC_BAD_ACCESS at `SMB2_LIST_REMOVE` inside
//  `smb2_destroy_context` (BTR AMP Crashlytics 7dbde209, v22.3).
//

import XCTest
@testable import AMSMB2

final class ContextLifecycleConcurrencyTests: XCTestCase {
    /// No server is involved: `SMB2Client()` only initializes a context, and releasing it destroys
    /// the context in `deinit`, which is exactly the list traffic that raced in production.
    func testConcurrentContextCreateAndDestroyDoesNotCorruptTheContextList() throws {
        let iterations = 20_000
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            var clients: [SMB2Client] = []
            for _ in 0..<(1 + index % 3) {
                if let client = try? SMB2Client() {
                    clients.append(client)
                }
            }
            //--- release in a different order than creation so removals hit the middle of the list
            clients.reverse()
            clients.removeAll()
        }
    }
}
