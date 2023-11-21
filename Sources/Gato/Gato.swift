// The Swift Programming Language
// https://docs.swift.org/swift-book

@attached(peer, names: overloaded)
public macro Gato() = #externalMacro(module: "GatoMacros", type: "GatoMacro")
