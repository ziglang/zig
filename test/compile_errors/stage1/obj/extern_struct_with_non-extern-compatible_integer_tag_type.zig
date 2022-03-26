pub const E = enum(u31) { A, B, C };
pub const S = extern struct {
    e: E,
};
export fn entry() void {
    const s: S = undefined;
    _ = s;
}

// extern struct with non-extern-compatible integer tag type
//
// tmp.zig:3:5: error: extern structs cannot contain fields of type 'E'
