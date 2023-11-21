import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct GatoPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        GatoMacro.self,
    ]
}

public enum GatoError: CustomStringConvertible, Error {
    case onlyApplicableToFunction
    
    public var description: String {
        switch self {
        case .onlyApplicableToFunction: "@Gato can only be applied to a function"
        }
    }
}

public struct GatoMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw GatoError.onlyApplicableToFunction
        }
        
        var signature = funcDecl.signature
        
        let gatoDefaults = funcDecl.gatoDefaults
        if signature.parameterClause.parameters.hasFile == false {
            if var lastParam = signature.parameterClause.parameters.last {
                signature.parameterClause.parameters = FunctionParameterListSyntax(signature.parameterClause.parameters.dropLast())
                lastParam.trailingComma = .commaToken()
                signature.parameterClause.parameters.append(lastParam)
                
            }
            signature.parameterClause.parameters.append(
                makeFileParameter(setDefaultValue: gatoDefaults)
            )
        }
        
        if signature.parameterClause.parameters.hasLine == false {
            signature.parameterClause.parameters.append(
                makeLineParameter(setDefaultValue: gatoDefaults)
            )
        }
        
        var body = funcDecl.body
        var statements = CodeBlockItemListSyntax()
        
        for statement in body?.statements ?? [] {
            guard let funcCall = statement.item.as(FunctionCallExprSyntax.self),
                  let funcName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
                  fileLineFunctionNames.contains(funcName) else {
                statements.append(statement)
                continue
            }
            
            var newFuncCall = funcCall
            
            if funcCall.arguments.hasFile == false {
                if var previousArgument = funcCall.arguments.last {
                    previousArgument.trailingComma = .commaToken()
                    newFuncCall.arguments = LabeledExprListSyntax(newFuncCall.arguments.dropLast())
                    newFuncCall.arguments.append(previousArgument)
                }
                newFuncCall.arguments.append(
                    .init(
                        label: .init(stringLiteral: "file"),
                        colon: .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .init(stringLiteral: "file")),
                        trailingComma: .commaToken()
                    )
                )
            }
            
            if funcCall.arguments.hasLine == false {
                newFuncCall.arguments.append(
                    .init(
                        label: .init(stringLiteral: "line"),
                        colon: .colonToken(),
                        expression: DeclReferenceExprSyntax(baseName: .init(stringLiteral: "line"))
                    )
                )
            }
            
            guard let item = newFuncCall.as(CodeBlockItemSyntax.Item.self) else { continue }
            
            statements.append(CodeBlockItemSyntax(item: item))
        }
        
        body?.statements = statements
        
        return [
            DeclSyntax(
                FunctionDeclSyntax(
                    name: funcDecl.name,
                    signature: signature,
                    body: body
                )
            )
        ]
    }
}

// TODO: XCTSkip.init(String?, file: StaticString, line: UInt

private let fileLineFunctionNames: Set<String> = [
    // Boolean Assertions - https://developer.apple.com/documentation/xctest/boolean_assertions
    "XCTAssert",
    "XCTAssertTrue",
    "XCTAssertFalse",
    
    // Nil and Non-Nil Assertions - https://developer.apple.com/documentation/xctest/nil_and_non-nil_assertions
    "XCTAssertNil",
    "XCTAssertNotNil",
    "XCTUnwrap",
    
    // Equality and Inequality Assertions - https://developer.apple.com/documentation/xctest/equality_and_inequality_assertions
    "XCTAssertEqual",
    "XCTAssertNotEqual",
    "XCTAssertIdentical",
    "XCTAssertNotIdentical",
    
    // Comparable Value Assertions - https://developer.apple.com/documentation/xctest/comparable_value_assertions
    "XCTAssertGreaterThan",
    "XCTAssertGreaterThanOrEqual",
    "XCTAssertLessThanOrEqual",
    "XCTAssertLessThan",
    
    // Error Assertions - https://developer.apple.com/documentation/xctest/error_assertions
    "XCTAssertThrowsError",
    "XCTAssertNoThrow",
    
    // Unconditional Test Failures - https://developer.apple.com/documentation/xctest/unconditional_test_failures
    "XCTFail",
    
    // Methods for Skipping Tests - https://developer.apple.com/documentation/xctest/methods_for_skipping_tests
    "XCTSkipIf",
    "XCTSkipUnless"
]

private extension FunctionParameterListSyntax {
    var hasFile: Bool {
        !allSatisfy { $0.firstName != "file" }
    }
    
    var hasLine: Bool {
        !allSatisfy { $0.firstName != "line" }
    }
}

private extension LabeledExprListSyntax {
    var hasFile: Bool {
        !allSatisfy { $0.label != "file" }
    }
    
    var hasLine: Bool {
        !allSatisfy { $0.label != "line" }
    }
}

private extension FunctionDeclSyntax {
    var gatoDefaults: Bool {
        guard let gatoAttribute = attributes
            .first (where: {
                $0.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "Gato"
            })?
            .as(AttributeSyntax.self) else {
            return true
        }
        
        guard let defaultsArgument = gatoAttribute
                .arguments?
                .as(LabeledExprListSyntax.self)?
                .compactMap({ $0.as(LabeledExprSyntax.self) })
                .first(where: { $0.label?.text == "defaults" }),
              let useDefaultsString = defaultsArgument
                .expression
                .as(BooleanLiteralExprSyntax.self)?
                .literal.text else {
            return true
        }
        return Bool(useDefaultsString) ?? true
    }
}

private func makeFileParameter(setDefaultValue: Bool) -> FunctionParameterSyntax {
    FunctionParameterSyntax(
        firstName: "file",
        type: IdentifierTypeSyntax(
            name: .init(stringLiteral: "StaticString")
        ),
        defaultValue: setDefaultValue ? .init(
            value: MacroExpansionExprSyntax(
                macroName: .identifier("file"),
                arguments: .init()
            )
        ) : nil,
        trailingComma: TokenSyntax(.comma, presence: .present)
    )
}

private func makeLineParameter(setDefaultValue: Bool) -> FunctionParameterSyntax {
    FunctionParameterSyntax(
        firstName: "line",
        type: IdentifierTypeSyntax(
            name: .init(stringLiteral: "UInt")
        ),
        defaultValue: setDefaultValue ? .init(
            value: MacroExpansionExprSyntax(
                macroName: .identifier("line"),
                arguments: .init()
            )
        ) : nil
    )
}
