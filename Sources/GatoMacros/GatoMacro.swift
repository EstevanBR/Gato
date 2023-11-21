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
    case onlyApplicableToPrivateFunction
    case fileArgumentExists
    case lineArgumentExists
    
    public var description: String {
        switch self {
        case .onlyApplicableToFunction: "@Gato can only be applied to a function"
        case .onlyApplicableToPrivateFunction: "@Gate can only be applied to a `private` function"
        case .fileArgumentExists: "@Gato requires no `file` argument in the function"
        case .lineArgumentExists: "@Gato requires no `line` argument in the function"
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
        
        guard let _ = funcDecl.modifiers.first(where: { $0.name.text == "private" }) else {
            throw GatoError.onlyApplicableToPrivateFunction
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
            if let funcCall = statement.item.as(FunctionCallExprSyntax.self),
               let funcName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
               fileLineFunctionNames.contains(funcName) {
                try addFileLine(funcCall: funcCall, statements: &statements)
            } else
            
            if let funcCall = statement.item.as(TryExprSyntax.self)?.expression.as(FunctionCallExprSyntax.self),
               let funcName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
               fileLineFunctionNames.contains(funcName) {
                statements.append(statement)
                try addFileLine(funcCall: funcCall, statements: &statements)
            } else
            
            if let funcCall = statement.item.as(ReturnStmtSyntax.self)?.expression?.as(FunctionCallExprSyntax.self),
               let funcName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
               fileLineFunctionNames.contains(funcName) {
                statements.append(statement)
                try addFileLine(funcCall: funcCall, statements: &statements)
            } else
            
            if let funcCall = statement.item.as(ReturnStmtSyntax.self)?.expression?.as(TryExprSyntax.self)?.expression.as(FunctionCallExprSyntax.self),
               let funcName = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
               fileLineFunctionNames.contains(funcName) {
                statements.append(statement)
                try addFileLine(funcCall: funcCall, statements: &statements)
            } else {
                statements.append(statement)
            }
        }
        
        body?.statements = statements
        
        return [
            DeclSyntax(
                FunctionDeclSyntax(
                    name: funcDecl.name,
                    genericParameterClause: funcDecl.genericParameterClause,
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

private func makeFileArgument() -> LabeledExprSyntax {
    .init(
        label: .init(stringLiteral: "file"),
        colon: .colonToken(),
        expression: DeclReferenceExprSyntax(baseName: .init(stringLiteral: "file")),
        trailingComma: .commaToken()
    )
}

private func makeLineArgument() -> LabeledExprSyntax {
    .init(
        label: .init(stringLiteral: "line"),
        colon: .colonToken(),
        expression: DeclReferenceExprSyntax(baseName: .init(stringLiteral: "line"))
    )
}

private func addFileLine(funcCall: FunctionCallExprSyntax, statements: inout CodeBlockItemListSyntax) throws {
    var newFuncCall = funcCall
    
    guard funcCall.arguments.hasFile == false else {
        throw GatoError.fileArgumentExists
    }
    
    guard funcCall.arguments.hasLine == false else {
        throw GatoError.lineArgumentExists
    }
    
    if var previousArgument = funcCall.arguments.last {
        previousArgument.trailingComma = .commaToken()
        newFuncCall.arguments = LabeledExprListSyntax(newFuncCall.arguments.dropLast())
        newFuncCall.arguments.append(previousArgument)
    }
    
    newFuncCall.arguments.append(makeFileArgument())
    newFuncCall.arguments.append(makeLineArgument())
    
    guard let item = newFuncCall.as(CodeBlockItemSyntax.Item.self) else { return }
    
    statements.append(CodeBlockItemSyntax(item: item))
}
