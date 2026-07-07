/// Toolchain capability gate for the §A9 `Tagged` metadata SIGSEGV.
///
/// `W3C_XML.parse` runs the stack-safe `Parser.Machine.Parser` over `Byte.Input`
/// (= `Input.Slice<Array<Column.Shared<Byte>>>`). That input's `Index` resolves
/// to `Tagged_Primitives.Tagged<Element, Ordinal>`, so the machine parser's type
/// metadata / protocol-witness-table instantiation forces `Tagged`'s full
/// value-witness table. On Swift 6.3.x this triggers catalog §A9:
/// `swift_getTypeByMangledName` returns `TypeLookupError("unknown error")` →
/// null-metadata deref → SIGSEGV (`EXC_BAD_ACCESS`, address 0x10), observable via
/// `SWIFT_DEBUG_FAILED_TYPE_LOOKUP=1` ("failed type lookup … unknown error").
/// The crash fires before `parse` can return or throw, so even the
/// throwing/error-path tests SIGSEGV rather than catching.
///
/// Root cause: incomplete `SuppressedAssociatedTypes` codegen on 6.3 (the
/// suppressed `Ordinal.Domain: ~Copyable`); the fix travels with the compiler
/// binary and is complete by 6.4-dev. There is no Institute-side code fix — the
/// raw-storage wrapper was reverted on correctness grounds (catalog §A9,
/// 2026-05-23) — so the `parse`-exercising suites are skipped on the buggy
/// toolchain and run normally once the compiler ships the fix.
///
/// Catalog: `swift-institute/Research/swift-compiler-bug-catalog.md` §A9
/// (and its `Parser.Machine.Parser × Byte.Input` new-site addendum).
enum Toolchain {}

extension Toolchain {
    /// `true` on Swift compilers older than 6.4, where the §A9 `Tagged` metadata
    /// SIGSEGV fires. Used as the predicate for the `.disabled(if:)` trait on the
    /// `parse`-exercising suites. `.disabled(if:)` (not `withKnownIssue`) is
    /// required: a SIGSEGV kills the test runner before swift-testing can register
    /// a known issue, so only skipping the body yields a clean run on 6.3.x. The
    /// guard auto-recovers (runs the suites normally) on 6.4+.
    static var hasTaggedMetadataSIGSEGV: Bool {
        #if compiler(<6.4)
            return true
        #else
            return false
        #endif
    }
}
