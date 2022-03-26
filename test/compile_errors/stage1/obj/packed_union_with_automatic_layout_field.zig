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

// packed union with automatic layout field
//
// tmp.zig:6:5: error: non-packed, non-extern struct 'Foo' not allowed in packed union; no guaranteed in-memory representation
