import Testing

@testable import W3C_XML

extension `W3C_XML.Encoder Tests` {
    @Suite
    struct `Quotes in text` {
        @Test
        func `are written as they are by default`() {
            let element = W3C_XML.Element(name: "root", content: [.text(#"a'b"c"#)])
            #expect(String(decoding: element.encode(), as: UTF8.self) == #"<root>a'b"c</root>"#)
        }

        @Test
        func `are escaped when escapeQuotesInText is set and parse back`() throws {
            let element = W3C_XML.Element(name: "root", content: [.text(#"a'b"c&d"#)])
            let output = String(decoding: element.encode(options: .init(escapeQuotesInText: true)), as: UTF8.self)
            #expect(output == "<root>a&apos;b&quot;c&amp;d</root>")
            #expect(try W3C_XML.parse(output).root.textContent == #"a'b"c&d"#)
        }
    }
}
