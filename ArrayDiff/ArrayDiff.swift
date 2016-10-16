
import Foundation

public struct ArrayDiff {
	static var debugLogging = false
	
	/// The indexes in the old array of the items that were kept
	public let commonIndexes: NSIndexSet
	/// The indexes in the old array of the items that were removed
	public let removedIndexes: NSIndexSet
	/// The indexes in the new array of the items that were inserted
	public let insertedIndexes: NSIndexSet
    /// The map of old indexes to new indexes in the array of the items that were modified
    public let modifiedIndexes: [Int: Int]
    /// The map of old indexes to new indexes in the array of the items that were moved
    public let movedIndexes: [Int: Int]
	
	/// Returns nil if the item was inserted
	public func oldIndexForNewIndex(index: Int) -> Int? {
		if insertedIndexes.containsIndex(index) { return nil }
        if let oldIndex = movedIndexes.allKeysForValue(index).first { return oldIndex }

        let inserted = NSMutableIndexSet()
        let removed = NSMutableIndexSet()
        
        inserted.addIndexes(insertedIndexes)
        removed.addIndexes(removedIndexes)

        movedIndexes.values.forEach{inserted.addIndex($0)}
        movedIndexes.keys.forEach{removed.addIndex($0)}
        
		var result = index

		result -= inserted.countOfIndexesInRange(NSMakeRange(0, index))
        for i in removed {
            if i <= result {
                result += 1
            }
        }
		return result
	}
	
	/// Returns nil if the item was deleted
	public func newIndexForOldIndex(index: Int) -> Int? {
		if removedIndexes.containsIndex(index) { return nil }
        if let newIndex = movedIndexes[index] { return newIndex }

        let inserted = NSMutableIndexSet()
        let removed = NSMutableIndexSet()
        
        inserted.addIndexes(insertedIndexes)
        removed.addIndexes(removedIndexes)
        
        movedIndexes.values.forEach{inserted.addIndex($0)}
        movedIndexes.keys.forEach{removed.addIndex($0)}
        
		var result = index
		let deletedBefore = removed.countOfIndexesInRange(NSMakeRange(0, index))
		result -= deletedBefore
		var insertedAtOrBefore = 0
		for i in inserted {
			if i <= result  {
				insertedAtOrBefore += 1
				result += 1
			} else {
				break
			}
		}
		if ArrayDiff.debugLogging {
			print("***Old -> New\n Removed \(removedIndexes)\n Inserted \(insertedIndexes)\n \(index) - \(deletedBefore) + \(insertedAtOrBefore) = \(result)\n")
		}
		
		return result
	}
    
    /**
     Returns true if there are no changes to the items in this diff
     */
    public var isEmpty: Bool {
        return removedIndexes.count == 0 && insertedIndexes.count == 0 && movedIndexes.count == 0 && modifiedIndexes.count == 0
    }
}

public extension Array {
	
    public func diff(other: Array<Element>, elementsAreEqual: ((Element, Element) -> Bool)) -> ArrayDiff {
		var lengths: [[Int]] = Array<Array<Int>>(
			count: count + 1,
			repeatedValue: Array<Int>(
				count: other.count + 1,
				repeatedValue: 0)
		)
		
		for i in (0...count).reverse() {
			for j in (0...other.count).reverse() {
				if i == count || j == other.count {
					lengths[i][j] = 0
				} else if elementsAreEqual(self[i], other[j]) {
					lengths[i][j] = 1 + lengths[i+1][j+1]
				} else {
					lengths[i][j] = max(lengths[i+1][j], lengths[i][j+1])
				}
			}
		}
		let commonIndexes = NSMutableIndexSet()
		var i = 0, j = 0

		while i < count && j < other.count {
			if elementsAreEqual(self[i], other[j]) {
				commonIndexes.addIndex(i)
				i += 1
				j += 1
			} else if lengths[i+1][j] >= lengths[i][j+1] {
				i += 1
			} else {
				j += 1
			}
		}
		
		let removedIndexes = NSMutableIndexSet(indexesInRange: NSMakeRange(0, count))
		removedIndexes.removeIndexes(commonIndexes)
		
		let commonObjects = self[commonIndexes]
		let addedIndexes = NSMutableIndexSet()
		i = 0
		j = 0
		
		while i < commonObjects.count || j < other.count {
			if i < commonObjects.count && j < other.count && elementsAreEqual (commonObjects[i], other[j]) {
				i += 1
				j += 1
			} else {
				addedIndexes.addIndex(j)
				j += 1
			}
		}
        
        var movedIndexes = [Int: Int]()
        let deletedIndexes = removedIndexes.mutableCopy() as! NSMutableIndexSet
        let insertedIndexes = addedIndexes.mutableCopy() as! NSMutableIndexSet
        
        for oldIndex in removedIndexes {
            
            let oldElement = self[oldIndex]
            
            if let newIndex = other.indexOf({ elementsAreEqual ($0, oldElement)}) {
                
                deletedIndexes.removeIndex(oldIndex)
                insertedIndexes.removeIndex(newIndex)
                
                movedIndexes[oldIndex] = newIndex
            }
        }
        
        return ArrayDiff(commonIndexes: commonIndexes, removedIndexes: deletedIndexes, insertedIndexes: insertedIndexes, modifiedIndexes: [Int: Int](), movedIndexes: movedIndexes)
	}
}

public extension Array where Element: Equatable {
	public func diff(other: Array<Element>) -> ArrayDiff {
		return self.diff(other, elementsAreEqual: { $0 == $1 })
	}
}
public extension Array where Element: Hashable {
    public func diff(other: Array<Element>) -> ArrayDiff {
        let diff = self.diff(other, elementsAreEqual: { $0 == $1 })

        var modifiedIndexes = [Int: Int]()
        
        for index in diff.commonIndexes {
            if let newIndex = diff.newIndexForOldIndex(index) where self[index].hashValue != other[newIndex].hashValue {
                modifiedIndexes[index] = newIndex
            }
        }
        
        return ArrayDiff(commonIndexes: diff.commonIndexes, removedIndexes: diff.removedIndexes, insertedIndexes: diff.insertedIndexes, modifiedIndexes: modifiedIndexes, movedIndexes: diff.movedIndexes)
    }
}

extension Dictionary where Value : Equatable {
    func allKeysForValue(val : Value) -> [Key] {
        return self.filter { $1 == val }.map { $0.0 }
    }
}
