//
//  String+FormEncoding.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/9/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation

extension String {
	
	/// from https://useyourloaf.com/blog/how-to-percent-encode-a-url-string/
	
	private static let allowedFormEncodedCharacters:CharacterSet =  { ()->CharacterSet in
		var allowed:CharacterSet = CharacterSet.alphanumerics
		allowed.insert(charactersIn: "*-._")
		return allowed
	}()
	
	private static let allowedFormEncodedCharactersAndSpace:CharacterSet =  { ()->CharacterSet in
		var allowed:CharacterSet = allowedFormEncodedCharacters
		allowed.insert(charactersIn: " ")
		return allowed
	}()
	
	internal func stringByAddingPercentEncodingForFormData(plusForSpace: Bool=false) -> String? {
		guard var encoded:String = self.addingPercentEncoding(withAllowedCharacters: plusForSpace ? String.allowedFormEncodedCharactersAndSpace : String.allowedFormEncodedCharacters ) else {
			return nil
		}
		if plusForSpace {
			encoded = encoded.replacingOccurrences(of: " ", with: "+")
		}
		return encoded
	}

}
