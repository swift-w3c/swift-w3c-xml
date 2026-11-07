import Byte
import Cursor
import Parser


extension W3C_XML.Parse {
    public struct Depth: Sendable, Hashable {

        public let value: Int

        public let limit: Int

        @inlinable
        public init(value: Int = 0, limit: Int = 512) {
            self.value = value
            self.limit = limit
        }
    }
}
