//
//  CloudantQuery.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/10/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation


public protocol CloudantQuery {
	var json:[String:Any] { get }
	
}

extension CloudantDocument {
	public static func query(path:String)->CloudantQueryAnchor {
		return CloudantQueryAnchor(path:path)
	}
}


public struct CloudantQueryAnchor {
	public var path:String
}


public struct CloudantPropertyQuery<ValueType:Encodable>  {
	public var path:String
	
	///no leading "$"
	public var op:String
	public var value:ValueType
	
	public var json:[String:Any] {
		return [path:["$"+op:value]]
	}
	
}


public func == <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "eq", value: rhs)
}

public func <= <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "lte", value: rhs)
}

public func < <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "lt", value: rhs)
}

public func >= <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "gte", value: rhs)
}

public func > <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "gt", value: rhs)
}

public func != <ValueType:Encodable>(lhs:CloudantQueryAnchor, rhs:ValueType)->CloudantPropertyQuery<ValueType> {
	return CloudantPropertyQuery(path: lhs.path, op: "gt", value: rhs)
}


public struct CloudantLogicalQuery : CloudantQuery {
	
	public var op:String
	
	public var subQueries:[CloudantQuery]
	
	public var json:[String:Any] {
		return ["$"+op:subQueries.map({$0.json})]
	}
	
}


public func &&(lhs:CloudantQuery, rhs:CloudantQuery)->CloudantLogicalQuery {
	return CloudantLogicalQuery(op: "and", subQueries: [lhs, rhs])
}

public func ||(lhs:CloudantQuery, rhs:CloudantQuery)->CloudantLogicalQuery {
	return CloudantLogicalQuery(op: "or", subQueries: [lhs, rhs])
}

