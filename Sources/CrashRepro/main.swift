import W3C_XML
import Parsing_Primitives
import Parsing_Machine

// Exact copy from test file
func testParseWrapper(_ string: String, maxDepth: Int = 10000) throws(W3C_XML.Parse.Error) -> W3C_XML.Document {
    var input = Parsing.CollectionInput(Array(string.utf8))

    W3C_XML.Parse.Whitespace<Parsing.CollectionInput<[UInt8]>>().parse(&input)

    var declaration: W3C_XML.Declaration?
    if let byte = input.first, byte == .ascii.lessThanSign {
        let saved = input
        _ = input.removeFirst()
        if let next = input.first, next == .ascii.questionMark {
            input = saved
            if let decl = try? W3C_XML.Parse.XMLDeclaration<Parsing.CollectionInput<[UInt8]>>().parse(&input) {
                declaration = decl
            }
        } else {
            input = saved
        }
    }

    W3C_XML.Parse.Whitespace<Parsing.CollectionInput<[UInt8]>>().parse(&input)

    let machineParser = W3C_XML.Parse.machineElement(maxDepth: maxDepth)
        as Parsing.Machine.Parser<Parsing.CollectionInput<[UInt8]>, W3C_XML.Element, W3C_XML.Parse.Error>
    let root = try machineParser.parse(&input)

    return W3C_XML.Document(
        declaration: declaration,
        doctype: nil,
        root: root,
        prologue: [],
        epilogue: []
    )
}

// Test with DEFAULT maxDepth (10000)
print("Testing with default maxDepth=10000...")
for depth in [100, 200, 500, 1000] {
    var xml = ""
    for _ in 0..<depth {
        xml += "<a>"
    }
    xml += "<inner/>"
    for _ in 0..<depth {
        xml += "</a>"
    }

    do {
        _ = try testParseWrapper(xml)  // Uses default maxDepth=10000
        print("  Depth \(depth): OK")
    } catch {
        print("  Depth \(depth): FAILED - \(error)")
    }
}
