# Cloudant4Swift

`Cloudant4Swift` is a Swift 4 package for working with Cloudant operationally.  Cloudant is a no-sql database (i.e. json-document) cloud service.

https://www.ibm.com/cloud/cloudant

While it is a work-in-progress, it supports the bare minimum functionality, create, update, get, delete and simple search, and thus I won't likely make it full-featured without help.

# CloudantSession

An instance of `CloudantSession` manages authentication for all requests sent to one instance of a Cloudant service.

Create the session with the host and authentication credentials.

	import Cloudant4Swift
	let credentials = CloudantCredentials(username: "blah-blah-blah-bluemix", password: "reallylong secure password")
	let session:CloudantSession = CloudantSession(host: "blah-blah-blah-bluemix", credentials: credentials)
	
For now, `CloudantSession` uses url auth, which is minimaly secure as long as you use an `https` scheme.

If you expect your credentials to change while your instance is still in use, set the `.authenticationChallengeHandler` to a closure which synchronously returns new credentials.  In the future, sessions will call this handler and attempt to re-try requets which have authentication problems before allowing authentication failures to propagate back to their completion blocks.

### Long-term auth goals

However, the long-term design is for it to manage cookie auth internally, freezing 401'd requests and re-starting them when once auth is re-established. For this reason, the `URLSessionDataTask` objects are managed internally to the session object, and each cloudant session has its own URLSession.  Unfortunately, there is an issue where the URLSessionConfiguration is backed by a non-mutable variant of a NSURLSessionConfiguration and using a custom cookie store fails.  This made testing slow, so it has been avoided for now.


# CloudantDatabase

While a Cloudant database can store a plethora of different data models, and in fact does for `_design/` documents, the nature of search indexing means most documents in a database will have a significantly similar structure.  `Cloudant4Swift` is desiged to assume that a `CloudantDatabase` instance will work with objects in a single databse with significantly similar structure, and thus are all represented by the same conrete type, conforming to the `CloduantDocument` protocol.  Thus, all its behaviors are generic with respect to the document type.  More on that below.

	struct Customer : CloudantDocument	// <- defined somewhere
	let session:CloudantSession	// <- defined somewhere
	let customerDatabase:CloudantDatabase<Customer> = session.database(named: "customers")

In this example, a database is obtained for instances of the user-defined `Customer` type in the database with the path component `customers`.  This doesn't cause any set up of the database, it's merely used to tie the name of the database with the concrete data model type.

All operations on the database happen through methods on the database.  For instance, fetching a document with a particular `_id`:

	customerDatabase.getDocument(id: "uniqueid") { (customerOrNil:Customer?) in
		if let customer:Customer = customerOrNil {
			print("customer = \(customer)")
		} else {
			print("failed!")
		}
	}

More on operations below.

# CloudantDocument

`CloudantDocument` is a protocol used to represent documents in the cloudant database.  You may use structs or classes for your concrete type.

To make `Codable` conformance as easy as possible, the protocol declares mutable `_id` and `_rev` properties, to match Cloudan't internal unique id and revision field names.  Keep in mind that you can create a concrete class for datatypes in cloudant which also conform to a protocol used for objects in other portions of your code.

To facilitate custom JSON encoding and decoding behaviors, the encoder and decoder are exposed to CloudantDocument's static `cloudantJsonDecoderConfiguration` and `cloudantJsonEncoderConfiguration`  closures.  These closures are called when the database is created, and it creates its JSONEncoder and JSONDecoder instances.  If you don't need customer modifications for a particular type, then you can simply `return nil` from these static properties.


# Operations

## Create a document

To upload a new instance of a document to the server, call `CloudantDatabase.makeDocument` with the instance of the concrete typ conforming to `CloudantDocument` associated with the database instance.  The `_id` property can be nil or non-nil, when creating a document.  If nil, one will be assigned to it.  If successful, the response in the completion handler will have a new `id` and `rev` properties.  The `rev` property should be saved on the data model instance so you can update it later, but you have to keep track of that yourself.


## Retrieve a document

To get a specific document, call `CloudantDatabase.getDocument(id:rev:_:)`, and provide a completion closure which will be called when the document is returned, or something has prevented it from being retrieved.

	customerDatabase.getDocument(id: "uniqueid") { (customerOrNil:Customer?) in
		if let customer:Customer = customerOrNil {
			print("customer = \(customer)")
		} else {
			print("failed!")
		}
	}

## Update a document

To alter a document, call the database instance's `.updateDocument` method with an instance of the document which already has the correct `_id` and `_rev` set.  If Cloudant detects that your revision is not the msot recent, the completion block will have `true` for the `conflict` (seecond) argument.


## Delete a document

To remove a document from the server, call `.deleteDocument` with the correct `id` and `rev`.  Like updating a document, the completion handler will have a `true` for the `conflict` argument if the `rev` did not match the most recent one on the server.



## Find a document

Forthcoming...

