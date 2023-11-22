import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import GatoMacros

private let testMacros: [String: Macro.Type] = [
    "Gato": GatoMacro.self,
]

final class GatoTests: XCTestCase {
    func testGatoMacroWithoutPrivateAndNoDefaults() throws {
        assertMacroExpansion(
            """
            @Gato
            func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                func failWithFileAndLine() {
                    XCTFail()
                }
                """
            ,
            diagnostics: [
                .init(message: "@Gate can only be applied to a `private` function", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testGatoMacroWithPrivateFuncAndXCTFailAndNoDefaults() throws {
        assertMacroExpansion(
            """
            @Gato
            private func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                private func failWithFileAndLine() {
                    XCTFail()
                }
                
                func failWithFileAndLine(file: StaticString = #file, line: UInt = #line) {
                    XCTFail(file: file, line: line)
                }
                """
            ,
            macros: testMacros
        )
    }
    
    func testGatoMacroWithXCTAssertEqualAndNoDefaults() throws {
        assertMacroExpansion(
            """
            @Gato
            private func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
                XCTAssertEqual(a, b)
            }
            """
            ,
            expandedSource: """
                private func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
                    XCTAssertEqual(a, b)
                }

                func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool, file: StaticString = #file, line: UInt = #line) {
                    XCTAssertEqual(a, b, file: file, line: line)
                }
                """
            ,
            macros: testMacros
        )
    }
    
    func testGatoMacroWithXCTFailAndDefaultsFalse() throws {
        assertMacroExpansion(
            """
            @Gato(defaults: false)
            private func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                private func failWithFileAndLine() {
                    XCTFail()
                }

                func failWithFileAndLine(file: StaticString, line: UInt) {
                    XCTFail(file: file, line: line)
                }
                """
            ,
            macros: testMacros
        )
    }
    
    func testGatoMacroWithXCTFailAndDefaultsTrue() throws {
        assertMacroExpansion(
            """
            @Gato(defaults: true)
            private func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                private func failWithFileAndLine() {
                    XCTFail()
                }

                func failWithFileAndLine(file: StaticString = #file, line: UInt = #line) {
                    XCTFail(file: file, line: line)
                }
                """
            ,
            macros: testMacros
        )
    }
    
    func testGatoGreeting() throws {
        assertMacroExpansion(
            """
            struct GatoGreeting {
                @Gato(defaults: true)
                private func printGatoFunc(_ message: String) {
                    XCTAssertEqual(message)
                    print("do something else")
                }
            }
            """,
            expandedSource:
            """
            struct GatoGreeting {
                private func printGatoFunc(_ message: String) {
                    XCTAssertEqual(message)
                    print("do something else")
                }

                func printGatoFunc(_ message: String, file: StaticString = #file, line: UInt = #line) {
                        XCTAssertEqual(message, file: file, line: line)
                        print("do something else")
                    }
            }
            """,
            macros: testMacros
        )
    }
    
    func testGatoMemoryLeakTracker() throws {
//        throw XCTSkip("not implemented")
        assertMacroExpansion(
"""
extension XCTestCase {
    @Gato(defaults: true)
    private func trackForMemoryLeaks(_ instance: AnyObject) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.")
        }
    }
}
"""
            ,
            expandedSource:
"""
extension XCTestCase {
    private func trackForMemoryLeaks(_ instance: AnyObject) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.")
        }
    }

    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
            addTeardownBlock { [weak instance] in
                XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
            }
        }
}
"""
            ,
            macros: testMacros
        )
    }

    func testGatoMacroWithGenericFunction() throws {
        assertMacroExpansion(
"""
extension UIResponder {
    @Gato(defaults: false)
    private func findChild<Success: UIAccessibilityIdentification>(withA11yId a11y: String) throws -> Success {
        let child = Mirror(reflecting: self).children.compactMap { $0.value as? Success }.first { $0.accessibilityIdentifier == a11y }
        return try XCTUnwrap(child, "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)")
    }
}
"""
            ,
            expandedSource:
"""
extension UIResponder {
    private func findChild<Success: UIAccessibilityIdentification>(withA11yId a11y: String) throws -> Success {
        let child = Mirror(reflecting: self).children.compactMap { $0.value as? Success }.first { $0.accessibilityIdentifier == a11y }
        return try XCTUnwrap(child, "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)")
    }

    func findChild<Success: UIAccessibilityIdentification>(withA11yId a11y: String, file: StaticString, line: UInt) throws -> Success {
            let child = Mirror(reflecting: self).children.compactMap {
                $0.value as? Success
            } .first {
                $0.accessibilityIdentifier == a11y
            }
            return try XCTUnwrap(child, "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)", file: file, line: line)
        }
}
"""
            ,
            macros: testMacros
        )
    }
}
