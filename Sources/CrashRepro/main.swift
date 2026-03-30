import W3C_XML

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
        _ = try W3C_XML.parse(xml)
        print("  Depth \(depth): OK")
    } catch {
        print("  Depth \(depth): FAILED - \(error)")
    }
}
