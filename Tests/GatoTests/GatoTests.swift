import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import GatoMacros

private let testMacros: [String: Macro.Type] = [
    "Gato": GatoMacro.self,
]

final class GatoTests: XCTestCase {
    func testGatoMacroWithDefaults() throws {
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
    
    func testGatoMacroWithXCTAssertEquals() throws {
        assertMacroExpansion(
            """
            @Gato
            func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
                XCTAssertEquals(a, b)
            }
            """
            ,
            expandedSource: """
                func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool) {
                    XCTAssertEquals(a, b)
                }

                func expectEqualWithFileAndLine(_ a: Bool, _ b: Bool, file: StaticString = #file, line: UInt = #line) {
                    XCTAssertEquals(a, b, file: file, line: line)
                }
                """
            ,
            macros: testMacros
        )
    }
    
    func testGatoMacroWithoutDefaultsTrue() throws {
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
    
    func testGatoMacroWithoutDefaultsFalse() throws {
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
}
