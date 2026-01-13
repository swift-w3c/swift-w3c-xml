/// W3C XML 1.0 (Fifth Edition) - Extensible Markup Language
///
/// This module implements XML parsing and encoding as specified in W3C XML 1.0.
/// XML provides a structured markup language for documents and data interchange.
///
/// ## Key Concepts
///
/// - **Document**: An XML document with declaration, optional doctype, and root element
/// - **Element**: A named container with attributes and content
/// - **Content**: Element children, text, CDATA, comments, or processing instructions
/// - **Namespace**: XML Namespaces per W3C specification
///
/// ## Example Usage
///
/// ```swift
/// // Parse XML
/// let doc = try W3C_XML.parse("""
///     <?xml version="1.0" encoding="UTF-8"?>
///     <root>
///         <item id="1">First</item>
///         <item id="2">Second</item>
///     </root>
///     """)
///
/// // Access elements
/// print(doc.root.name.local)  // "root"
/// print(doc.root.content.count)  // 2 elements
///
/// // Encode XML
/// let bytes = doc.encode()
/// ```
///
/// ## W3C XML 1.0 Compliance
///
/// This implementation follows W3C XML 1.0 (Fifth Edition):
/// - Well-formedness validation
/// - Namespace support (XML Namespaces 1.0)
/// - Entity reference handling (predefined + numeric)
/// - Depth limiting prevents stack overflow
///
/// ## Reference
///
/// - W3C XML 1.0 (Fifth Edition): https://www.w3.org/TR/xml/
/// - XML Namespaces 1.0: https://www.w3.org/TR/xml-names/
public enum W3C_XML {}

// MARK: - XML Whitespace (Production [3])

extension W3C_XML {
    /// Whitespace bytes permitted in XML content.
    ///
    /// Per W3C XML 1.0 Section 2.3, Production [3]:
    /// ```
    /// S ::= (#x20 | #x9 | #xD | #xA)+
    /// ```
    ///
    /// Space (0x20), Tab (0x09), Carriage Return (0x0D), Line Feed (0x0A).
    @usableFromInline
    static let whitespace: Set<UInt8> = [
        .ascii.sp,      // Space (0x20)
        .ascii.htab,    // Horizontal tab (0x09)
        .ascii.cr,      // Carriage return (0x0D)
        .ascii.lf,      // Line feed (0x0A)
    ]

    /// Returns true if the byte is XML whitespace.
    @inlinable
    public static func isWhitespace(_ byte: UInt8) -> Bool {
        whitespace.contains(byte)
    }
}

// MARK: - XML Name Characters (Productions [4], [4a], [5])

extension W3C_XML {
    /// Returns true if the Unicode scalar is a valid XML NameStartChar.
    ///
    /// Per W3C XML 1.0, Production [4]:
    /// ```
    /// NameStartChar ::= ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] |
    ///                   [#xF8-#x2FF] | [#x370-#x37D] | [#x37F-#x1FFF] |
    ///                   [#x200C-#x200D] | [#x2070-#x218F] | [#x2C00-#x2FEF] |
    ///                   [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD] |
    ///                   [#x10000-#xEFFFF]
    /// ```
    @inlinable
    public static func isNameStartChar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return v == 0x3A ||                     // ":"
               (v >= 0x41 && v <= 0x5A) ||      // [A-Z]
               v == 0x5F ||                     // "_"
               (v >= 0x61 && v <= 0x7A) ||      // [a-z]
               (v >= 0xC0 && v <= 0xD6) ||
               (v >= 0xD8 && v <= 0xF6) ||
               (v >= 0xF8 && v <= 0x2FF) ||
               (v >= 0x370 && v <= 0x37D) ||
               (v >= 0x37F && v <= 0x1FFF) ||
               (v >= 0x200C && v <= 0x200D) ||
               (v >= 0x2070 && v <= 0x218F) ||
               (v >= 0x2C00 && v <= 0x2FEF) ||
               (v >= 0x3001 && v <= 0xD7FF) ||
               (v >= 0xF900 && v <= 0xFDCF) ||
               (v >= 0xFDF0 && v <= 0xFFFD) ||
               (v >= 0x10000 && v <= 0xEFFFF)
    }

    /// Returns true if the Unicode scalar is a valid XML NameChar.
    ///
    /// Per W3C XML 1.0, Production [4a]:
    /// ```
    /// NameChar ::= NameStartChar | "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
    /// ```
    @inlinable
    public static func isNameChar(_ scalar: Unicode.Scalar) -> Bool {
        if isNameStartChar(scalar) { return true }
        let v = scalar.value
        return v == 0x2D ||                     // "-"
               v == 0x2E ||                     // "."
               (v >= 0x30 && v <= 0x39) ||      // [0-9]
               v == 0xB7 ||                     // middle dot
               (v >= 0x0300 && v <= 0x036F) ||  // combining diacritical marks
               (v >= 0x203F && v <= 0x2040)     // undertie, character tie
    }

    /// Returns true if the byte is a valid ASCII NameStartChar (fast path).
    @inlinable
    public static func isASCIINameStartChar(_ byte: UInt8) -> Bool {
        byte == .ascii.colon ||
        (byte >= .ascii.A && byte <= .ascii.Z) ||
        byte == .ascii.underline ||
        (byte >= .ascii.a && byte <= .ascii.z)
    }

    /// Returns true if the byte is a valid ASCII NameChar (fast path).
    @inlinable
    public static func isASCIINameChar(_ byte: UInt8) -> Bool {
        isASCIINameStartChar(byte) ||
        byte == .ascii.hyphen ||
        byte == .ascii.period ||
        (byte >= .ascii.`0` && byte <= .ascii.`9`)
    }
}

// MARK: - XML Char (Production [2])

extension W3C_XML {
    /// Returns true if the Unicode scalar is a valid XML Char.
    ///
    /// Per W3C XML 1.0, Production [2]:
    /// ```
    /// Char ::= #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
    /// ```
    @inlinable
    public static func isChar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return v == 0x09 ||
               v == 0x0A ||
               v == 0x0D ||
               (v >= 0x20 && v <= 0xD7FF) ||
               (v >= 0xE000 && v <= 0xFFFD) ||
               (v >= 0x10000 && v <= 0x10FFFF)
    }
}
