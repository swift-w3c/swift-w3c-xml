import Testing

@testable import W3C_XML

@Suite
struct `Character reference grammar` {
    @Test(arguments: ["X41", "x+41", "+65", "-0", "x", ""])
    func `a reference outside the CharRef production is refused`(_ reference: String) {
        #expect(W3C_XML.Entity.numeric(reference) == nil)
    }

    @Test
    func `decimal and lowercase-x hexadecimal references decode`() {
        #expect(W3C_XML.Entity.numeric("65") == "A")
        #expect(W3C_XML.Entity.numeric("x41") == "A")
        #expect(W3C_XML.Entity.numeric("x4a") == "J")
    }
}
