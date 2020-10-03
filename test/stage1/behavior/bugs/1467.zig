pub const E = enum(u32) { A, B, C };
pub const S = extern struct {
    e: E,
};
test "bug 1467" {
    const s: S = undefined;
}
