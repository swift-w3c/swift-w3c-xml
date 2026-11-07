public import Cursor
import Machine
import Parser
import Parser_Machine


extension W3C_XML.Parse {
    @usableFromInline
    struct NonEmptyTextContent<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        @usableFromInline typealias Output = String
        @usableFromInline typealias Failure = W3C_XML.Parse.Error

        @usableFromInline
        init() {}

        @usableFromInline
        func parse(_ input: inout Input) throws(Failure) -> String {
            var result: [Byte] = []
            var iterationCount = 0
            let maxIterations = 1_000_000

            while let byte = input.xmlPeek() {
                iterationCount += 1
                precondition(
                    iterationCount < maxIterations,
                    "NonEmptyTextContent: runaway loop detected"
                )

                if byte == ASCII.Code.lessThanSign.byte {

                    break
                } else if byte == ASCII.Code.ampersand.byte {

                    let resolved = try Reference<Input>().parse(&input)
                    result.append(contentsOf: resolved.utf8.map(Byte.init(bitPattern:)))
                } else {

                    let text = CharData<Input>().parse(&input)
                    if text.isEmpty {
                        break
                    }
                    result.append(contentsOf: text.utf8.map(Byte.init(bitPattern:)))
                }
            }

            guard !result.isEmpty else {
                throw .expected("text content")
            }

            return String(decoding: result, as: UTF8.self)
        }
    }
}
