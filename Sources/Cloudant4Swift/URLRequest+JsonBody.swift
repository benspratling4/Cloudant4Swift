//
//  URLRequest+JsonBody.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/9/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation
extension URLRequest {
	
	@discardableResult internal mutating func setJsonBody<Body:Encodable>(_ body:Body, encoder:JSONEncoder)->Bool {
		guard let bodyData:Data = try? encoder.encode(body) else { return false }
		httpBody = bodyData
		setValue("application/json", forHTTPHeaderField: "Content-Type")
		setValue("\(bodyData.count)", forHTTPHeaderField: "Content-Length")
		return true
	}
	
	
}
