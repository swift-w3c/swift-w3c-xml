extension W3C_XML {

    public struct Document: Sendable, Hashable {

        public var declaration: Declaration?

        public var doctype: Doctype?

        public var root: Element

        public var prologue: [Instruction]

        public var epilogue: [Content]

        @inlinable
        public init(
            declaration: Declaration? = nil,
            doctype: Doctype? = nil,
            root: Element,
            prologue: [Instruction] = [],
            epilogue: [Content] = []
        ) {
            self.declaration = declaration
            self.doctype = doctype
            self.root = root
            self.prologue = prologue
            self.epilogue = epilogue
        }
    }
}

extension W3C_XML.Document: CustomStringConvertible {
    public var description: String {
        var result = ""

        if let declaration {
            result += declaration.description
            result += "\n"
        }

        if let doctype {
            result += doctype.description
            result += "\n"
        }

        for instruction in prologue {
            result += instruction.description
            result += "\n"
        }

        result += root.description

        for item in epilogue {
            result += "\n"
            result += item.description
        }

        return result
    }
}
