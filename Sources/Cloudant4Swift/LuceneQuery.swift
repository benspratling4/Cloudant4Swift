//
//  LuceneQuery.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/10/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation


public protocol LuceneQuery {
	
	var luceneSearch:String { get }
}


extension CharacterSet {
	
	internal static let luceneSearchSpecialCharacters:CharacterSet = CharacterSet(charactersIn: "+-&|!(){}[]^\"~*?:\\/")
	
}


extension String {
	
	internal var luceneLiteralEscaped:String {
		var text:String = self
		var endOfRange = text.endIndex
		while let range = text.rangeOfCharacter(from: .luceneSearchSpecialCharacters, options: [.literal, .backwards], range: text.startIndex..<endOfRange) {
			let subText = text[range]
			text.replaceSubrange(range, with: "\\"+subText)
			endOfRange = range.lowerBound
		}
		return text
	}
	
}


public struct LuceneTextSearch : LuceneQuery {
	
	public var field:String
	
	public var criteria:LuceneFieldCriteria
	
	public var luceneSearch:String {
		return field.luceneLiteralEscaped + ":" + criteria.luceneFieldString
	}
	
}


public protocol LuceneFieldCriteria {
	var luceneFieldString:String { get }
}


public struct LuceneRangeCriteria <Value> : LuceneFieldCriteria {
	public var inclusive:Bool
	public var min:Value
	public var max:Value
	public var luceneFieldString:String {
		var text:String = "\(min)" + " TO " + "\(max)"
		if inclusive {
			text = "[" + text + "]"
		} else {
			text = "{" + text + "}"
		}
		return text
	}
}


public struct LuceneTextCriteria : LuceneFieldCriteria {
	
	public var phrases:[LuceneTextPhrase]
	
	public var luceneFieldString:String {
		return "(" + phrases.map({$0.luceneSearch}).joined(separator: " ") + ")"
	}
}


public struct LuceneTextPhrase {
	public var literal:String
	
	public var options:Options?
	
	public struct Options: OptionSet {
		public var rawValue: Int
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
		public static let contains:Options = Options(rawValue: 1)
		public static let beginsWith:Options = Options(rawValue: 2)
	}
	
	public var luceneSearch:String {
		var text:String = ""
		if options?.contains(.contains) == true {
			text += "+"
		}
		let useEnclosingQuotes:Bool = literal.contains(" ")
		if useEnclosingQuotes {
			text += "\""
		}
		text += literal.luceneLiteralEscaped
		if options?.contains(.beginsWith) == true {
			text += "*"
		}
		if useEnclosingQuotes {
			text += "\""
		}
		return text
	}
}


public struct LuceneLogicalQuery : LuceneQuery {
	public var op:String
	public var terms:[LuceneQuery]
	public var luceneSearch:String {
		return terms.map({return "(" + $0.luceneSearch + ")"}).joined(separator: " " + op + " ")
	}
}
