//
//  StringExtensionTests.swift
//  StringExtensionTests
//
//  Created by Mieraidihaimu Mieraisan on 12/07/2023.
//

import XCTest
@testable import TypingPall

class StringExtensionTests: XCTestCase {

    func testExtractMismatchedRange_WhenStringsAreIdentical() {
        // Given: Two identical strings
        let stringA = "Hello, World!"
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringAIsLonger() {
        // Given: String A is longer than String B
        let stringA = "Hello, World!"
        let stringB = "Hello"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be the range of the extra characters in String A
        XCTAssertEqual(range, NSRange(location: 5, length: 13 - 5))
    }

    func testExtractMismatchedRange_WhenStringBIsLonger() {
        // Given: String B is longer than String A
        let stringA = "Hello"
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringsHaveDifferentCharacters() {
        // Given: Two strings with different characters
        let stringA = "Hello, World!"
        let stringB = "Hello, Swift!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be the range of the different characters in String A
        XCTAssertEqual(range, NSRange(location: 7, length: 13 - 7))
    }

    func testExtractMismatchedRange_WhenStringAIsEmpty() {
        // Given: String A is empty
        let stringA = ""
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringBIsEmpty() {
        // Given: String B is empty
        let stringA = "Hello, World!"
        let stringB = ""

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result all string A is mismatched
        XCTAssertEqual(range, NSRange(location: 0, length: 13))
    }

    func testExtractMismatchedRange_WhenStringBIsTotallyMismatch() {
        // Given: String B is empty
        let stringA = "Hello, World!"
        let stringB = "WFDSFDHSJ"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result all string A is mismatched compare to String B
        XCTAssertEqual(range, NSRange(location: 0, length: 13))
    }
}

