// swift-tools-version:4.0
import PackageDescription
let package = Package(
	name: "Cloudant4Swift",
	products: [
		.library(
			name: "Cloudant4Swift",
			targets: ["Cloudant4Swift"]),
		],
	dependencies:[
		.package(url:"https://github.com/benspratling4/SwiftPatterns.git", from:"2.0.0")
	],
	targets:[
		.target(
			name: "Cloudant4Swift",
			dependencies: ["SwiftPatterns"])
		,.testTarget(
		name:"Cloudant4SwiftTests"
		,dependencies:["Cloudant4Swift"]
		)
		],
	swiftLanguageVersions:[4]
)
