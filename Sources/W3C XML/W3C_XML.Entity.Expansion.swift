import Byte
import Cursor
import Machine
import Parser
import Parser_Machine

extension W3C_XML.Entity {

    /// Includes the replacement text of internal general entities where the document
    /// references them (XML 1.0 §4.4): in content as markup, in attribute values as data.
    ///
    /// References inside comments, CDATA sections and processing instructions are left alone,
    /// as are character references, predefined entities and undeclared names. A reference to
    /// an external or unparsed entity throws ``W3C_XML/Parse/Error/externalEntity(_:)``,
    /// since external entities are never resolved. Recursion, nesting depth and the total
    /// expanded size are bounded by ``Limits``.
    struct Expansion {

        let declarations: Declarations

        let limits: Limits

        let maxDepth: Int

        var expandedBytes = 0

        var validated: Swift::Set<String> = []

        init(declarations: Declarations, limits: Limits, maxDepth: Int) {
            self.declarations = declarations
            self.limits = limits
            self.maxDepth = maxDepth
        }
    }
}

extension W3C_XML.Entity.Expansion {

    mutating func markup(_ source: [UInt8]) throws(W3C_XML.Parse.Error) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(source.count)
        try markup(source, into: &output, open: [])
        return output
    }

    mutating func markup(
        _ source: [UInt8],
        into output: inout [UInt8],
        open: [String]
    ) throws(W3C_XML.Parse.Error) {
        var index = 0

        while index < source.count {
            let byte = source[index]

            if byte == UInt8(ascii: "<") {
                if let end = Self.end(of: "<!--", "-->", in: source, at: index)
                    ?? Self.end(of: "<![CDATA[", "]]>", in: source, at: index)
                    ?? Self.end(of: "<?", "?>", in: source, at: index)
                {
                    output.append(contentsOf: source[index..<end])
                    index = end
                } else {
                    index = try tag(source, from: index, into: &output, open: open)
                }
            } else if byte == UInt8(ascii: "&"), let reference = Self.reference(in: source, at: index),
                declarations.replacements[reference.name] != nil || declarations.external.contains(reference.name)
            {
                try include(reference.name, inAttribute: false, into: &output, open: open)
                index = reference.end
            } else {
                output.append(byte)
                index += 1
            }
        }
    }

    mutating func tag(
        _ source: [UInt8],
        from start: Int,
        into output: inout [UInt8],
        open: [String]
    ) throws(W3C_XML.Parse.Error) -> Int {
        output.append(source[start])
        var index = start + 1

        while index < source.count, source[index] != UInt8(ascii: ">") {
            let byte = source[index]
            output.append(byte)
            index += 1
            guard byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") else { continue }

            while index < source.count, source[index] != byte {
                if source[index] == UInt8(ascii: "&"), let reference = Self.reference(in: source, at: index),
                    declarations.replacements[reference.name] != nil
                        || declarations.external.contains(reference.name)
                {
                    try include(reference.name, inAttribute: true, into: &output, open: open)
                    index = reference.end
                } else {
                    output.append(source[index])
                    index += 1
                }
            }
            if index < source.count {
                output.append(byte)
                index += 1
            }
        }

        if index < source.count {
            output.append(source[index])
            index += 1
        }
        return index
    }

    mutating func attributeText(
        _ source: [UInt8],
        into output: inout [UInt8],
        open: [String]
    ) throws(W3C_XML.Parse.Error) {
        var index = 0

        while index < source.count {
            let byte = source[index]
            if byte == UInt8(ascii: "&"), let reference = Self.reference(in: source, at: index),
                declarations.replacements[reference.name] != nil || declarations.external.contains(reference.name)
            {
                try include(reference.name, inAttribute: true, into: &output, open: open)
                index = reference.end
            } else if byte == UInt8(ascii: "\"") {
                output.append(contentsOf: Swift::Array("&#34;".utf8))
                index += 1
            } else if byte == UInt8(ascii: "'") {
                output.append(contentsOf: Swift::Array("&#39;".utf8))
                index += 1
            } else {
                output.append(byte)
                index += 1
            }
        }
    }

    mutating func include(
        _ name: String,
        inAttribute: Bool,
        into output: inout [UInt8],
        open: [String]
    ) throws(W3C_XML.Parse.Error) {
        guard let text = declarations.replacements[name] else {
            throw .externalEntity(name)
        }
        guard !open.contains(name) else {
            throw .recursiveEntity(name)
        }
        guard open.count < limits.depth else {
            throw .entityDepthExceeded(limit: limits.depth)
        }

        var replacement: [UInt8] = []
        if inAttribute {
            try attributeText(text, into: &replacement, open: open + [name])
        } else {
            try markup(text, into: &replacement, open: open + [name])
        }

        expandedBytes += replacement.count
        guard expandedBytes <= limits.expandedBytes else {
            throw .entityExpansionExceeded(limit: limits.expandedBytes)
        }

        if !inAttribute {
            try validate(name, replacement)
        }
        output.append(contentsOf: replacement)
    }

    /// Checks that a replacement text included in content is well-formed content on its own
    /// (XML 1.0 §4.3.2), so an entity cannot open a tag that the document closes.
    mutating func validate(_ name: String, _ replacement: [UInt8]) throws(W3C_XML.Parse.Error) {
        guard !validated.contains(name) else { return }

        var wrapped = [Byte](utf8: "<x>")
        wrapped.append(contentsOf: replacement.map(Byte.init(bitPattern:)))
        wrapped.append(contentsOf: [Byte](utf8: "</x>"))
        var input = wrapped[...]

        let parser =
            W3C_XML.Parse.machineElement(maxDepth: maxDepth)
            as Machine::Machine.Parser.Parser<ArraySlice<Byte>, W3C_XML.Element, W3C_XML.Parse.Error>
        _ = try parser.parse(&input)
        guard input.xmlPeek() == nil else {
            throw .expected("well-formed replacement text for entity \(name)")
        }

        validated.insert(name)
    }
}

extension W3C_XML.Entity.Expansion {

    static func end(of opener: String, _ terminator: String, in source: [UInt8], at index: Int) -> Int? {
        let open = Swift::Array(opener.utf8)
        guard index + open.count <= source.count,
            source[index..<(index + open.count)].elementsEqual(open)
        else {
            return nil
        }
        let close = Swift::Array(terminator.utf8)
        var cursor = index + open.count
        while cursor + close.count <= source.count {
            if source[cursor..<(cursor + close.count)].elementsEqual(close) {
                return cursor + close.count
            }
            cursor += 1
        }
        return source.count
    }

    static func reference(in source: [UInt8], at index: Int) -> (name: String, end: Int)? {
        var cursor = index + 1
        guard cursor < source.count, source[cursor] != UInt8(ascii: "#") else { return nil }
        while cursor < source.count {
            let byte = source[cursor]
            if byte == UInt8(ascii: ";") {
                guard cursor > index + 1 else { return nil }
                return (String(decoding: source[(index + 1)..<cursor], as: UTF8.self), cursor + 1)
            }
            if W3C_XML.Entity.Declarations.isSpace(byte) || byte == UInt8(ascii: "<") || byte == UInt8(ascii: "&")
                || byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "'") || byte == UInt8(ascii: ">")
            {
                return nil
            }
            cursor += 1
        }
        return nil
    }
}
