extension W3C_XML {

    public enum Entity {}
}

extension W3C_XML.Entity {

    @inlinable
    public static func predefined(_ name: String) -> Unicode.Scalar? {
        switch name {
        case "lt": return Unicode.Scalar(0x3C)
        case "gt": return Unicode.Scalar(0x3E)
        case "amp": return Unicode.Scalar(0x26)
        case "apos": return Unicode.Scalar(0x27)
        case "quot": return Unicode.Scalar(0x22)
        default: return nil
        }
    }

    @inlinable
    public static func numeric(_ reference: String) -> Unicode.Scalar? {
        guard !reference.isEmpty else { return nil }

        let codePoint: UInt32?

        if reference.hasPrefix("x") || reference.hasPrefix("X") {

            let hex = String(reference.dropFirst())
            codePoint = UInt32(hex, radix: 16)
        } else {

            codePoint = UInt32(reference, radix: 10)
        }

        guard let value = codePoint else { return nil }

        guard
            value == 0x09 || value == 0x0A || value == 0x0D || (value >= 0x20 && value <= 0xD7FF)
                || (value >= 0xE000 && value <= 0xFFFD) || (value >= 0x10000 && value <= 0x10FFFF)
        else {
            return nil
        }

        return Unicode.Scalar(value)
    }
}

extension W3C_XML.Entity {

    public static let textEscapeRequired: Set<Character> = ["<", "&"]

    public static let attributeEscapeRequired: Set<Character> = ["<", "&", "\"", "'"]

    @inlinable
    public static func escapeText(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)

        for char in text {
            switch char {
            case "<":
                result += "&lt;"

            case "&":
                result += "&amp;"

            default:
                result.append(char)
            }
        }

        return result
    }

    @inlinable
    public static func escapeAttribute(_ value: String, quote: Character = "\"") -> String {
        var result = ""
        result.reserveCapacity(value.count)

        for char in value {
            switch char {
            case "<":
                result += "&lt;"

            case "&":
                result += "&amp;"

            case "\"" where quote == "\"":
                result += "&quot;"

            case "'" where quote == "'":
                result += "&apos;"

            default:
                result.append(char)
            }
        }

        return result
    }
}
