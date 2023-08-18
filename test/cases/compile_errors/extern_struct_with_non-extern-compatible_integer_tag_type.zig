pub const E = enum(u31) { A, B, C };
pub const S = extern struct {
    e: E,
};
export fn entry() void {
    const s: S = undefined;
    _ = s;
}

// error
// backend=stage2
// target=native
//
// :3:8: error: extern structs cannot contain fields of type 'tmp.E'
// :3:8: note: enum tag type 'u31' is not extern compatible
// :3:8: note: only integers with 0 or power of two bits are extern compatible
// :1:15: note: enum declared here
