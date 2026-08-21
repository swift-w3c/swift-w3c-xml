public import Input_Primitives

extension Input_Primitives.Input.Streaming where Self: Copyable, Element: Copyable {

    @inlinable
    @_disfavoredOverload
    package var first: Element? {
        guard !isEmpty else { return nil }
        var copy = self
        do {
            return try copy.advance()
        } catch {
            return nil
        }
    }

    @inlinable
    @_disfavoredOverload
    @discardableResult
    package mutating func removeFirst() -> Element {
        do {
            return try advance()
        } catch {
            preconditionFailure("removeFirst() on empty input — peek `first` before consuming")
        }
    }
}
