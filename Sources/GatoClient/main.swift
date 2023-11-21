import Gato

func XCTAssertEqual(_ message: String, file: StaticString = #file, line: UInt = #line) {
    print("\(message)\n\t\(file):\(line)")
}

struct GatoGreeting {
    @Gato(defaults: true)
    private func printGatoFunc(_ message: String) {
        XCTAssertEqual(message)
        print("Meow")
    }
}

GatoGreeting().printGatoFunc("Gato where are you?")
GatoGreeting().printGatoFunc("Here!")
