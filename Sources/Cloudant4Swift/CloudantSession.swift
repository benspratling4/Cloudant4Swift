//
//  CloudantSession.swift
//  Cloudant4Swift
//
//  Created by Ben Spratling on 2/9/18.
//  Copyright © 2018 benspratling.com. All rights reserved.
//

import Foundation
import SwiftPatterns

public struct CloudantCredentials {
	public var username:String
	public var password:String
	public init(username:String, password:String) {
		self.username = username
		self.password = password
	}
}

public typealias URLSessionTaskCompletionHandler = (Data?, URLResponse?, Error?)->()


///A CloudantSession removes the headache of authenticating or re-authenticating and handling all the re-dispatches of requests as a result
///when authentication fails, all tasks that fail due to lack of authentication will be "frozen", and re-tried when authentication is re-established.
///when authentication fails, authentication is retried once, and if that fails, all frozen requests are failed.
public class CloudantSession {
	
	public static func newUrlConfiguration()->URLSessionConfiguration {
		return URLSessionConfiguration.default
		/*var config = URLSessionConfiguration(httpCookieStorage:HTTPCookieStorage())
		//config.httpCookieStorage =
		return config*/
	}
	
	public var urlSession:URLSession
	
	public init(host:String, credentials:CloudantCredentials, urlSessionConfiguration:URLSessionConfiguration = CloudantSession.newUrlConfiguration()) {
		self.host = host
		self.credentials = credentials
		urlSession = URLSession(configuration: urlSessionConfiguration)
	//	authenticate({_ in })	//pre-empt anything
	}
	
	deinit {
		urlSession.invalidateAndCancel()
	}
	
	//todo: add authentication & negotiation
	private var credentials:CloudantCredentials
	
	private var host:String
	
	public var useSessionAuthentication:Bool = false	//todo: for now, later make this true by default
	
	///if authentication fails, this can be called, and new credentials provided
	public var authenticationChallengeHandler:(()->((String, String)?))? {
		didSet {
			//todo: write me
		}
	}
	
	public var baseUrlComponents:URLComponents {
		var components = URLComponents()
		components.scheme = "https"
		components.host = host + ".cloudant.com"
		if !useSessionAuthentication {
			components.user = credentials.username
			components.password = credentials.password
		}
		return components
	}
	
	private func authRequest()->URLRequest? {
		var components:URLComponents = baseUrlComponents
		components.path = "/_session"
		guard let url:URL = components.url else { return nil }
		var request = URLRequest(url:url)
		request.httpMethod = "POST"
		request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		guard let body = "name=\(credentials.username)&password=\(credentials.password)".stringByAddingPercentEncodingForFormData()?.data(using: .utf8) else { return nil }
		request.httpBody =  body
		request.addValue("\(body.count)", forHTTPHeaderField: "Content-Length")
		return request
	}
	
	private var requestsAwaitingAuthentication:QueuedVar<(URLSessionTask, [(URLRequest,URLSessionTaskCompletionHandler)])?> = QueuedVar<(URLSessionTask, [(URLRequest,URLSessionTaskCompletionHandler)])?>(model:nil)
	
	
	///completion gets true if we authenticated, false otherwise
	///you should call .resume() on the task when you're ready
	private func authenticate(_ completion:@escaping(Bool)->())->URLSessionTask? {
		guard let request = authRequest() else {
			completion(false)
			return nil
		}
		guard let task:URLSessionTask = requestsAwaitingAuthentication.readWrite(work: { (model) -> URLSessionTask? in
			if model != nil {
				return nil
			}
			let authenticationTask:URLSessionTask = urlSession.dataTask(with: request, completionHandler: { (_, responseOrNil, _) in
				guard let response = responseOrNil as? HTTPURLResponse else {
					completion(false)
					return
				}
				completion(response.statusCode == 200)
			})
			model = (authenticationTask, [])
			return authenticationTask
		}) else {
			completion(false)
			return nil
		}
		return task
	}
	
	//so re-start all the frozen requests
	private func authenticationSucceeded() {
		let all:(URLSessionTask, [(URLRequest,URLSessionTaskCompletionHandler)])? = requestsAwaitingAuthentication.readWrite(work: {  contents in
			let oldContents = contents
			contents = nil
			return oldContents
		})
		//try them all
	/*	all.forEach { (pair) in
			_ = urlSession.dataTask(with: pair.0, completionHandler: pair.1)
		}	*/
	}
	
	//so fail all the frozen requests
	private func authenticationFailed() {
		let all:(URLSessionTask, [(URLRequest,URLSessionTaskCompletionHandler)])? = requestsAwaitingAuthentication.readWrite(work: {  contents in
			let oldContents = contents
			contents = nil
			return oldContents
		})
	/*	all?.1.forEach { (pair) in
			pair.1(nil, nil, nil)
		}	*/
	}
	
	///databases are not held strongly, they are created new each time you call this method
	///hold the instance strongly.  It maintains a reference to this session
	public func database<DocType:CloudantDocument>(named:String)->CloudantDatabase<DocType> {
		return CloudantDatabase(session: self, pathComponent: named)
	}
	
	
	///return value is whether the request was kicked off, or likely will be
	internal func task(request:URLRequest, completion:@escaping(Data?, URLResponse?, Error?)->())->Bool {
		if request.url?.user != nil && request.url?.password != nil {
			//kick off now, don't wait on auth
			let task:URLSessionTask = urlSession.dataTask(with: request, completionHandler: completion)
			task.resume()
			return true
		}
		
		/*
		let kickOffNow:Bool = requestsAwaitingAuthentication.readWrite { (modelOrNil) -> Bool in
			guard let model = modelOrNil else {
				modelOrNil?.1.append((request,completion))
				return false	//?
			}
			return true
		}
		
		
		return urlSession.dataTask(with: request, completionHandler: completion)	*/
		return false
	}
	
	
	private func taskFailedDueToAuthentication(_ request:URLRequest, completion:@escaping URLSessionTaskCompletionHandler)->Bool {
		let newTask:URLSessionTask? = requestsAwaitingAuthentication.readWrite(work: {modelOrNil in
			if modelOrNil == nil {
				let task:URLSessionTask? = firstTaskFailedDuetoAuthentication(request, completion:completion, model:&modelOrNil)
				return task
			} else {
				modelOrNil?.1.append((request,completion))
				return nil
			}
		})
		newTask?.resume()
		return newTask != nil
	}
	
	private func firstTaskFailedDuetoAuthentication(_ request:URLRequest, completion:@escaping URLSessionTaskCompletionHandler, model:inout(URLSessionTask, [(URLRequest,URLSessionTaskCompletionHandler)])?)->URLSessionTask? {
		guard let task = authenticate({ [weak self] (authenticated) in
			authenticated ? self?.authenticationSucceeded() : self?.authenticationFailed()
		}) else {
			return nil
		}
		model = (task, [(request, completion)])
		return task
	}
	
}
