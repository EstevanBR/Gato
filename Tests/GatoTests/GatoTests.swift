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
}
