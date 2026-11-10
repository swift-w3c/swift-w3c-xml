import Testing

@testable import W3C_XML

enum `W3C_XML.parse Tests` {}

extension `W3C_XML.parse Tests` {
    @Suite
    struct `Strings and bytes` {
        @Test
        func `bytes with two roots are refused like a string`() {
            #expect(throws: W3C_XML.Parse.Error.multipleRootElements) {
                _ = try W3C_XML.parse(Array("<a/><b/>".utf8))
            }
            #expect(throws: W3C_XML.Parse.Error.multipleRootElements) {
                _ = try W3C_XML.parse("<a/><b/>")
            }
        }

        @Test
        func `bytes keep the prologue and epilogue`() throws {
            let doc = try W3C_XML.parse(Array("<?xml version=\"1.0\"?><?pi data?><!--c--><a/><!--d-->".utf8))
            #expect(doc.declaration?.version == .v1_0)
            #expect(doc.prologue == [.instruction(W3C_XML.Instruction(target: "pi", data: "data")), .comment("c")])
            #expect(doc.epilogue == [.comment("d")])
        }

        @Test
        func `a UTF-8 byte order mark before the document is skipped`() throws {
            let bytes: [UInt8] = [0xEF, 0xBB, 0xBF] + Array("<?xml version=\"1.0\"?><a/>".utf8)
            let doc = try W3C_XML.parse(bytes)
            #expect(doc.declaration?.version == .v1_0)
            #expect(doc.root.name.local == "a")
            #expect(try W3C_XML.parse("\u{FEFF}<a/>").root.name.local == "a")
            var parser = W3C_XML.Parser([Byte](bitPatterns: bytes)[...])
            #expect(try parser.parse().root.name.local == "a")
        }

        @Test
        func `text after the root is refused`() {
            #expect(throws: W3C_XML.Parse.Error.self) {
                _ = try W3C_XML.parse("<a/>text")
            }
        }

        @Test
        func `a malformed XML declaration reports its own error`() {
            #expect(throws: W3C_XML.Parse.Error.expected("valid XML version (1.0 or 1.1)")) {
                _ = try W3C_XML.parse(#"<?xml version="2.0"?><a/>"#)
            }
        }
    }

    @Suite
    struct `Prologue` {
        @Test
        func `a DOCTYPE is parsed into the document`() throws {
            let doc = try W3C_XML.parse(
                #"<?xml version="1.0"?><!DOCTYPE note SYSTEM "note.dtd"><note/>"#
            )
            #expect(doc.doctype == W3C_XML.Doctype(name: "note", systemID: "note.dtd"))
            #expect(doc.root.name.local == "note")
        }

        @Test
        func `a DOCTYPE with an internal subset is parsed`() throws {
            let doc = try W3C_XML.parse("<!DOCTYPE a [<!ELEMENT a (#PCDATA)><!-- ] --><!ATTLIST a b CDATA ']'>]><a/>")
            #expect(doc.doctype?.name == "a")
            #expect(doc.doctype?.internalSubset == "<!ELEMENT a (#PCDATA)><!-- ] --><!ATTLIST a b CDATA ']'>")
        }

        @Test
        func `comments before the root are kept in order`() throws {
            let doc = try W3C_XML.parse("<!--one--><?pi?><!--two--><a/>")
            #expect(doc.prologue == [.comment("one"), .instruction(W3C_XML.Instruction(target: "pi")), .comment("two")])
        }

        @Test
        func `a second DOCTYPE is refused`() {
            #expect(throws: W3C_XML.Parse.Error.self) {
                _ = try W3C_XML.parse("<!DOCTYPE a><!DOCTYPE a><a/>")
            }
        }
    }

    @Suite
    struct `Long text` {
        @Test
        func `a million references in one text node parse`() throws {
            let count = 1_000_001
            let doc = try W3C_XML.parse("<a>" + String(repeating: "&lt;", count: count) + "</a>")
            #expect(doc.root.textContent.utf8.count == count)
        }
    }
}
