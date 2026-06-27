/// W3C_XML.Encode.swift
/// swift-w3c-xml
///
/// XML encoding (Document/Element → bytes)

extension W3C_XML {
    /// Encodes an XML document to UTF-8 bytes.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let doc: W3C_XML.Document = ...
    ///
    /// // Compact encoding
    /// let bytes = doc.encode()
    ///
    /// // Pretty-printed
    /// let pretty = doc.encode(options: .init(prettyPrint: true))
    ///
    /// // Encode into existing buffer
    /// var buffer: [UInt8] = []
    /// doc.encode(into: &buffer)
    /// ```
    public struct Encode: Sendable {
        /// The document to encode.
        public let document: Document

        @usableFromInline
        internal init(_ document: Document) {
            self.document = document
        }

        /// Encodes the document to a byte array.
        ///
        /// - Parameter options: Encoding options.
        /// - Returns: UTF-8 encoded XML bytes.
        @inlinable
        public func callAsFunction(options: Options = Options()) -> [UInt8] {
            var buffer: [UInt8] = []
            callAsFunction(into: &buffer, options: options)
            return buffer
        }

        /// Encodes the document into an existing buffer.
        ///
        /// - Parameters:
        ///   - buffer: The buffer to append to.
        ///   - options: Encoding options.
        @inlinable
        public func callAsFunction<Buffer: RangeReplaceableCollection>(
            into buffer: inout Buffer,
            options: Options = Options()
        ) where Buffer.Element == UInt8 {
            var encoder = Encoder(options: options)
            encoder.encode(document, into: &buffer)
        }
    }
}

// MARK: - Encode Options

extension W3C_XML {
    /// Options for XML encoding.
    public struct Options: Sendable {
        /// Whether to format with indentation and newlines.
        public var prettyPrint: Bool

        /// Indentation string (used when prettyPrint is true).
        public var indent: String

        /// Whether to include XML declaration.
        public var includeDeclaration: Bool

        /// Whether to escape ' as &apos; in attribute values.
        public var escapeApostrophe: Bool

        /// Creates default encoding options.
        public init(
            prettyPrint: Bool = false,
            indent: String = "  ",
            includeDeclaration: Bool = true,
            escapeApostrophe: Bool = false
        ) {
            self.prettyPrint = prettyPrint
            self.indent = indent
            self.includeDeclaration = includeDeclaration
            self.escapeApostrophe = escapeApostrophe
        }
    }
}

// MARK: - Internal Encoder

extension W3C_XML {
    /// Internal encoder state.
    @usableFromInline
    internal struct Encoder {
        @usableFromInline
        let options: Options

        @usableFromInline
        var depth: Int = 0

        @usableFromInline
        init(options: Options) {
            self.options = options
        }
    }
}

extension W3C_XML.Encoder {
    /// Encodes a document into the buffer.
    @inlinable
    mutating func encode<Buffer: RangeReplaceableCollection>(
        _ document: W3C_XML.Document,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // XML declaration
        if options.includeDeclaration, let decl = document.declaration {
            encodeDeclaration(decl, into: &buffer)
            if options.prettyPrint {
                buffer.append(ASCII.Code.lf.byte.underlying)
            }
        }

        // DOCTYPE
        if let doctype = document.doctype {
            encodeDoctype(doctype, into: &buffer)
            if options.prettyPrint {
                buffer.append(ASCII.Code.lf.byte.underlying)
            }
        }

        // Prologue PIs
        for instruction in document.prologue {
            encodeInstruction(instruction, into: &buffer)
            if options.prettyPrint {
                buffer.append(ASCII.Code.lf.byte.underlying)
            }
        }

        // Root element
        encodeElement(document.root, into: &buffer)

        // Epilogue
        for content in document.epilogue {
            if options.prettyPrint {
                buffer.append(ASCII.Code.lf.byte.underlying)
            }
            encodeContent(content, into: &buffer)
        }
    }

    /// Encodes an XML declaration.
    @inlinable
    mutating func encodeDeclaration<Buffer: RangeReplaceableCollection>(
        _ decl: W3C_XML.Declaration,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: [ASCII.Code.lessThanSign.byte.underlying, ASCII.Code.questionMark.byte.underlying])  // <?
        buffer.append(contentsOf: Swift.Array("xml".utf8))

        buffer.append(contentsOf: Swift.Array(" version=\"".utf8))
        buffer.append(contentsOf: Swift.Array(decl.version.rawValue.utf8))
        buffer.append(ASCII.Code.quotationMark.byte.underlying)

        if let encoding = decl.encoding {
            buffer.append(contentsOf: Swift.Array(" encoding=\"".utf8))
            buffer.append(contentsOf: Swift.Array(encoding.utf8))
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        }

        if let standalone = decl.standalone {
            buffer.append(contentsOf: Swift.Array(" standalone=\"".utf8))
            buffer.append(contentsOf: Swift.Array((standalone ? "yes" : "no").utf8))
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        }

        buffer.append(contentsOf: [ASCII.Code.questionMark.byte.underlying, ASCII.Code.greaterThanSign.byte.underlying])  // ?>
    }

    /// Encodes a DOCTYPE declaration.
    @inlinable
    mutating func encodeDoctype<Buffer: RangeReplaceableCollection>(
        _ doctype: W3C_XML.Doctype,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: Swift.Array("<!DOCTYPE ".utf8))
        buffer.append(contentsOf: Swift.Array(doctype.name.utf8))

        if let publicID = doctype.publicID, let systemID = doctype.systemID {
            buffer.append(contentsOf: Swift.Array(" PUBLIC \"".utf8))
            buffer.append(contentsOf: Swift.Array(publicID.utf8))
            buffer.append(contentsOf: Swift.Array("\" \"".utf8))
            buffer.append(contentsOf: Swift.Array(systemID.utf8))
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        } else if let systemID = doctype.systemID {
            buffer.append(contentsOf: Swift.Array(" SYSTEM \"".utf8))
            buffer.append(contentsOf: Swift.Array(systemID.utf8))
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        }

        if let internalSubset = doctype.internalSubset {
            buffer.append(contentsOf: Swift.Array(" [".utf8))
            buffer.append(contentsOf: Swift.Array(internalSubset.utf8))
            buffer.append(ASCII.Code.rightBracket.byte.underlying)
        }

        buffer.append(ASCII.Code.greaterThanSign.byte.underlying)
    }

    /// Encodes a processing instruction.
    @inlinable
    mutating func encodeInstruction<Buffer: RangeReplaceableCollection>(
        _ instruction: W3C_XML.Instruction,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: [ASCII.Code.lessThanSign.byte.underlying, ASCII.Code.questionMark.byte.underlying])  // <?
        buffer.append(contentsOf: Swift.Array(instruction.target.utf8))

        if let data = instruction.data {
            buffer.append(ASCII.Code.sp.byte.underlying)
            buffer.append(contentsOf: Swift.Array(data.utf8))
        }

        buffer.append(contentsOf: [ASCII.Code.questionMark.byte.underlying, ASCII.Code.greaterThanSign.byte.underlying])  // ?>
    }

    /// Encodes an element.
    @inlinable
    mutating func encodeElement<Buffer: RangeReplaceableCollection>(
        _ element: W3C_XML.Element,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        // Opening tag
        buffer.append(ASCII.Code.lessThanSign.byte.underlying)
        buffer.append(contentsOf: Swift.Array(element.name.qualified.utf8))

        // Namespace declarations
        for ns in element.namespaces {
            buffer.append(ASCII.Code.sp.byte.underlying)
            if let prefix = ns.prefix {
                buffer.append(contentsOf: Swift.Array("xmlns:".utf8))
                buffer.append(contentsOf: Swift.Array(prefix.utf8))
            } else {
                buffer.append(contentsOf: Swift.Array("xmlns".utf8))
            }
            buffer.append(contentsOf: [ASCII.Code.equalsSign.byte.underlying, ASCII.Code.quotationMark.byte.underlying])
            encodeAttributeValue(ns.uri, into: &buffer)
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        }

        // Attributes
        for attr in element.attributes {
            buffer.append(ASCII.Code.sp.byte.underlying)
            buffer.append(contentsOf: Swift.Array(attr.name.qualified.utf8))
            buffer.append(contentsOf: [ASCII.Code.equalsSign.byte.underlying, ASCII.Code.quotationMark.byte.underlying])
            encodeAttributeValue(attr.value, into: &buffer)
            buffer.append(ASCII.Code.quotationMark.byte.underlying)
        }

        if element.content.isEmpty {
            // Empty element
            buffer.append(contentsOf: [ASCII.Code.solidus.byte.underlying, ASCII.Code.greaterThanSign.byte.underlying])  // />
        } else {
            buffer.append(ASCII.Code.greaterThanSign.byte.underlying)

            // Check if content is text-only (no formatting)
            let hasElementChildren = element.content.contains { $0.isElement }

            depth += 1

            for content in element.content {
                if options.prettyPrint && hasElementChildren && content.isElement {
                    buffer.append(ASCII.Code.lf.byte.underlying)
                    appendIndent(into: &buffer)
                }
                encodeContent(content, into: &buffer)
            }

            depth -= 1

            if options.prettyPrint && hasElementChildren {
                buffer.append(ASCII.Code.lf.byte.underlying)
                appendIndent(into: &buffer)
            }

            // Closing tag
            buffer.append(contentsOf: [ASCII.Code.lessThanSign.byte.underlying, ASCII.Code.solidus.byte.underlying])  // </
            buffer.append(contentsOf: Swift.Array(element.name.qualified.utf8))
            buffer.append(ASCII.Code.greaterThanSign.byte.underlying)
        }
    }

    /// Encodes content.
    @inlinable
    mutating func encodeContent<Buffer: RangeReplaceableCollection>(
        _ content: W3C_XML.Content,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        switch content {
        case .element(let element):
            encodeElement(element, into: &buffer)

        case .text(let text):
            encodeText(text, into: &buffer)

        case .cdata(let text):
            buffer.append(contentsOf: Swift.Array("<![CDATA[".utf8))
            buffer.append(contentsOf: Swift.Array(text.utf8))
            buffer.append(contentsOf: Swift.Array("]]>".utf8))

        case .comment(let text):
            buffer.append(contentsOf: Swift.Array("<!--".utf8))
            buffer.append(contentsOf: Swift.Array(text.utf8))
            buffer.append(contentsOf: Swift.Array("-->".utf8))

        case .instruction(let pi):
            encodeInstruction(pi, into: &buffer)
        }
    }

    /// Encodes text content with entity escaping.
    @inlinable
    mutating func encodeText<Buffer: RangeReplaceableCollection>(
        _ text: String,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case UInt32(UInt8.ascii.lessThanSign):
                buffer.append(contentsOf: Swift.Array("&lt;".utf8))
            case UInt32(UInt8.ascii.ampersand):
                buffer.append(contentsOf: Swift.Array("&amp;".utf8))
            case UInt32(UInt8.ascii.greaterThanSign):
                buffer.append(contentsOf: Swift.Array("&gt;".utf8))
            default:
                encodeScalarUTF8(scalar, into: &buffer)
            }
        }
    }

    /// Encodes an attribute value with entity escaping.
    @inlinable
    mutating func encodeAttributeValue<Buffer: RangeReplaceableCollection>(
        _ value: String,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case UInt32(UInt8.ascii.lessThanSign):
                buffer.append(contentsOf: Swift.Array("&lt;".utf8))
            case UInt32(UInt8.ascii.ampersand):
                buffer.append(contentsOf: Swift.Array("&amp;".utf8))
            case UInt32(UInt8.ascii.quotationMark):
                buffer.append(contentsOf: Swift.Array("&quot;".utf8))
            case UInt32(UInt8.ascii.apostrophe) where options.escapeApostrophe:
                buffer.append(contentsOf: Swift.Array("&apos;".utf8))
            case 0x09:  // Tab
                buffer.append(contentsOf: Swift.Array("&#9;".utf8))
            case 0x0A:  // LF
                buffer.append(contentsOf: Swift.Array("&#10;".utf8))
            case 0x0D:  // CR
                buffer.append(contentsOf: Swift.Array("&#13;".utf8))
            default:
                encodeScalarUTF8(scalar, into: &buffer)
            }
        }
    }

    /// Encodes a Unicode scalar directly to UTF-8 bytes.
    @inlinable
    func encodeScalarUTF8<Buffer: RangeReplaceableCollection>(
        _ scalar: Unicode.Scalar,
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        let v = scalar.value
        switch v {
        case 0x00...0x7F:
            buffer.append(UInt8(v))
        case 0x80...0x7FF:
            buffer.append(UInt8(0xC0 | (v >> 6)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        case 0x800...0xFFFF:
            buffer.append(UInt8(0xE0 | (v >> 12)))
            buffer.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        default:
            buffer.append(UInt8(0xF0 | (v >> 18)))
            buffer.append(UInt8(0x80 | ((v >> 12) & 0x3F)))
            buffer.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            buffer.append(UInt8(0x80 | (v & 0x3F)))
        }
    }

    /// Appends indentation for the current depth.
    @inlinable
    func appendIndent<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer
    ) where Buffer.Element == UInt8 {
        for _ in 0..<depth {
            buffer.append(contentsOf: options.indent.utf8)
        }
    }
}

// MARK: - Document.encode Extension

extension W3C_XML.Document {
    /// Creates an encoder for this document.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let bytes = document.encode()
    /// let pretty = document.encode(options: .init(prettyPrint: true))
    /// ```
    public var encode: W3C_XML.Encode {
        W3C_XML.Encode(self)
    }
}

// MARK: - Element Encode Extension

extension W3C_XML.Element {
    /// Encodes this element to a byte array.
    ///
    /// - Parameter options: Encoding options.
    /// - Returns: UTF-8 encoded XML bytes.
    @inlinable
    public func encode(options: W3C_XML.Options = W3C_XML.Options()) -> [UInt8] {
        var buffer: [UInt8] = []
        var encoder = W3C_XML.Encoder(options: options)
        encoder.encodeElement(self, into: &buffer)
        return buffer
    }

    /// Encodes this element into an existing buffer.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to append to.
    ///   - options: Encoding options.
    @inlinable
    public func encode<Buffer: RangeReplaceableCollection>(
        into buffer: inout Buffer,
        options: W3C_XML.Options = W3C_XML.Options()
    ) where Buffer.Element == UInt8 {
        var encoder = W3C_XML.Encoder(options: options)
        encoder.encodeElement(self, into: &buffer)
    }
}
