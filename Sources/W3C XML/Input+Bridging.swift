public import Cursor

extension Cursor.`Protocol` where Element: Copyable & Escapable, Failure == Never {
    @inlinable
    package mutating func xmlPeek() -> Element? {
        let saved = checkpoint
        let element = next()
        seek(to: saved)
        return element
    }

    @inlinable
    package mutating func xmlTake(expected: String) throws(W3C_XML.Parse.Error) -> Element {
        guard let element = next() else {
            throw .unexpectedEndOfInput(expected: expected)
        }
        return element
    }
}
