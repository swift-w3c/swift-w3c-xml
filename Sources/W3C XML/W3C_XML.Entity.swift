/// W3C_XML.Entity.swift
/// swift-w3c-xml
///
/// XML Entity reference handling

extension W3C_XML {
    /// XML entity reference utilities.
    ///
    /// Per W3C XML 1.0 Section 4.6, there are five predefined entities:
    /// - `&lt;` → `<`
    /// - `&gt;` → `>`
    /// - `&amp;` → `&`
    /// - `&apos;` → `'`
    /// - `&quot;` → `"`
    ///
    /// Additionally, numeric character references are supported:
    /// - `&#60;` → decimal character reference
    /// - `&#x3C;` → hexadecimal character reference
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Resolve predefined entity
    /// let char = W3C_XML.Entity.predefined("lt")  // Unicode.Scalar("<")
    ///
    /// // Resolve numeric reference
    /// let decimal = W3C_XML.Entity.numeric("60")     // Unicode.Scalar("<")
    /// let hex = W3C_XML.Entity.numeric("x3C")        // Unicode.Scalar("<")
    /// ```
    ///
    /// ## Note
    ///
    /// This implementation does not support custom entity declarations from DTDs.
    /// External entities are not resolved (security).
    public enum Entity {}
}

// MARK: - Predefined Entities

extension W3C_XML.Entity {
    /// Resolves a predefined entity name to its Unicode scalar.
    ///
    /// Per W3C XML 1.0 Section 4.6, the predefined entities are:
    /// - `lt` → U+003C `<`
    /// - `gt` → U+003E `>`
    /// - `amp` → U+0026 `&`
    /// - `apos` → U+0027 `'`
    /// - `quot` → U+0022 `"`
    ///
    /// - Parameter name: The entity name (without `&` and `;`).
    /// - Returns: The Unicode scalar, or nil if not a predefined entity.
    @inlinable
    public static func predefined(_ name: String) -> Unicode.Scalar? {
        switch name {
        case "lt":   return Unicode.Scalar(0x3C)    // <
        case "gt":   return Unicode.Scalar(0x3E)    // >
        case "amp":  return Unicode.Scalar(0x26)    // &
        case "apos": return Unicode.Scalar(0x27)    // '
        case "quot": return Unicode.Scalar(0x22)    // "
        default:     return nil
        }
    }

    /// Resolves a numeric character reference to its Unicode scalar.
    ///
    /// Supports both decimal (`60`) and hexadecimal (`x3C` or `X3C`) formats.
    ///
    /// - Parameter reference: The reference string (without `&#` prefix and `;` suffix).
    /// - Returns: The Unicode scalar, or nil if invalid.
    @inlinable
    public static func numeric(_ reference: String) -> Unicode.Scalar? {
        guard !reference.isEmpty else { return nil }

        let codePoint: UInt32?

        if reference.hasPrefix("x") || reference.hasPrefix("X") {
            // Hexadecimal: &#xHHHH;
            let hex = String(reference.dropFirst())
            codePoint = UInt32(hex, radix: 16)
        } else {
            // Decimal: &#DDDD;
            codePoint = UInt32(reference, radix: 10)
        }

        guard let value = codePoint else { return nil }

        // Validate against XML Char production
        // Production [2]: Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
        guard value == 0x09 ||
              value == 0x0A ||
              value == 0x0D ||
              (value >= 0x20 && value <= 0xD7FF) ||
              (value >= 0xE000 && value <= 0xFFFD) ||
              (value >= 0x10000 && value <= 0x10FFFF) else {
            return nil
        }

        return Unicode.Scalar(value)
    }
}

// MARK: - Entity Escaping

extension W3C_XML.Entity {
    /// Characters that must be escaped in XML text content.
    ///
    /// - `<` must always be escaped (would start a tag)
    /// - `&` must always be escaped (would start an entity reference)
    public static let textEscapeRequired: Set<Character> = ["<", "&"]

    /// Characters that must be escaped in XML attribute values.
    ///
    /// In addition to text escapes:
    /// - `"` must be escaped in double-quoted attributes
    /// - `'` must be escaped in single-quoted attributes
    /// - `<` must be escaped (would start a tag)
    public static let attributeEscapeRequired: Set<Character> = ["<", "&", "\"", "'"]

    /// Escapes a string for use as XML text content.
    ///
    /// - Parameter text: The text to escape.
    /// - Returns: The escaped text.
    @inlinable
    public static func escapeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for char in text {
            switch char {
            case "<":
                result += "&lt;"
            case "&":
                result += "&amp;"
            default:
                result.append(char)
            }
        }

        return result
    }

    /// Escapes a string for use as an XML attribute value.
    ///
    /// - Parameters:
    ///   - value: The attribute value to escape.
    ///   - quote: The quote character used (default double quote).
    /// - Returns: The escaped value.
    @inlinable
    public static func escapeAttribute(_ value: String, quote: Character = "\"") -> String {
        var result = ""
        result.reserveCapacity(value.count)

        for char in value {
            switch char {
            case "<":
                result += "&lt;"
            case "&":
                result += "&amp;"
            case "\"" where quote == "\"":
                result += "&quot;"
            case "'" where quote == "'":
                result += "&apos;"
            default:
                result.append(char)
            }
        }

        return result
    }
}
