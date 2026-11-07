public import Cursor
import Parser


extension W3C_XML.Parse {
    public struct ProcessingInstruction<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {

        public typealias Output = W3C_XML.Instruction
        public typealias Failure = W3C_XML.Parse.Error

        @inlinable
        public init() {}

        @inlinable
        public func parse(_ input: inout Input) throws(Failure) -> Output {

            try expectLiteral(&input, "<?")

            let target = try Name<Input>().parse(&input)

            if target.qualified.lowercased() == "xml" {
                throw .expected("processing instruction target (not 'xml')")
            }

            var data: String? = nil

            if let byte = input.xmlPeek(), W3C_XML.isWhitespace(byte) {
                Whitespace<Input>().parse(&input)

                var bytes: [Byte] = []

                while true {
                    guard let byte = input.xmlPeek() else {
                        throw .unexpectedEndOfInput(expected: "?>")
                    }

                    if byte == ASCII.Code.questionMark.byte {
                        _ = input.next()
                        if input.xmlPeek() == ASCII.Code.greaterThanSign.byte {
                            _ = input.next()
                            if !bytes.isEmpty {
                                data = String(decoding: bytes, as: UTF8.self)
                            }
                            return W3C_XML.Instruction(target: target.qualified, data: data)
                        }

                        bytes.append(ASCII.Code.questionMark.byte)
                        continue
                    }
                    bytes.append(try input.xmlTake(expected: "character"))
                }
            }

            try expectLiteral(&input, "?>")

            return W3C_XML.Instruction(target: target.qualified, data: nil)
        }
    }
}
