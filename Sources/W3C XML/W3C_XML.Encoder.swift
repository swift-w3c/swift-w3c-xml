
extension W3C_XML {
    @usableFromInline
    internal struct Encoder {
        @usableFromInline
        let options: Options

        @usableFromInline
        var depth: Int = 0

        @usableFromInline
        init(options: Options) {
            self.options = options
        }
    }
}
