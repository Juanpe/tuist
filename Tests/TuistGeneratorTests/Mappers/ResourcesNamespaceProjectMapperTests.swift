import Foundation
import TSCBasic
import TuistCore
import TuistSupport
import XCTest
@testable import TuistCoreTesting
@testable import TuistGenerator
@testable import TuistSupportTesting

final class ResourcesNamespaceProjectMapperTests: TuistUnitTestCase {
    private var subject: ResourcesNamespaceProjectMapper!
    private var namespaceGenerator: MockNamespaceGenerator!
    
    override func setUp() {
        super.setUp()
        
        namespaceGenerator = MockNamespaceGenerator()
        subject = ResourcesNamespaceProjectMapper(
            namespaceGenerator: namespaceGenerator
        )
    }
    
    override func tearDown() {
        super.tearDown()
        
        namespaceGenerator = nil
        subject = nil
    }
    
    func test_map() throws {
        // Given
        namespaceGenerator.renderStub = { _, paths in
            paths
                .map(\.basenameWithoutExt)
                .map { (name: $0, contents: $0) }
        }
        
        namespaceGenerator.generateNamespaceScriptStub = {
            "generate namespace"
        }
        
        let projectPath = try temporaryPath()
        let targetAPath = projectPath.appending(component: "TargetA")
        let aAssets = targetAPath.appending(component: "a.xcassets")
        let bAssets = targetAPath.appending(component: "b.xcassets")
        
        try fileHandler.createFolder(aAssets)
        try fileHandler.touch(bAssets)
        
        let targetA = Target.test(
            name: "TargetA",
            resources: [
                .folderReference(path: aAssets),
                .file(path: bAssets),
            ],
            actions: [
                TargetAction(name: "Preaction", order: .pre),
                TargetAction(name: "Postaction", order: .post),
            ]
        )
        
        let project = Project.test(
            path: projectPath,
            targets: [
                targetA,
            ]
        )
        
        // When
        let (mappedProject, sideEffects) = try subject.map(project: project)
        
        // Then
        let derivedPath = projectPath
            .appending(component: Constants.DerivedDirectory.name)
        let derivedSourcesPath = derivedPath
            .appending(component: Constants.DerivedDirectory.sources)
        
        let generateNamespaceScriptPath = derivedPath
            .appending(component: "generate_namespace.sh")
        
        XCTAssertEqual(
            sideEffects,
            [
                .file(
                    FileDescriptor(
                        path: derivedSourcesPath.appending(component: "a.swift"),
                        contents: "a".data(using: .utf8)
                    )
                ),
                .file(
                    FileDescriptor(
                        path: generateNamespaceScriptPath,
                        contents: "generate namespace".data(using: .utf8)
                    )
                ),
                .command(
                    CommandDescriptor(
                        command: "chmod", "+x", generateNamespaceScriptPath.pathString
                    )
                )
            ]
        )
        
        XCTAssertEqual(
            mappedProject,
            Project.test(
                path: projectPath,
                targets: [
                    Target.test(
                        name: targetA.name,
                        resources: targetA.resources,
                        actions: [
                            TargetAction(name: "Preaction", order: .pre),
                            TargetAction(name: "Postaction", order: .post),
                            TargetAction(
                                name: "Generate namespace",
                                order: .pre,
                                path: generateNamespaceScriptPath,
                                skipLint: true
                            )
                        ]
                    )
                ]
            )
        )
    }
}
