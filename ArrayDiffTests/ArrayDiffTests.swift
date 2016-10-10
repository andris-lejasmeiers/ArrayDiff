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
		let old = "a b c d e".componentsSeparatedByString(" ")
		let new = "m a b f".componentsSeparatedByString(" ")
		
		let allFirstIndexes = NSIndexSet(indexesInRange: NSMakeRange(0, old.count))
		
		let expectedRemoves = NSMutableIndexSet()
		expectedRemoves.addIndexesInRange(NSMakeRange(2, 3))

		let expectedInserts = NSMutableIndexSet()
		expectedInserts.addIndex(0)
		expectedInserts.addIndex(3)
		

		let expectedCommonObjects = "a b".componentsSeparatedByString(" ")

		let diff = old.diff(new)
		
		XCTAssertEqual(expectedInserts, diff.insertedIndexes)
		XCTAssertEqual(expectedRemoves, diff.removedIndexes)
		XCTAssertEqual(expectedCommonObjects, old[diff.commonIndexes])
		
		let removedPlusCommon = NSMutableIndexSet(indexSet: diff.removedIndexes)
		removedPlusCommon.addIndexes(diff.commonIndexes)
		XCTAssertEqual(removedPlusCommon, allFirstIndexes)
		
		var reconstructed = old
		reconstructed.removeAtIndexes(diff.removedIndexes)
		reconstructed.insertElements(new[diff.insertedIndexes], atIndexes: diff.insertedIndexes)
		XCTAssertEqual(reconstructed, new)
    }
	
	func testNewIndexForOldIndex() {
		let old = "a b c d e".componentsSeparatedByString(" ")
		let new = "m a b f".componentsSeparatedByString(" ")
		let diff = old.diff(new)
		let newIndexes: [Int?] = (0..<old.count).map { diff.newIndexForOldIndex($0) }
		let expectedNewIndexes: [Int?] = [1, 2, nil, nil, nil]
		XCTAssert(newIndexes.elementsEqual(expectedNewIndexes, isEquivalent: { $0 == $1 }), "Expected newIndexes to be \(expectedNewIndexes), got \(newIndexes)")
	}
	
	func testNewIndexForOldIndexWithInsertTail() {
		let old = "a b c d".componentsSeparatedByString(" ")
		let new = "a b c e f g j h d".componentsSeparatedByString(" ")
		let diff = old.diff(new)
		let newIndexes: [Int?] = (0..<old.count).map { diff.newIndexForOldIndex($0) }
		let expectedNewIndexes: [Int?] = [0, 1, 2, 8]
		XCTAssert(newIndexes.elementsEqual(expectedNewIndexes, isEquivalent: { $0 == $1 }), "Expected newIndexes to be \(expectedNewIndexes), got \(newIndexes)")
	}
	
	func testOldIndexForNewIndex() {
		let old = "a b c d e".componentsSeparatedByString(" ")
		let new = "m a b f".componentsSeparatedByString(" ")
		let diff = old.diff(new)
		let oldIndexes: [Int?] = (0..<new.count).map { diff.oldIndexForNewIndex($0) }
		let expectedOldIndexes: [Int?] = [nil, 0, 1, nil]
		XCTAssert(oldIndexes.elementsEqual(expectedOldIndexes, isEquivalent: { $0 == $1 }), "Expected oldIndexes to be \(expectedOldIndexes), got \(oldIndexes)")
	}
	
	func testCustomEqualityOperator() {
		let old = "a b c d e".componentsSeparatedByString(" ")
		let oldWrapped = old.map { TestType(value: $0) }
		let new = "m a b f".componentsSeparatedByString(" ")
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
		let indexPath0 = NSIndexPath(indexes: [0, 3], length: 2)
		XCTAssertNil(sections[indexPath0])
		let indexPath1 = NSIndexPath(indexes: [2, 0], length: 2)
		XCTAssertNil(sections[indexPath1])
		let indexPath2 = NSIndexPath(indexes: [0, 2], length: 2)
		XCTAssertEqual(sections[indexPath2], 3)
		let indexPath3 = NSIndexPath(indexes: [1, 0], length: 2)
		XCTAssertEqual(sections[indexPath3], 4)
	}
    
    func testModificationDetection() {
        let old = "a b c d e".componentsSeparatedByString(" ")
        let oldWrapped = old.map { TestModifyType(value: $0, hashValue: 0) }
        let new = "m a b f".componentsSeparatedByString(" ")
        let newWrapped = new.map { TestModifyType(value: $0, hashValue: ($0 == "a" ? 0 : 1)) }
        let diff = oldWrapped.diff(newWrapped)
        
        let expectedModifications = NSMutableIndexSet()
        expectedModifications.addIndex(1)
        
        XCTAssertEqual(expectedModifications, diff.modifiedIndexes)
    }
    
    func testMovesDetection() {
        let old = "a b c d e".componentsSeparatedByString(" ")
        let oldWrapped = old.map { TestModifyType(value: $0, hashValue: 0) }
        let new = "m b f a".componentsSeparatedByString(" ")
        let newWrapped = new.map { TestModifyType(value: $0, hashValue: 0) }
        let diff = oldWrapped.diff(newWrapped)
        
        let expectedRemoved = NSMutableIndexSet()
        expectedRemoved.addIndex(2)
        expectedRemoved.addIndex(3)
        expectedRemoved.addIndex(4)
        
        let expectedInserted = NSMutableIndexSet()
        expectedInserted.addIndex(0)
        expectedInserted.addIndex(2)
        
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
