//
//  CloudantDatabase.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/9/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation


public struct CloudantDocumentResponse : Codable {
	var id:String
	var rev:String
}


public struct CloudantDocumentRow<DocType:CloudantDocument> : Codable {
	public var doc:DocType
}

public struct CloudantGetDocumentsResponse<DocType:CloudantDocument> : Codable {
	public var total_rows:Int
	public var offset:Int
	public var rows:[CloudantDocumentRow<DocType>]
	
}


public struct SearchResponse<DocType:CloudantDocument> : Codable {
	public var docs:[DocType]
	public var bookmark:String?
}


public enum Sorting : Encodable {
	public enum Direction : String, Codable {
		case ascending = "asc"
		case descending = "desc"
	}
	
	///field name, then either ascending or descending, in order
	case fields([(String,Direction)])
	
	case distance(DistanceSorting)
	
	
	public func encode(to encoder: Encoder) throws {
		switch self {
		case .fields(let values):
			var arrayContainer = encoder.unkeyedContainer()
			try values.forEach({
				try arrayContainer.encode([$0.0:$0.1])
			})
		case .distance(let distance):
			let stringValue:String = "<" + [
				distance.longFieldName
				,distance.latFieldName
				,"\(distance.longitude)"
				,"\(distance.latitude)"
				,distance.units.rawValue
				].joined(separator: ",") + ">"
			var stringContainer = encoder.singleValueContainer()
			try stringContainer.encode(stringValue)
		}
	}
	
	
	public struct DistanceSorting {
		//the field names of and longitude and latitude of the center of the search area
		public var longFieldName:String
		public var latFieldName:String
		public var latitude:Double	//in degrees
		public var longitude:Double	//in degrees
		public var units:Units = .kilometers
		
		public enum Units : String, Codable {
			case kilometers = "km"
			case miles = "mi"
		}
	}
}

public class CloudantDatabase<DocType : CloudantDocument> {
	
	public init(session:CloudantSession, pathComponent:String) {
		self.pathComponent = pathComponent
		self.session = session
		jsonEncoder = JSONEncoder()
		jsonDecoder = JSONDecoder()
		DocType.decoderConfiguration?(jsonDecoder)
		DocType.encoderConfiguration?(jsonEncoder)
	}
	
	private var jsonEncoder:JSONEncoder
	private var jsonDecoder:JSONDecoder
	
	private var session:CloudantSession
	
	public var pathComponent:String
	
	
	private func getDocumentRequest(id:String, rev:String? = nil)->URLRequest? {
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)/\(id)"
		var query:[URLQueryItem] = []
		if let revision:String = rev {
			query.append(URLQueryItem(name: "rev", value: revision))
		}
		components.queryItems = query
		guard let url:URL = components.url else { return nil }
		return URLRequest(url: url)
	}
	
	
	public func getDocument(id:String, rev:String? = nil, completion:@escaping(DocType?)->())->Bool {
		guard let request:URLRequest = getDocumentRequest(id: id, rev: rev) else {
			completion(nil)
			return false
		}
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			guard let data:Data = dataOrNil else {completion(nil)
				return
			}
			let document:DocType? = try? self.jsonDecoder.decode(DocType.self, from: data)
			completion(document)
		}
		if !kickedOff {
			completion(nil)
		}
		return kickedOff
	}
	
	///reads all the docs, warning, this is a data intensive operation
	private func requestForAllDocs(limit:Int? = nil, skip:Int? = nil)->URLRequest? {
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)/_all_docs"
		var query:[URLQueryItem] = [URLQueryItem(name: "include_docs", value: "true")]
		if let limit:Int = limit {
			query.append(URLQueryItem(name: "limit", value: "\(limit)"))
		}
		if let skip:Int = skip {
			query.append(URLQueryItem(name: "skip", value: "\(skip)"))
		}
		components.queryItems = query
		guard let url:URL = components.url else { return nil }
		return URLRequest(url: url)
	}
	
	
	public func getAllDocs(limit:Int? = nil, skip:Int? = nil, completion:@escaping(CloudantGetDocumentsResponse<DocType>?)->())->Bool {
		guard let request:URLRequest = requestForAllDocs(limit:limit, skip: skip) else {
			completion(nil)
			return false
		}
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			guard let data:Data = dataOrNil else {completion(nil)
				return
			}
			let response:CloudantGetDocumentsResponse<DocType>? = try? self.jsonDecoder.decode(CloudantGetDocumentsResponse<DocType>.self, from: data)
			completion(response)
		}
		if !kickedOff {
			completion(nil)
		}
		return kickedOff
		
		
	}
	
	
	private func requestForCreatingDocument(_ document:DocType)->URLRequest? {
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)"
		guard let url:URL = components.url else { return nil }
		var request:URLRequest = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setJsonBody(document, encoder: jsonEncoder)
		return request
	}
	
	///document should not have _rev specified, ._id is optional
	public func makeDocument(_ document:DocType, completion:@escaping(CloudantDocumentResponse?)->())->Bool? {
		guard let request:URLRequest = requestForCreatingDocument(document) else {
			completion(nil)
			return nil
		}
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			guard let data:Data = dataOrNil else {completion(nil)
				return
			}
			let creationResponse:CloudantDocumentResponse? = try? self.jsonDecoder.decode(CloudantDocumentResponse.self, from: data)
			completion(creationResponse)
		}
		if !kickedOff {
			completion(nil)
		}
		return kickedOff
	}
	
	private func requestForUpdating(document:DocType)->URLRequest? {
		guard let id:String = document._id else { return nil }
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)/\(id)"
		guard let url:URL = components.url else { return nil }
		
		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		request.setJsonBody(document, encoder: jsonEncoder)
		return request
	}
	
	
	public func updateDocument(_ document:DocType, completion:@escaping(CloudantDocumentResponse?, _ conflict:Bool)->())->Bool {
		guard let request:URLRequest = requestForUpdating(document: document) else {
			completion(nil, false)
			return false
		}
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			let isConflict:Bool = (responseOrNil as? HTTPURLResponse)?.statusCode == 409
			guard let data:Data = dataOrNil else {
				completion(nil, isConflict)
				return
			}
			let creationResponse:CloudantDocumentResponse? = try? self.jsonDecoder.decode(CloudantDocumentResponse.self, from: data)
			completion(creationResponse, isConflict)
		}
		if !kickedOff {
			completion(nil, false)
		}
		return kickedOff
	}
	
	
	private func requestForDeleting(id:String, rev:String)->URLRequest? {
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)/\(id)"
		components.queryItems = [URLQueryItem(name: "rev", value: rev)]
		guard let url:URL = components.url else { return nil }
		var request:URLRequest = URLRequest(url: url)
		request.httpMethod = "DELETE"
		return request
	}
	
	
	public func deleteDocument(id:String, rev:String, completion:@escaping(CloudantDocumentResponse?, _ conflict:Bool)->())->Bool {
		guard let request:URLRequest = requestForDeleting(id:id, rev:rev) else { return false }
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			let isConflict:Bool = (responseOrNil as? HTTPURLResponse)?.statusCode == 409
			guard let data:Data = dataOrNil else {
				completion(nil, isConflict)
				return
			}
			let creationResponse:CloudantDocumentResponse? = try? self.jsonDecoder.decode(CloudantDocumentResponse.self, from: data)
			completion(creationResponse, isConflict)
		}
		if !kickedOff {
			completion(nil, false)
		}
		return kickedOff
	}
	
	internal struct SearchFields : Encodable {
		var query:String
		var limit:Int?
		var bookmark:String?
		var include_docs:String = "true"
		var sort:Sorting?
		init(query:String) {
			self.query = query
		}
	}
	
	public func requestForSearching(designDocId:String, indexName:String, query:LuceneQuery, bookmark:String?, limit:Int?)->URLRequest? {
		var components:URLComponents = session.baseUrlComponents
		components.path = "/\(pathComponent)/_design/\(designDocId)/_search/\(indexName)"
		guard let url = components.url else { return nil }
		var searchFields = SearchFields(query: query.luceneSearch)
		searchFields.limit = limit
		searchFields.bookmark = bookmark
		//sort
		var request:URLRequest = URLRequest(url: url)
		request.setJsonBody(searchFields, encoder: jsonEncoder)
		request.httpMethod = "POST"
		return request
	}
	
	
	public func searchFor(query:LuceneQuery, in designDoc:String, index:String, limit:Int? = 200, sorting:Sorting? = nil, bookmark:String? = nil, completion:@escaping(SearchResponse<DocType>?)->())->Bool {
		guard let request:URLRequest = requestForSearching(designDocId: designDoc, indexName: index, query: query, bookmark: bookmark, limit: limit) else { return false }
		let kickedOff:Bool = session.task(request: request) { (dataOrNil, responseOrNil, errorOrNil) in
			guard let data:Data = dataOrNil else {
				completion(nil)
				return
			}
			let creationResponse:SearchResponse<DocType>? = try? self.jsonDecoder.decode(SearchResponse<DocType>.self, from: data)
			completion(creationResponse)
		}
		if !kickedOff {
			completion(nil)
		}
		return kickedOff
	}
	
	
}
