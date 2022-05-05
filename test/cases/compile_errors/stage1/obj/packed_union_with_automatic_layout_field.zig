const Foo = struct {
    a: u32,
    b: f32,
};
const Payload = packed union {
    A: Foo,
    B: bool,
};
export fn entry() void {
    var a = Payload { .B = true };
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:5: error: non-packed, non-extern struct 'Foo' not allowed in packed union; no guaranteed in-memory representation
