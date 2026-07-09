import Testing

@testable import W3C_XML

@Suite(
    "W3C_XML Parser Tests",
    .disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+")
)
struct ParserTests {
    @Test
    func `Parse simple element`() throws {
        let doc = try W3C_XML.parse("<root/>")
        #expect(doc.root.name.local == "root")
        #expect(doc.root.content.isEmpty)
    }

    @Test
    func `Parse element with text`() throws {
        let doc = try W3C_XML.parse("<root>Hello</root>")
        #expect(doc.root.name.local == "root")
        #expect(doc.root.textContent == "Hello")
    }

    @Test
    func `Parse element with attributes`() throws {
        let doc = try W3C_XML.parse(#"<root id="123" class="test"/>"#)
        #expect(doc.root.name.local == "root")
        #expect(doc.root.attribute("id") == "123")
        #expect(doc.root.attribute("class") == "test")
    }

    @Test
    func `Parse nested elements`() throws {
        let doc = try W3C_XML.parse(
            """
            <root>
                <child1>First</child1>
                <child2>Second</child2>
            </root>
            """
        )
        #expect(doc.root.children.count == 2)
        #expect(doc.root.child("child1")?.textContent == "First")
        #expect(doc.root.child("child2")?.textContent == "Second")
    }

    @Test
    func `Parse with XML declaration`() throws {
        let doc = try W3C_XML.parse(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <root/>
            """
        )
        #expect(doc.declaration?.version == .v1_0)
        #expect(doc.declaration?.encoding == "UTF-8")
    }

    @Test
    func `Parse with namespace`() throws {
        let doc = try W3C_XML.parse(
            """
            <root xmlns="http://example.com" xmlns:ex="http://example.com/ex">
                <ex:child/>
            </root>
            """
        )
        #expect(doc.root.namespaces.count == 2)
        #expect(doc.root.namespaces[0].uri == "http://example.com")
        #expect(doc.root.namespaces[1].prefix == "ex")
    }

    @Test
    func `Parse CDATA section`() throws {
        let doc = try W3C_XML.parse("<root><![CDATA[<script>alert('hi')</script>]]></root>")
        if case .cdata(let text) = doc.root.content.first {
            #expect(text == "<script>alert('hi')</script>")
        } else {
            Issue.record("Expected CDATA content")
        }
    }

    @Test
    func `Parse comment`() throws {
        let doc = try W3C_XML.parse("<root><!--This is a comment--></root>")
        if case .comment(let text) = doc.root.content.first {
            #expect(text == "This is a comment")
        } else {
            Issue.record("Expected comment content")
        }
    }

    @Test
    func `Parse processing instruction`() throws {
        let doc = try W3C_XML.parse(
            """
            <?xml-stylesheet type="text/xsl" href="style.xsl"?>
            <root/>
            """
        )
        #expect(doc.prologue.count == 1)
        #expect(doc.prologue[0].target == "xml-stylesheet")
    }

    @Test
    func `Parse entity references`() throws {
        let doc = try W3C_XML.parse("<root>&lt;&gt;&amp;&apos;&quot;</root>")
        #expect(doc.root.textContent == "<>&'\"")
    }

    @Test
    func `Parse numeric character references`() throws {
        let doc = try W3C_XML.parse("<root>&#60;&#x3E;</root>")
        #expect(doc.root.textContent == "<>")
    }
}

@Suite(
    "W3C_XML Error Handling Tests",
    .disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+")
)
struct ErrorHandlingTests {
    @Test
    func `Reject unclosed element`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>")
        }
    }

    @Test
    func `Reject mismatched tags`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root></other>")
        }
    }

    @Test
    func `Reject missing root element`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("")
        }
    }

    @Test
    func `Reject multiple root elements`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<a/><b/>")
        }
    }

    @Test
    func `Reject unterminated comment`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><!-- unterminated</root>")
        }
    }

    @Test
    func `Reject unterminated CDATA`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><![CDATA[unterminated</root>")
        }
    }

    @Test
    func `Reject unterminated attribute value`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root attr="unterminated>"#)
        }
    }

    @Test
    func `Reject invalid entity reference`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&invalid;</root>")
        }
    }

    @Test
    func `Reject unterminated entity reference`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&amp</root>")
        }
    }

    @Test
    func `Reject invalid numeric character reference`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&#xZZZ;</root>")
        }
    }

    @Test
    func `Reject less-than in attribute value`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root attr="a<b"/>"#)
        }
    }

    @Test
    func `Reject duplicate attributes`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root id="1" id="2"/>"#)
        }
    }

    @Test
    func `Reject invalid element name starting with number`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<123/>")
        }
    }

    @Test
    func `Reject unterminated processing instruction`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<?xml version=\"1.0\"")
        }
    }

    @Test
    func `Reject invalid XML declaration`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<?xml version=\"2.0\"?><root/>")
        }
    }

    @Test
    func `Reject double hyphen in comment`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><!-- -- --></root>")
        }
    }

    @Test
    func `Reject text before root element`() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("text<root/>")
        }
    }
}

@Suite("W3C_XML Encoder Tests")
struct EncoderTests {
    @Test
    func `Encode empty element`() {
        let element = W3C_XML.Element(name: "root")
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root/>")
    }

    @Test
    func `Encode element with text`() {
        let element = W3C_XML.Element(name: "root", content: [.text("Hello")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root>Hello</root>")
    }

    @Test
    func `Encode escapes text entities`() {
        let element = W3C_XML.Element(name: "root", content: [.text("<>&")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root>&lt;&gt;&amp;</root>")
    }

    @Test
    func `Encode escapes attribute entities`() throws {
        let element = W3C_XML.Element(
            name: "root",
            attributes: [W3C_XML.Attribute(name: "a", value: "<&\"")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("&lt;"))
        #expect(output.contains("&amp;"))
        #expect(output.contains("&quot;"))
    }

    @Test
    func `Encode CDATA section`() {
        let element = W3C_XML.Element(name: "root", content: [.cdata("<script>")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root><![CDATA[<script>]]></root>")
    }

    @Test
    func `Encode comment`() {
        let element = W3C_XML.Element(name: "root", content: [.comment("note")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root><!--note--></root>")
    }

    @Test
    func `Encode namespace declaration`() {
        let element = W3C_XML.Element(
            name: "root",
            namespaces: [W3C_XML.Namespace(prefix: nil, uri: "http://example.com")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("xmlns=\"http://example.com\""))
    }

    @Test
    func `Encode prefixed namespace`() {
        let element = W3C_XML.Element(
            name: "root",
            namespaces: [W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("xmlns:ex=\"http://example.com\""))
    }

    @Test
    func `Encode pretty print`() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.element(W3C_XML.Element(name: "child"))]
        )
        let output = String(decoding: element.encode(options: .init(prettyPrint: true)), as: UTF8.self)
        #expect(output.contains("\n"))
        #expect(output.contains("  "))  // Default indent
    }

    @Test
    func `Encode processing instruction`() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.instruction(W3C_XML.Instruction(target: "php", data: "echo 1"))]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("<?php echo 1?>"))
    }

    @Test
    func `Encode Unicode content`() {
        let element = W3C_XML.Element(name: "root", content: [.text("日本語 🎉")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("日本語 🎉"))
    }
}

@Suite(
    "W3C_XML Parser Edge Cases",
    .disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+")
)
struct ParserEdgeCases {
    @Test
    func `Parse empty element with explicit close tag`() throws {
        let doc = try W3C_XML.parse("<root></root>")
        #expect(doc.root.content.isEmpty)
    }

    @Test
    func `Parse whitespace-only content`() throws {
        let doc = try W3C_XML.parse("<root>   \n\t  </root>")
        #expect(doc.root.textContent == "   \n\t  ")
    }

    @Test
    func `Parse mixed content`() throws {
        let doc = try W3C_XML.parse("<root>text<b>bold</b>more</root>")
        #expect(doc.root.content.count == 3)
        #expect(doc.root.textContent == "textmore")
        #expect(doc.root.child("b")?.textContent == "bold")
    }

    @Test
    func `Parse attribute with single quotes`() throws {
        let doc = try W3C_XML.parse("<root attr='value'/>")
        #expect(doc.root.attribute("attr") == "value")
    }

    @Test
    func `Parse empty attribute value`() throws {
        let doc = try W3C_XML.parse(#"<root attr=""/>"#)
        #expect(doc.root.attribute("attr")?.isEmpty == true)
    }

    @Test
    func `Parse multiple attributes`() throws {
        let doc = try W3C_XML.parse(#"<root a="1" b="2" c="3"/>"#)
        #expect(doc.root.attributes.count == 3)
        #expect(doc.root.attribute("a") == "1")
        #expect(doc.root.attribute("b") == "2")
        #expect(doc.root.attribute("c") == "3")
    }

    @Test
    func `Parse nested elements 10 deep`() throws {
        var xml = ""
        for _ in 0..<10 {
            xml += "<a>"
        }
        xml += "deep"
        for _ in 0..<10 {
            xml += "</a>"
        }
        let doc = try W3C_XML.parse(xml)
        #expect(doc.root.name.local == "a")
    }

    @Test
    func `Parse adjacent text nodes`() throws {
        // Entity references can create adjacent text - parser should handle
        let doc = try W3C_XML.parse("<root>a&amp;b</root>")
        #expect(doc.root.textContent == "a&b")
    }

    @Test
    func `Parse element with all content types`() throws {
        let doc = try W3C_XML.parse(
            """
            <root>
                text
                <child/>
                <![CDATA[cdata]]>
                <!--comment-->
                <?pi data?>
            </root>
            """
        )
        #expect(doc.root.content.count >= 5)
    }
}

@Suite("W3C_XML Type Tests")
struct TypeTests {
    @Test
    func `Name parses prefix and local`() {
        let name = W3C_XML.Name("prefix:local")
        #expect(name.prefix == "prefix")
        #expect(name.local == "local")
        #expect(name.qualified == "prefix:local")
    }

    @Test
    func `Name without prefix`() {
        let name = W3C_XML.Name("local")
        #expect(name.prefix == nil)
        #expect(name.local == "local")
        #expect(name.qualified == "local")
    }

    @Test
    func `Namespace equality`() {
        let ns1 = W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")
        let ns2 = W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")
        #expect(ns1 == ns2)
    }

    @Test
    func `Attribute equality`() {
        let attr1 = W3C_XML.Attribute(name: "id", value: "123")
        let attr2 = W3C_XML.Attribute(name: "id", value: "123")
        #expect(attr1 == attr2)
    }

    @Test
    func `Content element accessor`() {
        let element = W3C_XML.Element(name: "child")
        let content = W3C_XML.Content.element(element)
        #expect(content.element?.name.local == "child")
        #expect(content.isElement)
    }

    @Test
    func `Element children filter`() {
        let element = W3C_XML.Element(
            name: "root",
            content: [
                .element(W3C_XML.Element(name: "a")),
                .text("text"),
                .element(W3C_XML.Element(name: "b")),
                .comment("comment"),
            ]
        )
        #expect(element.children.count == 2)
    }

    @Test
    func `Element subscript by name`() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.element(W3C_XML.Element(name: "child", content: [.text("value")]))]
        )
        #expect(element["child"]?.textContent == "value")
        #expect(element["nonexistent"] == nil)
    }

    @Test
    func `Element subscript by index`() {
        let element = W3C_XML.Element(
            name: "root",
            content: [
                .element(W3C_XML.Element(name: "first")),
                .element(W3C_XML.Element(name: "second")),
            ]
        )
        #expect(element[0]?.name.local == "first")
        #expect(element[1]?.name.local == "second")
        #expect(element[99] == nil)
    }
}

@Suite("W3C_XML Character Validation Tests")
struct CharacterValidationTests {
    @Test
    func `isWhitespace`() {
        #expect(W3C_XML.isWhitespace(0x20))  // Space
        #expect(W3C_XML.isWhitespace(0x09))  // Tab
        #expect(W3C_XML.isWhitespace(0x0A))  // LF
        #expect(W3C_XML.isWhitespace(0x0D))  // CR
        #expect(!W3C_XML.isWhitespace(0x41))  // 'A'
    }

    @Test
    func `isNameStartChar ASCII`() {
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar("A")))
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar("Z")))
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar("a")))
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar("z")))
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar("_")))
        #expect(W3C_XML.isNameStartChar(Unicode.Scalar(":")))
        #expect(!W3C_XML.isNameStartChar(Unicode.Scalar("0")))
        #expect(!W3C_XML.isNameStartChar(Unicode.Scalar("-")))
        #expect(!W3C_XML.isNameStartChar(Unicode.Scalar(".")))
    }

    @Test
    func `isNameChar includes digits and hyphen`() {
        #expect(W3C_XML.isNameChar(Unicode.Scalar("0")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("9")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("-")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar(".")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("A")))
    }

    @Test
    func `isChar valid characters`() {
        #expect(W3C_XML.isChar(Unicode.Scalar(0x09)!))  // Tab
        #expect(W3C_XML.isChar(Unicode.Scalar(0x0A)!))  // LF
        #expect(W3C_XML.isChar(Unicode.Scalar(0x0D)!))  // CR
        #expect(W3C_XML.isChar(Unicode.Scalar(0x20)!))  // Space
        #expect(W3C_XML.isChar(Unicode.Scalar("A")))
    }

    @Test
    func `isChar invalid characters`() {
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x00)!))  // NUL
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x01)!))  // Control
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x1F)!))  // Control
    }

    @Test(.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+"))
    func `Parse Unicode element name`() throws {
        let doc = try W3C_XML.parse("<日本語/>")
        #expect(doc.root.name.local == "日本語")
    }

    @Test(.disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+"))
    func `Parse Unicode text content`() throws {
        let doc = try W3C_XML.parse("<root>日本語 🎉 émojis</root>")
        #expect(doc.root.textContent == "日本語 🎉 émojis")
    }
}

@Suite(
    "W3C_XML Deep Nesting Tests",
    .disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+")
)
struct DeepNestingTests {
    @Test
    func `Parse 1000-level deep nesting without stack overflow`() throws {
        var xml = ""
        for i in 0..<1000 {
            xml += "<level\(i)>"
        }
        xml += "deep"
        for i in (0..<1000).reversed() {
            xml += "</level\(i)>"
        }

        let doc = try W3C_XML.parse(xml)
        #expect(doc.root.name.local == "level0")

        var current: W3C_XML.Element? = doc.root
        for i in 1..<1000 {
            current = current?.child("level\(i)")
            #expect(current != nil, "Missing level\(i)")
        }
        #expect(current?.textContent == "deep")
    }

    @Test
    func `Parse 500-level deep nesting with attributes`() throws {
        var xml = ""
        for i in 0..<500 {
            xml += #"<level\#(i) id="\#(i)">"#
        }
        xml += "bottom"
        for i in (0..<500).reversed() {
            xml += "</level\(i)>"
        }

        let doc = try W3C_XML.parse(xml)
        #expect(doc.root.attribute("id") == "0")

        var current: W3C_XML.Element? = doc.root
        for i in 1..<500 {
            current = current?.child("level\(i)")
            #expect(current?.attribute("id") == "\(i)")
        }
    }

    @Test
    func `Depth limit is enforced`() {
        var xml = ""
        for i in 0..<600 {
            xml += "<a\(i)>"
        }
        xml += "x"
        for i in (0..<600).reversed() {
            xml += "</a\(i)>"
        }

        #expect(throws: W3C_XML.Parse.Error.self) {
            _ = try W3C_XML.parse(xml, maxDepth: 500)
        }
    }

    @Test
    func `Custom depth limit via W3C_XML.parse() directly`() throws {
        let depth = 37
        var xml = ""
        for _ in 0..<depth {
            xml += "<a>"
        }
        xml += "<inner/>"
        for _ in 0..<depth {
            xml += "</a>"
        }

        let doc = try W3C_XML.parse(xml, maxDepth: 10000)
        #expect(doc.root.name.local == "a")
    }
}

@Suite(
    "W3C_XML Round-trip Tests",
    .disabled(if: Toolchain.hasTaggedMetadataSIGSEGV, "§A9 Tagged-metadata SIGSEGV on Swift 6.3.x (W3C_XML.parse → Parser.Machine.Parser over Byte.Input forces Tagged VWT); fixed on 6.4+")
)
struct RoundtripTests {
    @Test
    func `Round-trip simple document`() throws {
        let original = "<root/>"
        let doc = try W3C_XML.parse(original)
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output == original)
    }

    @Test
    func `Round-trip document with content`() throws {
        let original = try W3C_XML.parse(
            """
            <?xml version="1.0"?>
            <root>
                <child id="1">First</child>
                <child id="2">Second</child>
            </root>
            """
        )

        let bytes = original.encode()
        let reparsed = try W3C_XML.parse(bytes)

        #expect(reparsed.declaration?.version == .v1_0)
        #expect(reparsed.root.name.local == "root")
        #expect(reparsed.root.children.count == 2)
    }

    @Test
    func `Round-trip preserves entities`() throws {
        let doc = try W3C_XML.parse("<root>&lt;&gt;&amp;</root>")
        let bytes = doc.root.encode()
        let reparsed = try W3C_XML.parse(bytes)
        #expect(reparsed.root.textContent == "<>&")
    }

    @Test
    func `Round-trip preserves CDATA`() throws {
        let doc = try W3C_XML.parse("<root><![CDATA[<script>]]></root>")
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output.contains("<![CDATA["))
    }

    @Test
    func `Round-trip preserves namespaces`() throws {
        let doc = try W3C_XML.parse(#"<root xmlns="http://example.com" xmlns:ex="http://ex.com"/>"#)
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output.contains("xmlns=\"http://example.com\""))
        #expect(output.contains("xmlns:ex=\"http://ex.com\""))
    }
}
