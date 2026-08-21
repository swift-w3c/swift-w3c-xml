public enum W3C_XML {}

extension W3C_XML {

    @usableFromInline
    static let whitespace: Set<Byte> = [
        ASCII.Code.sp.byte,
        ASCII.Code.htab.byte,
        ASCII.Code.cr.byte,
        ASCII.Code.lf.byte,
    ]

    @inlinable
    public static func isWhitespace(_ byte: Byte) -> Bool {
        whitespace.contains(byte)
    }
}

extension W3C_XML {

    @inlinable
    public static func isNameStartChar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return v == 0x3A
            || (v >= 0x41 && v <= 0x5A)
            || v == 0x5F
            || (v >= 0x61 && v <= 0x7A)
            || (v >= 0xC0 && v <= 0xD6) || (v >= 0xD8 && v <= 0xF6) || (v >= 0xF8 && v <= 0x2FF)
            || (v >= 0x370 && v <= 0x37D) || (v >= 0x37F && v <= 0x1FFF)
            || (v >= 0x200C && v <= 0x200D)
            || (v >= 0x2070 && v <= 0x218F) || (v >= 0x2C00 && v <= 0x2FEF)
            || (v >= 0x3001 && v <= 0xD7FF) || (v >= 0xF900 && v <= 0xFDCF)
            || (v >= 0xFDF0 && v <= 0xFFFD)
            || (v >= 0x10000 && v <= 0xEFFFF)
    }

    @inlinable
    public static func isNameChar(_ scalar: Unicode.Scalar) -> Bool {
        if isNameStartChar(scalar) { return true }
        let v = scalar.value
        return v == 0x2D
            || v == 0x2E
            || (v >= 0x30 && v <= 0x39)
            || v == 0xB7
            || (v >= 0x0300 && v <= 0x036F)
            || (v >= 0x203F && v <= 0x2040)
    }

    @inlinable
    public static func isASCIINameStartChar(_ byte: Byte) -> Bool {
        byte == ASCII.Code.colon.byte || (byte >= ASCII.Code.A.byte && byte <= ASCII.Code.Z.byte)
            || byte == ASCII.Code.underline.byte
            || (byte >= ASCII.Code.a.byte && byte <= ASCII.Code.z.byte)
    }

    @inlinable
    public static func isASCIINameChar(_ byte: Byte) -> Bool {
        isASCIINameStartChar(byte) || byte == ASCII.Code.hyphen.byte
            || byte == ASCII.Code.period.byte || (byte >= .ascii.`0` && byte <= .ascii.`9`)
    }
}

extension W3C_XML {

    @inlinable
    public static func isChar(_ scalar: Unicode.Scalar) -> Bool {
        let v = scalar.value
        return v == 0x09 || v == 0x0A || v == 0x0D || (v >= 0x20 && v <= 0xD7FF)
            || (v >= 0xE000 && v <= 0xFFFD) || (v >= 0x10000 && v <= 0x10FFFF)
    }
}
