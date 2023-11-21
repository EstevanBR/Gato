import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import GatoMacros

private let testMacros: [String: Macro.Type] = [
    "Gato": GatoMacro.self,
]

final class GatoTests: XCTestCase {
    func testGatoMacroWithXCTFailAndNoDefaults() throws {
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
            func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
                XCTAssertEqual(a, b)
            }
            """
            ,
            expandedSource: """
                func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
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
            func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                func failWithFileAndLine() {
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
            func failWithFileAndLine() {
                XCTFail()
            }
            """
            ,
            expandedSource: """
                func failWithFileAndLine() {
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
    
    func testGatoMacroWithGenericFunction() throws {
        assertMacroExpansion(
            """
            extension UIResponder {
                @Gato(defaults: false)
                func findChild<Success: UIAccessibilityIdentification>(
                    withA11yId a11y: String
                ) throws -> Success {
                    let child = Mirror(reflecting: self)
                        .children
                        .compactMap { $0.value as? Success }
                        .first { $0.accessibilityIdentifier == a11y }
                    
                    return try XCTUnwrap(
                        child,
                        "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)"
                    )
                }
            }
            """,
            expandedSource: """
            extension UIResponder {
                func findChild<Success: UIAccessibilityIdentification>(
                    withA11yId a11y: String
                ) throws -> Success {
                    let child = Mirror(reflecting: self)
                        .children
                        .compactMap { $0.value as? Success }
                        .first { $0.accessibilityIdentifier == a11y }
                    
                    return try XCTUnwrap(
                        child,
                        "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)"
                    )
                }

                func findChild<Success: UIAccessibilityIdentification>(
                    withA11yId a11y: String, file: StaticString, line: UInt
                ) throws -> Success {
                    let child = Mirror(reflecting: self)
                        .children
                        .compactMap { $0.value as? Success }
                        .first { $0.accessibilityIdentifier == a11y }
                    
                    return try XCTUnwrap(
                        child,
                        "Did not find element of type: \\(Success.self) with accessibility identifier: \\(a11y)", file: file, line: line
                    )
                }
            }
            """,
            macros: testMacros
        )
    }
}
