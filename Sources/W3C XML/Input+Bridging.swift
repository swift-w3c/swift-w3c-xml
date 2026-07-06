// Input+Bridging.swift
// swift-w3c-xml
//
// Bridging extensions for Input.Streaming to provide `first` and `removeFirst()`
// convenience methods used throughout the XML parser codebase.

// `public import`: the `first` / `removeFirst` bridging members below are
// `@inlinable`, so the `Input.Streaming` protocol and its `Element` associated
// type they reference must be visible at the inlinable surface — an internal
// import leaves them internal-only ([MemberImportVisibility]).
public import Input_Primitives

// MARK: - first / removeFirst bridging

extension Input_Primitives.Input.Streaming where Self: Copyable, Element: Copyable {
    /// Peeks at the next element without consuming it.
    ///
    /// Returns `nil` if the input is empty. This creates a temporary copy
    /// of the cursor to peek without modifying the original position.
    @inlinable
    @_disfavoredOverload
    internal var first: Element? {
        guard !isEmpty else { return nil }
        var copy = self
        return try? copy.advance()
    }

    /// Consumes and returns the next element.
    ///
    /// - Precondition: The input must not be empty.
    @inlinable
    @_disfavoredOverload
    @discardableResult
    internal mutating func removeFirst() -> Element {
        try! advance()
    }
}
