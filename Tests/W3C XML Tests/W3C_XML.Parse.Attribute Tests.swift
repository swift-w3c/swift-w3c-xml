import Byte
import Testing

@testable import W3C_XML

enum `W3C_XML.Parse.Attribute Tests` {}

extension `W3C_XML.Parse.Attribute Tests` {
    @Suite
    struct `UTF-8 values` {
        @Test
        func `a non-ASCII attribute value decodes as UTF-8`() throws {
            let doc = try W3C_XML.parse(#"<root name="café ✓ 𝄞"/>"#)
            #expect(doc.root.attribute("name") == "café ✓ 𝄞")
        }

        @Test
        func `a non-ASCII attribute value decodes as UTF-8 from bytes`() throws {
            let doc = try W3C_XML.parse(Array(#"<root name="é&amp;é"/>"#.utf8))
            #expect(doc.root.attribute("name") == "é&é")
        }

        @Test
        func `text content decodes as UTF-8`() throws {
            var input = [Byte](utf8: "é&lt;ü")[...]
            let text = try W3C_XML.Parse.TextContent<ArraySlice<Byte>>().parse(&input)
            #expect(text == "é<ü")
        }
    }
}
