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
// :3:5: error: extern structs cannot contain fields of type 'tmp.E'
// :3:5: note: enum tag type 'u31' is not extern compatible
// :3:5: note: only integers with power of two bits are extern compatible
// :1:15: note: enum declared here
