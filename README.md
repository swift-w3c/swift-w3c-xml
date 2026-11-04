# swift-w3c-xml

Use this package when you need to read an XML document into a tree of elements, or write such a tree back out as UTF-8 bytes. Start from `W3C_XML.parse(_:maxDepth:)`, which returns a `W3C_XML.Document`, and write with `W3C_XML.Document.encode` or `W3C_XML.Element.encode(options:)`. For dynamic-member navigation, mapping Swift values and async streaming on top of this model, use swift-xml.

## Laws

- A document has exactly one root element. Text other than whitespace before it, or a second element after it, fails. Comments and processing instructions after the root go into `W3C_XML.Document.epilogue`. Processing instructions before it go into `W3C_XML.Document.prologue`, and comments before it are dropped.
- `W3C_XML.parse(_:maxDepth:)` does not read a DOCTYPE, so a document with one fails and `W3C_XML.Document.doctype` stays nil.
- Only the five predefined entities and numeric character references are expanded. Any other named entity fails, and a numeric reference must name a character XML allows.
- Nesting deeper than `maxDepth` fails with an error. The parser does not recurse on the call stack, so deep documents within the limit don't overflow it.
- `xmlns` and `xmlns:` attributes go into `W3C_XML.Element.namespaces`, not into `W3C_XML.Element.attributes`. Names keep their prefix and are never resolved to a namespace URI. Two attributes with the same qualified name fail.
- Text and references next to each other become one text item. Whitespace between elements is kept as text. CDATA sections and comments stay separate items, and `W3C_XML.Element.textContent` joins text and CDATA but not comments.
- Looking up children by name matches either the qualified or the local name, so a name without a prefix also finds prefixed children. Looking up an attribute by string matches the qualified name only.
- Encoding escapes `<`, `&` and `>` in text. In attribute values it escapes `<`, `&` and `"`, writes tab, LF and CR as character references so they survive attribute-value normalization, and escapes `'` only when `W3C_XML.Options.escapeApostrophe` is set. An element with no content is written as an empty-element tag.
- The XML declaration is written only when the document has one and `W3C_XML.Options.includeDeclaration` is true. Pretty-printing adds a line break and indentation before each child element, and before the end tag of an element that has child elements. An element that holds only text stays on one line.
