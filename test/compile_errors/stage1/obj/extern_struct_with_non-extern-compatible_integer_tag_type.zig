pub const E = enum(u31) { A, B, C };
pub const S = extern struct {
    e: E,
};
export fn entry() void {
    const s: S = undefined;
    _ = s;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: extern structs cannot contain fields of type 'E'
