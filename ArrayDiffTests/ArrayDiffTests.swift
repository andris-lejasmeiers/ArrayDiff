//
//  ArrayDiffTests.swift
//  ArrayDiffTests
//
//  Created by Adlai Holler on 10/1/15.
//  Copyright © 2015 Adlai Holler. All rights reserved.
//

import XCTest
@testable import ArrayDiff

class ArrayDiffTests: XCTestCase {
	
    func testACommonCase() {
		let old = "a b c d e".components(separatedBy: " ")
		let new = "m a b f".components(separatedBy: " ")
		
		let allFirstIndexes = IndexSet(integersIn: NSMakeRange(0, old.count).toRange()!)
		
        var expectedRemoves = IndexSet()
        expectedRemoves.insert(integersIn: 2..<2+3)

        var expectedInserts = IndexSet()
        expectedInserts.insert(0)
        expectedInserts.insert(3)
		

		let expectedCommonObjects = "a b".components(separatedBy: " ")

		let diff = old.diff(new)
		
		XCTAssertEqual(expectedInserts, diff.insertedIndexes)
		XCTAssertEqual(expectedRemoves, diff.removedIndexes)
		XCTAssertEqual(expectedCommonObjects, old[diff.commonIndexes])
		
        var removedPlusCommon = IndexSet(diff.removedIndexes)
        removedPlusCommon.formUnion(diff.commonIndexes)
        XCTAssertEqual(removedPlusCommon, allFirstIndexes)
		
		var reconstructed = old
		reconstructed.removeAtIndexes(diff.removedIndexes)
		reconstructed.insertElements(new[diff.insertedIndexes], atIndexes: diff.insertedIndexes)
		XCTAssertEqual(reconstructed, new)
    }
	
	func testNewIndexForOldIndex() {
		let old = "a b c d e".components(separatedBy: " ")
		let new = "m a b f".components(separatedBy: " ")
		let diff = old.diff(new)
		let newIndexes: [Int?] = (0..<old.count).map { diff.newIndexForOldIndex($0) }
		let expectedNewIndexes: [Int?] = [1, 2, nil, nil, nil]
        XCTAssert(newIndexes.elementsEqual(expectedNewIndexes, by: { $0 == $1 }), "Expected newIndexes to be \(expectedNewIndexes), got \(newIndexes)")
	}
	
	func testNewIndexForOldIndexWithInsertTail() {
		let old = "a b c d".components(separatedBy: " ")
		let new = "a b c e f g j h d".components(separatedBy: " ")
		let diff = old.diff(new)
		let newIndexes: [Int?] = (0..<old.count).map { diff.newIndexForOldIndex($0) }
		let expectedNewIndexes: [Int?] = [0, 1, 2, 8]
		XCTAssert(newIndexes.elementsEqual(expectedNewIndexes, by: { $0 == $1 }), "Expected newIndexes to be \(expectedNewIndexes), got \(newIndexes)")
	}
    
    func testNewIndexForOldIndexWithMoves() {
        let old = "a b c d e".components(separatedBy: " ")
        let new = "m c b f a".components(separatedBy: " ")
        let diff = old.diff(new)
        let newIndexes: [Int?] = (0..<old.count).map { diff.newIndexForOldIndex($0) }
        let expectedNewIndexes: [Int?] = [4, 2, 1, nil, nil]
        XCTAssert(newIndexes.elementsEqual(expectedNewIndexes, by: { $0 == $1 }), "Expected newIndexes to be \(expectedNewIndexes), got \(newIndexes)")
    }
	
	func testOldIndexForNewIndex() {
		let old = "a b c d e".components(separatedBy: " ")
		let new = "m a b f".components(separatedBy: " ")
		let diff = old.diff(new)
		let oldIndexes: [Int?] = (0..<new.count).map { diff.oldIndexForNewIndex($0) }
		let expectedOldIndexes: [Int?] = [nil, 0, 1, nil]
		XCTAssert(oldIndexes.elementsEqual(expectedOldIndexes, by: { $0 == $1 }), "Expected oldIndexes to be \(expectedOldIndexes), got \(oldIndexes)")
	}
    
    func testOldIndexForNewIndexWithMoves() {
        let old = "a b c d e".components(separatedBy: " ")
        let new = "m c b a f".components(separatedBy: " ")
        let diff = old.diff(new)
        let oldIndexes: [Int?] = (0..<new.count).map { diff.oldIndexForNewIndex($0) }
        let expectedOldIndexes: [Int?] = [nil, 2, 1, 0, nil]
        XCTAssert(oldIndexes.elementsEqual(expectedOldIndexes, by: { $0 == $1 }), "Expected oldIndexes to be \(expectedOldIndexes), got \(oldIndexes)")
    }
	
	func testCustomEqualityOperator() {
		let old = "a b c d e".components(separatedBy: " ")
		let oldWrapped = old.map { TestType(value: $0) }
		let new = "m a b f".components(separatedBy: " ")
		let newWrapped = new.map { TestType(value: $0) }
		let diff = oldWrapped.diff(newWrapped, elementsAreEqual: TestType.customEqual)
		var reconstructed = oldWrapped
		reconstructed.removeAtIndexes(diff.removedIndexes)
		reconstructed.insertElements(newWrapped[diff.insertedIndexes], atIndexes: diff.insertedIndexes)
		let reconstructedUnwrapped = reconstructed.map { $0.value }
		XCTAssertEqual(reconstructedUnwrapped, new)
	}
	
	func testSectionsSubscriptAtIndexPath() {
		let sections = [
			BasicSection(name: "Alpha", items: [1, 2, 3]),
			BasicSection(name: "Beta", items: [4, 5])
		]
		let indexPath0 = IndexPath(indexes: [0, 3])
		XCTAssertNil(sections[indexPath0])
		let indexPath1 = IndexPath(indexes: [2, 0])
		XCTAssertNil(sections[indexPath1])
		let indexPath2 = IndexPath(indexes: [0, 2])
		XCTAssertEqual(sections[indexPath2], 3)
		let indexPath3 = IndexPath(indexes: [1, 0])
		XCTAssertEqual(sections[indexPath3], 4)
	}
    
    func testModificationDetection() {
        let old = "a b c d e".components(separatedBy: " ")
        let oldWrapped = old.map { TestModifyType(value: $0, hashValue: 0) }
        let new = "m a b f".components(separatedBy: " ")
        let newWrapped = new.map { TestModifyType(value: $0, hashValue: ($0 == "a" ? 0 : 1)) }
        let diff = oldWrapped.diff(newWrapped)
        
        let expectedModifications = [1: 2]
        
        XCTAssertEqual(expectedModifications, diff.modifiedIndexes)
    }
    
    func testMovesDetection() {
        let old = "a b c d e".components(separatedBy: " ")
        let oldWrapped = old.map { TestModifyType(value: $0, hashValue: 0) }
        let new = "m b f a".components(separatedBy: " ")
        let newWrapped = new.map { TestModifyType(value: $0, hashValue: 0) }
        let diff = oldWrapped.diff(newWrapped)
        
        var expectedRemoved = IndexSet()
        expectedRemoved.insert(2)
        expectedRemoved.insert(3)
        expectedRemoved.insert(4)
        
        var expectedInserted = IndexSet()
        expectedInserted.insert(0)
        expectedInserted.insert(2)
        
        let expectedMoved = [0:3]
        
        XCTAssertEqual(expectedRemoved, diff.removedIndexes)
        XCTAssertEqual(expectedInserted, diff.insertedIndexes)
        XCTAssertEqual(expectedMoved, diff.movedIndexes)

    }
}

struct TestType {
	var value: String
	
	static func customEqual(t0: TestType, t1: TestType) -> Bool {
		return t0.value == t1.value
	}
}

struct TestModifyType: Hashable {
    var value: String
    var hashValue: Int

    static func customEqual(t0: TestModifyType, t1: TestModifyType) -> Bool {
        return t0.value == t1.value
    }
}

func ==(lhs: TestModifyType, rhs: TestModifyType) -> Bool {
    return lhs.value == rhs.value
}
