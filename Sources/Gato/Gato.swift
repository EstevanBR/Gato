// The Swift Programming Language
// https://docs.swift.org/swift-book

//public enum GatoScope: String {
//    case `fileprivate`
//    case `private`
//    case `internal`
//    case `public`
//    case `open`
//}
@attached(peer, names: overloaded)
public macro Gato(defaults: Bool = true) = #externalMacro(module: "GatoMacros", type: "GatoMacro")
