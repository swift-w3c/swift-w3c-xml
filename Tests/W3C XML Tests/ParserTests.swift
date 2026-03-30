import Testing
@testable import W3C_XML

@Suite("W3C_XML Parser Tests")
struct ParserTests {
    @Test("Parse simple element")
    func parseSimpleElement() throws {
        let doc = try W3C_XML.parse("<root/>")
        #expect(doc.root.name.local == "root")
        #expect(doc.root.content.isEmpty)
    }

    @Test("Parse element with text")
    func parseElementWithText() throws {
        let doc = try W3C_XML.parse("<root>Hello</root>")
        #expect(doc.root.name.local == "root")
        #expect(doc.root.textContent == "Hello")
    }

    @Test("Parse element with attributes")
    func parseElementWithAttributes() throws {
        let doc = try W3C_XML.parse(#"<root id="123" class="test"/>"#)
        #expect(doc.root.name.local == "root")
        #expect(doc.root.attribute("id") == "123")
        #expect(doc.root.attribute("class") == "test")
    }

    @Test("Parse nested elements")
    func parseNestedElements() throws {
        let doc = try W3C_XML.parse("""
            <root>
                <child1>First</child1>
                <child2>Second</child2>
            </root>
            """)
        #expect(doc.root.children.count == 2)
        #expect(doc.root.child("child1")?.textContent == "First")
        #expect(doc.root.child("child2")?.textContent == "Second")
    }

    @Test("Parse with XML declaration")
    func parseWithDeclaration() throws {
        let doc = try W3C_XML.parse("""
            <?xml version="1.0" encoding="UTF-8"?>
            <root/>
            """)
        #expect(doc.declaration?.version == .v1_0)
        #expect(doc.declaration?.encoding == "UTF-8")
    }

    @Test("Parse with namespace")
    func parseWithNamespace() throws {
        let doc = try W3C_XML.parse("""
            <root xmlns="http://example.com" xmlns:ex="http://example.com/ex">
                <ex:child/>
            </root>
            """)
        #expect(doc.root.namespaces.count == 2)
        #expect(doc.root.namespaces[0].uri == "http://example.com")
        #expect(doc.root.namespaces[1].prefix == "ex")
    }

    @Test("Parse CDATA section")
    func parseCDATA() throws {
        let doc = try W3C_XML.parse("<root><![CDATA[<script>alert('hi')</script>]]></root>")
        if case .cdata(let text) = doc.root.content.first {
            #expect(text == "<script>alert('hi')</script>")
        } else {
            Issue.record("Expected CDATA content")
        }
    }

    @Test("Parse comment")
    func parseComment() throws {
        let doc = try W3C_XML.parse("<root><!--This is a comment--></root>")
        if case .comment(let text) = doc.root.content.first {
            #expect(text == "This is a comment")
        } else {
            Issue.record("Expected comment content")
        }
    }

    @Test("Parse processing instruction")
    func parseProcessingInstruction() throws {
        let doc = try W3C_XML.parse("""
            <?xml-stylesheet type="text/xsl" href="style.xsl"?>
            <root/>
            """)
        #expect(doc.prologue.count == 1)
        #expect(doc.prologue[0].target == "xml-stylesheet")
    }

    @Test("Parse entity references")
    func parseEntityReferences() throws {
        let doc = try W3C_XML.parse("<root>&lt;&gt;&amp;&apos;&quot;</root>")
        #expect(doc.root.textContent == "<>&'\"")
    }

    @Test("Parse numeric character references")
    func parseNumericReferences() throws {
        let doc = try W3C_XML.parse("<root>&#60;&#x3E;</root>")
        #expect(doc.root.textContent == "<>")
    }
}

@Suite("W3C_XML Error Handling Tests")
struct ErrorHandlingTests {
    @Test("Reject unclosed element")
    func rejectUnclosedElement() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>")
        }
    }

    @Test("Reject mismatched tags")
    func rejectMismatchedTags() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root></other>")
        }
    }

    @Test("Reject missing root element")
    func rejectMissingRoot() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("")
        }
    }

    @Test("Reject multiple root elements")
    func rejectMultipleRoots() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<a/><b/>")
        }
    }

    @Test("Reject unterminated comment")
    func rejectUnterminatedComment() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><!-- unterminated</root>")
        }
    }

    @Test("Reject unterminated CDATA")
    func rejectUnterminatedCDATA() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><![CDATA[unterminated</root>")
        }
    }

    @Test("Reject unterminated attribute value")
    func rejectUnterminatedAttribute() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root attr="unterminated>"#)
        }
    }

    @Test("Reject invalid entity reference")
    func rejectInvalidEntity() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&invalid;</root>")
        }
    }

    @Test("Reject unterminated entity reference")
    func rejectUnterminatedEntity() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&amp</root>")
        }
    }

    @Test("Reject invalid numeric character reference")
    func rejectInvalidNumericRef() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root>&#xZZZ;</root>")
        }
    }

    @Test("Reject less-than in attribute value")
    func rejectLessThanInAttribute() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root attr="a<b"/>"#)
        }
    }

    @Test("Reject duplicate attributes")
    func rejectDuplicateAttributes() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse(#"<root id="1" id="2"/>"#)
        }
    }

    @Test("Reject invalid element name starting with number")
    func rejectInvalidElementName() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<123/>")
        }
    }

    @Test("Reject unterminated processing instruction")
    func rejectUnterminatedPI() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<?xml version=\"1.0\"")
        }
    }

    @Test("Reject invalid XML declaration")
    func rejectInvalidDeclaration() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<?xml version=\"2.0\"?><root/>")
        }
    }

    @Test("Reject double hyphen in comment")
    func rejectDoubleHyphenInComment() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("<root><!-- -- --></root>")
        }
    }

    @Test("Reject text before root element")
    func rejectTextBeforeRoot() {
        #expect(throws: (any Error).self) {
            _ = try W3C_XML.parse("text<root/>")
        }
    }
}

@Suite("W3C_XML Encoder Tests")
struct EncoderTests {
    @Test("Encode empty element")
    func encodeEmptyElement() {
        let element = W3C_XML.Element(name: "root")
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root/>")
    }

    @Test("Encode element with text")
    func encodeElementWithText() {
        let element = W3C_XML.Element(name: "root", content: [.text("Hello")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root>Hello</root>")
    }

    @Test("Encode escapes text entities")
    func encodeEscapesTextEntities() {
        let element = W3C_XML.Element(name: "root", content: [.text("<>&")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root>&lt;&gt;&amp;</root>")
    }

    @Test("Encode escapes attribute entities")
    func encodeEscapesAttributeEntities() throws {
        let element = W3C_XML.Element(
            name: "root",
            attributes: [W3C_XML.Attribute(name: "a", value: "<&\"")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("&lt;"))
        #expect(output.contains("&amp;"))
        #expect(output.contains("&quot;"))
    }

    @Test("Encode CDATA section")
    func encodeCDATA() {
        let element = W3C_XML.Element(name: "root", content: [.cdata("<script>")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root><![CDATA[<script>]]></root>")
    }

    @Test("Encode comment")
    func encodeComment() {
        let element = W3C_XML.Element(name: "root", content: [.comment("note")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output == "<root><!--note--></root>")
    }

    @Test("Encode namespace declaration")
    func encodeNamespace() {
        let element = W3C_XML.Element(
            name: "root",
            namespaces: [W3C_XML.Namespace(prefix: nil, uri: "http://example.com")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("xmlns=\"http://example.com\""))
    }

    @Test("Encode prefixed namespace")
    func encodePrefixedNamespace() {
        let element = W3C_XML.Element(
            name: "root",
            namespaces: [W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("xmlns:ex=\"http://example.com\""))
    }

    @Test("Encode pretty print")
    func encodePrettyPrint() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.element(W3C_XML.Element(name: "child"))]
        )
        let output = String(decoding: element.encode(options: .init(prettyPrint: true)), as: UTF8.self)
        #expect(output.contains("\n"))
        #expect(output.contains("  "))  // Default indent
    }

    @Test("Encode processing instruction")
    func encodeProcessingInstruction() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.instruction(W3C_XML.Instruction(target: "php", data: "echo 1"))]
        )
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("<?php echo 1?>"))
    }

    @Test("Encode Unicode content")
    func encodeUnicodeContent() {
        let element = W3C_XML.Element(name: "root", content: [.text("日本語 🎉")])
        let output = String(decoding: element.encode(), as: UTF8.self)
        #expect(output.contains("日本語 🎉"))
    }
}

@Suite("W3C_XML Parser Edge Cases")
struct ParserEdgeCases {
    @Test("Parse empty element with explicit close tag")
    func parseEmptyElementExplicitClose() throws {
        let doc = try W3C_XML.parse("<root></root>")
        #expect(doc.root.content.isEmpty)
    }

    @Test("Parse whitespace-only content")
    func parseWhitespaceContent() throws {
        let doc = try W3C_XML.parse("<root>   \n\t  </root>")
        #expect(doc.root.textContent == "   \n\t  ")
    }

    @Test("Parse mixed content")
    func parseMixedContent() throws {
        let doc = try W3C_XML.parse("<root>text<b>bold</b>more</root>")
        #expect(doc.root.content.count == 3)
        #expect(doc.root.textContent == "textmore")
        #expect(doc.root.child("b")?.textContent == "bold")
    }

    @Test("Parse attribute with single quotes")
    func parseAttributeSingleQuotes() throws {
        let doc = try W3C_XML.parse("<root attr='value'/>")
        #expect(doc.root.attribute("attr") == "value")
    }

    @Test("Parse empty attribute value")
    func parseEmptyAttributeValue() throws {
        let doc = try W3C_XML.parse(#"<root attr=""/>"#)
        #expect(doc.root.attribute("attr") == "")
    }

    @Test("Parse multiple attributes")
    func parseMultipleAttributes() throws {
        let doc = try W3C_XML.parse(#"<root a="1" b="2" c="3"/>"#)
        #expect(doc.root.attributes.count == 3)
        #expect(doc.root.attribute("a") == "1")
        #expect(doc.root.attribute("b") == "2")
        #expect(doc.root.attribute("c") == "3")
    }

    @Test("Parse nested elements 10 deep")
    func parseDeeplyNested() throws {
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

    @Test("Parse adjacent text nodes")
    func parseAdjacentText() throws {
        // Entity references can create adjacent text - parser should handle
        let doc = try W3C_XML.parse("<root>a&amp;b</root>")
        #expect(doc.root.textContent == "a&b")
    }

    @Test("Parse element with all content types")
    func parseAllContentTypes() throws {
        let doc = try W3C_XML.parse("""
            <root>
                text
                <child/>
                <![CDATA[cdata]]>
                <!--comment-->
                <?pi data?>
            </root>
            """)
        #expect(doc.root.content.count >= 5)
    }
}

@Suite("W3C_XML Type Tests")
struct TypeTests {
    @Test("Name parses prefix and local")
    func nameParsesPrefixLocal() {
        let name = W3C_XML.Name("prefix:local")
        #expect(name.prefix == "prefix")
        #expect(name.local == "local")
        #expect(name.qualified == "prefix:local")
    }

    @Test("Name without prefix")
    func nameWithoutPrefix() {
        let name = W3C_XML.Name("local")
        #expect(name.prefix == nil)
        #expect(name.local == "local")
        #expect(name.qualified == "local")
    }

    @Test("Namespace equality")
    func namespaceEquality() {
        let ns1 = W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")
        let ns2 = W3C_XML.Namespace(prefix: "ex", uri: "http://example.com")
        #expect(ns1 == ns2)
    }

    @Test("Attribute equality")
    func attributeEquality() {
        let attr1 = W3C_XML.Attribute(name: "id", value: "123")
        let attr2 = W3C_XML.Attribute(name: "id", value: "123")
        #expect(attr1 == attr2)
    }

    @Test("Content element accessor")
    func contentElementAccessor() {
        let element = W3C_XML.Element(name: "child")
        let content = W3C_XML.Content.element(element)
        #expect(content.element?.name.local == "child")
        #expect(content.isElement)
    }

    @Test("Element children filter")
    func elementChildrenFilter() {
        let element = W3C_XML.Element(
            name: "root",
            content: [
                .element(W3C_XML.Element(name: "a")),
                .text("text"),
                .element(W3C_XML.Element(name: "b")),
                .comment("comment")
            ]
        )
        #expect(element.children.count == 2)
    }

    @Test("Element subscript by name")
    func elementSubscriptByName() {
        let element = W3C_XML.Element(
            name: "root",
            content: [.element(W3C_XML.Element(name: "child", content: [.text("value")]))]
        )
        #expect(element["child"]?.textContent == "value")
        #expect(element["nonexistent"] == nil)
    }

    @Test("Element subscript by index")
    func elementSubscriptByIndex() {
        let element = W3C_XML.Element(
            name: "root",
            content: [
                .element(W3C_XML.Element(name: "first")),
                .element(W3C_XML.Element(name: "second"))
            ]
        )
        #expect(element[0]?.name.local == "first")
        #expect(element[1]?.name.local == "second")
        #expect(element[99] == nil)
    }
}

@Suite("W3C_XML Character Validation Tests")
struct CharacterValidationTests {
    @Test("isWhitespace")
    func isWhitespace() {
        #expect(W3C_XML.isWhitespace(0x20))  // Space
        #expect(W3C_XML.isWhitespace(0x09))  // Tab
        #expect(W3C_XML.isWhitespace(0x0A))  // LF
        #expect(W3C_XML.isWhitespace(0x0D))  // CR
        #expect(!W3C_XML.isWhitespace(0x41)) // 'A'
    }

    @Test("isNameStartChar ASCII")
    func isNameStartCharASCII() {
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

    @Test("isNameChar includes digits and hyphen")
    func isNameCharExtended() {
        #expect(W3C_XML.isNameChar(Unicode.Scalar("0")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("9")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("-")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar(".")))
        #expect(W3C_XML.isNameChar(Unicode.Scalar("A")))
    }

    @Test("isChar valid characters")
    func isCharValid() {
        #expect(W3C_XML.isChar(Unicode.Scalar(0x09)!))  // Tab
        #expect(W3C_XML.isChar(Unicode.Scalar(0x0A)!))  // LF
        #expect(W3C_XML.isChar(Unicode.Scalar(0x0D)!))  // CR
        #expect(W3C_XML.isChar(Unicode.Scalar(0x20)!))  // Space
        #expect(W3C_XML.isChar(Unicode.Scalar("A")))
    }

    @Test("isChar invalid characters")
    func isCharInvalid() {
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x00)!))  // NUL
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x01)!))  // Control
        #expect(!W3C_XML.isChar(Unicode.Scalar(0x1F)!))  // Control
    }

    @Test("Parse Unicode element name")
    func parseUnicodeElementName() throws {
        let doc = try W3C_XML.parse("<日本語/>")
        #expect(doc.root.name.local == "日本語")
    }

    @Test("Parse Unicode text content")
    func parseUnicodeTextContent() throws {
        let doc = try W3C_XML.parse("<root>日本語 🎉 émojis</root>")
        #expect(doc.root.textContent == "日本語 🎉 émojis")
    }
}

@Suite("W3C_XML Deep Nesting Tests")
struct DeepNestingTests {
    @Test("Parse 1000-level deep nesting without stack overflow")
    func parseDeepNesting1000() throws {
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

    @Test("Parse 500-level deep nesting with attributes")
    func parseDeepNestingWithAttributes() throws {
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

    @Test("Depth limit is enforced")
    func depthLimitEnforced() {
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

    @Test("Custom depth limit via W3C_XML.parse() directly")
    func customDepthLimitDirect() throws {
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

@Suite("W3C_XML Round-trip Tests")
struct RoundtripTests {
    @Test("Round-trip simple document")
    func roundtripSimple() throws {
        let original = "<root/>"
        let doc = try W3C_XML.parse(original)
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output == original)
    }

    @Test("Round-trip document with content")
    func roundtripWithContent() throws {
        let original = try W3C_XML.parse("""
            <?xml version="1.0"?>
            <root>
                <child id="1">First</child>
                <child id="2">Second</child>
            </root>
            """)

        let bytes = original.encode()
        let reparsed = try W3C_XML.parse(bytes)

        #expect(reparsed.declaration?.version == .v1_0)
        #expect(reparsed.root.name.local == "root")
        #expect(reparsed.root.children.count == 2)
    }

    @Test("Round-trip preserves entities")
    func roundtripEntities() throws {
        let doc = try W3C_XML.parse("<root>&lt;&gt;&amp;</root>")
        let bytes = doc.root.encode()
        let reparsed = try W3C_XML.parse(bytes)
        #expect(reparsed.root.textContent == "<>&")
    }

    @Test("Round-trip preserves CDATA")
    func roundtripCDATA() throws {
        let doc = try W3C_XML.parse("<root><![CDATA[<script>]]></root>")
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output.contains("<![CDATA["))
    }

    @Test("Round-trip preserves namespaces")
    func roundtripNamespaces() throws {
        let doc = try W3C_XML.parse(#"<root xmlns="http://example.com" xmlns:ex="http://ex.com"/>"#)
        let bytes = doc.root.encode()
        let output = String(decoding: bytes, as: UTF8.self)
        #expect(output.contains("xmlns=\"http://example.com\""))
        #expect(output.contains("xmlns:ex=\"http://ex.com\""))
    }
}
