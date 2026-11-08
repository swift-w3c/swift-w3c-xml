import ASCII
import Byte
public import Cursor
import Parser

extension W3C_XML.Parse {
    public struct Name<Input: Cursor.`Protocol`>: Parser::Parsing, Sendable
    where Input: Sendable, Input.Element == Byte, Input.Failure == Never {
        @inlinable
        public init() {}
    }
}

extension W3C_XML.Parse.Name {
    public typealias Output = W3C_XML.Name

    public typealias Failure = W3C_XML.Parse.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var bytes: [Byte] = []

        guard let first = input.xmlPeek() else {
            throw .unexpectedEndOfInput(expected: "name")
        }

        if W3C_XML.isASCIINameStartChar(first) {
            bytes.append(try input.xmlTake(expected: "character"))
        } else {
            let scalar = try consumeUTF8Scalar(&input, bytes: &bytes, checkStart: true)
            guard W3C_XML.isNameStartChar(scalar) else {
                throw .invalidName
            }
        }

        while let byte = input.xmlPeek() {
            if W3C_XML.isASCIINameChar(byte) {
                bytes.append(try input.xmlTake(expected: "character"))
            } else if byte.bitPattern >= 0x80 {
                let savedInput = input.checkpoint
                let savedBytes = bytes
                do throws(Failure) {
                    let scalar = try consumeUTF8Scalar(&input, bytes: &bytes, checkStart: false)
                    guard W3C_XML.isNameChar(scalar) else {
                        input.seek(to: savedInput)
                        bytes = savedBytes
                        break
                    }
                } catch {
                    input.seek(to: savedInput)
                    bytes = savedBytes
                    break
                }
            } else {
                break
            }
        }

        guard !bytes.isEmpty else {
            throw .invalidName
        }

        let qualified = String(decoding: bytes, as: UTF8.self)
        return W3C_XML.Name(qualified)
    }

    @inlinable
    package func consumeUTF8Scalar(
        _ input: inout Input,
        bytes: inout [Byte],
        checkStart: Bool
    ) throws(Failure) -> Unicode.Scalar {
        guard let first = input.xmlPeek() else {
            throw .unexpectedEndOfInput(expected: "character")
        }

        let byteCount: Int
        let value: UInt32

        if first.bitPattern < 0x80 {
            bytes.append(try input.xmlTake(expected: "character"))
            return Unicode.Scalar(first.bitPattern)
        } else if first.bitPattern & 0xE0 == 0xC0 {
            byteCount = 2
            value = UInt32(first.bitPattern & 0x1F)
        } else if first.bitPattern & 0xF0 == 0xE0 {
            byteCount = 3
            value = UInt32(first.bitPattern & 0x0F)
        } else if first.bitPattern & 0xF8 == 0xF0 {
            byteCount = 4
            value = UInt32(first.bitPattern & 0x07)
        } else {
            throw .invalidName
        }

        bytes.append(try input.xmlTake(expected: "character"))
        var scalarValue = value

        for _ in 1..<byteCount {
            guard let cont = input.xmlPeek(), cont.bitPattern & 0xC0 == 0x80 else {
                throw .invalidName
            }
            scalarValue = (scalarValue << 6) | UInt32(cont.bitPattern & 0x3F)
            bytes.append(try input.xmlTake(expected: "character"))
        }

        guard let scalar = Unicode.Scalar(scalarValue) else {
            throw .invalidName
        }

        return scalar
    }
}
