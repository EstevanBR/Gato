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
        
        if signature.parameterClause.parameters.hasFile == false {
            signature.parameterClause.parameters.append(
                makeFileParameter(setDefaultValue: true)
            )
        }
        
        if signature.parameterClause.parameters.hasLine == false {
            signature.parameterClause.parameters.append(
                makeLineParameter(setDefaultValue: true)
            )
        }
        
        var body = funcDecl.body
        var statements = CodeBlockItemListSyntax()
        
        for statement in body?.statements ?? [] {
            guard let funcCall = statement.item.as(FunctionCallExprSyntax.self),
                  funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "XCTFail" else {
                statements.append(statement)
                continue
            }
            
            var newFuncCall = funcCall
            
            if funcCall.arguments.hasFile == false {
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
