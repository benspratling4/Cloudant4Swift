//
//  CloudantDocument.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/9/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation



public protocol CloudantDocument : Codable {
	
	var _id:String? { get set }
	
	var _rev:String? { get set }
	
	static var decoderConfiguration:((JSONDecoder)->())? { get }
	
	static var encoderConfiguration:((JSONEncoder)->())? { get }
	
}


