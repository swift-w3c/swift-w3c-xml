import Testing

@testable import W3C_XML

extension `W3C_XML.Encoder Tests` {
    @Suite
    struct `Well-formed output` {
        @Test
        func `CDATA containing the end marker is split`() throws {
            let element = W3C_XML.Element(name: "root", content: [.cdata("a]]>b")])
            let output = String(decoding: element.encode(), as: UTF8.self)
            #expect(output == "<root><![CDATA[a]]]]><![CDATA[>b]]></root>")
            let parsed = try W3C_XML.parse(output)
            #expect(parsed.root.content == [.cdata("a]]"), .cdata(">b")])
        }

        @Test
        func `a comment containing double hyphens stays a comment`() throws {
            let element = W3C_XML.Element(name: "root", content: [.comment("a--b-")])
            let output = String(decoding: element.encode(), as: UTF8.self)
            #expect(output == "<root><!--a- -b- --></root>")
            _ = try W3C_XML.parse(output)
        }

        @Test
        func `instruction data containing the end marker stays one instruction`() throws {
            let element = W3C_XML.Element(
                name: "root",
                content: [.instruction(W3C_XML.Instruction(target: "pi", data: "a?>b?"))]
            )
            let output = String(decoding: element.encode(), as: UTF8.self)
            #expect(output == "<root><?pi a? >b??></root>")
            let parsed = try W3C_XML.parse(output)
            #expect(parsed.root.content == [.instruction(W3C_XML.Instruction(target: "pi", data: "a? >b?"))])
        }
    }
}
