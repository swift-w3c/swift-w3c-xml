import Testing

@testable import W3C_XML

enum `W3C_XML.Entity Tests` {}

extension `W3C_XML.Entity Tests` {
    @Suite
    struct `Internal entity declarations` {
        @Test
        func `an internal entity is included in content`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY name "World">]><a>Hello &name;!</a>"#)
            #expect(doc.root.textContent == "Hello World!")
        }

        @Test
        func `an internal entity is included in an attribute value as data`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY q 'say "hi"'>]><a t="&q;"/>"#)
            #expect(doc.root.attribute("t") == #"say "hi""#)
        }

        @Test
        func `markup in replacement text becomes elements`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY b "<b>bold</b>">]><a>&b;</a>"#)
            #expect(doc.root.child("b")?.textContent == "bold")
        }

        @Test
        func `nested references and character references expand`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY x "&#233;"><!ENTITY y "&x;&x;">]><a>&y;</a>"#)
            #expect(doc.root.textContent == "éé")
        }

        @Test
        func `the XML 1.0 appendix D example expands as specified`() throws {
            let doc = try W3C_XML.parse(
                """
                <!DOCTYPE a [<!ENTITY example "<p>An ampersand (&#38;#38;) may be escaped
                numerically (&#38;#38;#38;) or with a general entity
                (&amp;amp;).</p>" >]><a>&example;</a>
                """
            )
            #expect(
                doc.root.child("p")?.textContent
                    == "An ampersand (&) may be escaped\nnumerically (&#38;) or with a general entity\n(&amp;)."
            )
        }

        @Test
        func `the first declaration of an entity is binding`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY e "first"><!ENTITY e "second">]><a>&e;</a>"#)
            #expect(doc.root.textContent == "first")
        }

        @Test
        func `references in CDATA and comments are not expanded`() throws {
            let doc = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY e "x">]><a><![CDATA[&e;]]><!--&e;--></a>"#)
            #expect(doc.root.content == [.cdata("&e;"), .comment("&e;")])
        }

        @Test
        func `the same document parses from bytes`() throws {
            let doc = try W3C_XML.parse(Array(#"<!DOCTYPE a [<!ENTITY e "é">]><a>&e;</a>"#.utf8))
            #expect(doc.root.textContent == "é")
        }
    }

    @Suite
    struct `Entity failures` {
        @Test
        func `an undeclared entity is still unknown`() {
            #expect(throws: W3C_XML.Parse.Error.unknownEntity("other")) {
                _ = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY e "x">]><a>&other;</a>"#)
            }
        }

        @Test
        func `a recursive entity is refused`() {
            #expect(throws: W3C_XML.Parse.Error.recursiveEntity("a")) {
                _ = try W3C_XML.parse(#"<!DOCTYPE r [<!ENTITY a "&b;"><!ENTITY b "&a;">]><r>&a;</r>"#)
            }
        }

        @Test
        func `nesting deeper than the limit is refused`() {
            #expect(throws: W3C_XML.Parse.Error.entityDepthExceeded(limit: 2)) {
                _ = try W3C_XML.parse(
                    #"<!DOCTYPE r [<!ENTITY e1 "&e2;"><!ENTITY e2 "&e3;"><!ENTITY e3 "x">]><r>&e1;</r>"#,
                    entityLimits: { var limits = W3C_XML.Entity.Limits(); limits.depth = 2; return limits }()
                )
            }
        }

        @Test
        func `exponential expansion is stopped at the size limit`() {
            let document = """
                <!DOCTYPE r [
                <!ENTITY l0 "lol">
                <!ENTITY l1 "&l0;&l0;&l0;&l0;&l0;&l0;&l0;&l0;&l0;&l0;">
                <!ENTITY l2 "&l1;&l1;&l1;&l1;&l1;&l1;&l1;&l1;&l1;&l1;">
                <!ENTITY l3 "&l2;&l2;&l2;&l2;&l2;&l2;&l2;&l2;&l2;&l2;">
                <!ENTITY l4 "&l3;&l3;&l3;&l3;&l3;&l3;&l3;&l3;&l3;&l3;">
                <!ENTITY l5 "&l4;&l4;&l4;&l4;&l4;&l4;&l4;&l4;&l4;&l4;">
                <!ENTITY l6 "&l5;&l5;&l5;&l5;&l5;&l5;&l5;&l5;&l5;&l5;">
                <!ENTITY l7 "&l6;&l6;&l6;&l6;&l6;&l6;&l6;&l6;&l6;&l6;">
                <!ENTITY l8 "&l7;&l7;&l7;&l7;&l7;&l7;&l7;&l7;&l7;&l7;">
                <!ENTITY l9 "&l8;&l8;&l8;&l8;&l8;&l8;&l8;&l8;&l8;&l8;">
                ]><r>&l9;</r>
                """
            #expect(throws: W3C_XML.Parse.Error.entityExpansionExceeded(limit: 10_000)) {
                _ = try W3C_XML.parse(document, entityLimits: { var limits = W3C_XML.Entity.Limits(); limits.expandedBytes = 10_000; return limits }())
            }
        }

        @Test
        func `an external entity is declared but never resolved`() throws {
            let declared = #"<!DOCTYPE a [<!ENTITY ext SYSTEM "file:///etc/passwd">]>"#
            _ = try W3C_XML.parse(declared + "<a/>")
            #expect(throws: W3C_XML.Parse.Error.externalEntity("ext")) {
                _ = try W3C_XML.parse(declared + "<a>&ext;</a>")
            }
        }

        @Test
        func `replacement text that is not well-formed content is refused`() {
            #expect(throws: W3C_XML.Parse.Error.self) {
                _ = try W3C_XML.parse(#"<!DOCTYPE a [<!ENTITY open "<b>">]><a>&open;</b></a>"#)
            }
        }

        @Test
        func `declarations after a parameter-entity reference are not processed`() {
            #expect(throws: W3C_XML.Parse.Error.unknownEntity("n")) {
                _ = try W3C_XML.parse(#"<!DOCTYPE a [%pe;<!ENTITY n "x">]><a>&n;</a>"#)
            }
        }
    }
}
