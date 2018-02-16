//
//  TestGettingAllDatabaseNames.swift
//  Cloudant4SwiftPackageDescription
//
//  Created by Ben Spratling on 2/15/18.
//

import XCTest
import Cloudant4Swift

class TestGettingAllDatabaseNames: XCTestCase {
	
	lazy var session = CloudantSession(uri:"https://username:password@username-bluemix.cloudant.com")!
	
    func testExample() {
		
		let namesExpectation = expectation(description: "get database names")
		session.getAllDatabaseNames { (namesOrNil) in
			guard let names:[String] = namesOrNil else {
				return
			}
			print("names = \(names)")
			namesExpectation.fulfill()
		}
		waitForExpectations(timeout: 30.0, handler: nil)
    }
	
    
}
