
import Foundation

public struct ArrayDiff {
	static var debugLogging = false
	
	/// The indexes in the old array of the items that were kept
	public let commonIndexes: IndexSet
	/// The indexes in the old array of the items that were removed
	public let removedIndexes: IndexSet
	/// The indexes in the new array of the items that were inserted
	public let insertedIndexes: IndexSet
    /// The map of old indexes to new indexes in the array of the items that were modified
    public let modifiedIndexes: [Int: Int]
    /// The map of old indexes to new indexes in the array of the items that were moved
    public let movedIndexes: [Int: Int]
	
	/// Returns nil if the item was inserted
	public func oldIndexForNewIndex(_ index: Int) -> Int? {
		if insertedIndexes.contains(index) { return nil }
        if let oldIndex = movedIndexes.allKeysForValue(index).first { return oldIndex }

        let (removed, inserted) = self.mergedWithMovesRemovedAndInsertedIndexes()
        
		var result = index

		result -= inserted.count(in: NSMakeRange(0, index).toRange()!)
        for i in removed {
            if i <= result {
                result += 1
            }
        }
		return result
	}
	
	/// Returns nil if the item was deleted
	public func newIndexForOldIndex(_ index: Int) -> Int? {
		if removedIndexes.contains(index) { return nil }
        if let newIndex = movedIndexes[index] { return newIndex }

        let (removed, inserted) = self.mergedWithMovesRemovedAndInsertedIndexes()
        
		var result = index
		let deletedBefore = removed.count(in: NSMakeRange(0, index).toRange()!)
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
    
    
    /**
     Returns removed and inserted indexes if moves treated as removes/inserts
     */
    public func mergedWithMovesRemovedAndInsertedIndexes() -> (removed: IndexSet, inserted: IndexSet) {
        
        var inserted = IndexSet(insertedIndexes)
        var removed = IndexSet(removedIndexes)
        
        movedIndexes.values.forEach{inserted.insert($0)}
        movedIndexes.keys.forEach{removed.insert($0)}
        
        return (removed, inserted)
    }
}

public extension Array {
	
    public func diff(_ other: Array<Element>, elementsAreEqual: ((Element, Element) -> Bool)) -> ArrayDiff {
        var lengths: [[Int]] = Array<Array<Int>>(
            repeating: Array<Int>(
                repeating: 0,
                count: other.count + 1),
            count: count + 1
        )
        
        for i in (0...count).reversed() {
            for j in (0...other.count).reversed() {
                if i == count || j == other.count {
                    lengths[i][j] = 0
                } else if elementsAreEqual(self[i], other[j]) {
                    lengths[i][j] = 1 + lengths[i+1][j+1]
                } else {
                    lengths[i][j] = Swift.max(lengths[i+1][j], lengths[i][j+1])
                }
            }
        }
		var commonIndexes = IndexSet()
		var i = 0, j = 0

		while i < count && j < other.count {
			if elementsAreEqual(self[i], other[j]) {
				commonIndexes.insert(i)
				i += 1
				j += 1
			} else if lengths[i+1][j] >= lengths[i][j+1] {
				i += 1
			} else {
				j += 1
			}
		}
		
		var removedIndexes = IndexSet(integersIn: 0..<count)
		removedIndexes.subtract(commonIndexes)
		
		let commonObjects = self[commonIndexes]
		var addedIndexes = IndexSet()
		i = 0
		j = 0
		
		while i < commonObjects.count || j < other.count {
			if i < commonObjects.count && j < other.count && elementsAreEqual (commonObjects[i], other[j]) {
				i += 1
				j += 1
			} else {
				addedIndexes.insert(j)
				j += 1
			}
		}
        
        var movedIndexes = [Int: Int]()
        var deletedIndexes = removedIndexes
        var insertedIndexes = addedIndexes
        
        for oldIndex in removedIndexes {
            
            let oldElement = self[oldIndex]
            
            if let newIndex = other.index(where: { elementsAreEqual ($0, oldElement)}) {
                
                deletedIndexes.remove(oldIndex)
                insertedIndexes.remove(newIndex)
                
                movedIndexes[oldIndex] = newIndex
            }
        }
        
        return ArrayDiff(commonIndexes: commonIndexes, removedIndexes: deletedIndexes, insertedIndexes: insertedIndexes, modifiedIndexes: [Int: Int](), movedIndexes: movedIndexes)
	}
}

public extension Array where Element: Equatable {
    public func diff(_ other: Array<Element>) -> ArrayDiff {
        return self.diff(other, elementsAreEqual: { $0 == $1 })
    }
}
public extension Array where Element: Hashable {
    public func diff(_ other: Array<Element>) -> ArrayDiff {
        let diff = self.diff(other, elementsAreEqual: {
            let result = $0 == $1
            return result
        }) //Simple $0 == $1 crashes Swift compiler

        var modifiedIndexes = [Int: Int]()
        
        for index in diff.commonIndexes {
            if let newIndex = diff.newIndexForOldIndex(index) {
                if self[index].hashValue != other[newIndex].hashValue {
                    modifiedIndexes[index] = newIndex
                }
            }
        }
        
        return ArrayDiff(commonIndexes: diff.commonIndexes, removedIndexes: diff.removedIndexes, insertedIndexes: diff.insertedIndexes, modifiedIndexes: modifiedIndexes, movedIndexes: diff.movedIndexes)
    }
}

extension Dictionary where Value : Equatable {
    func allKeysForValue(_ val : Value) -> [Key] {
        return self.filter { $1 == val }.map { $0.0 }
    }
}
