const Foo = enum(f32) {
    A,
};
export fn entry() void {
    var f: Foo = undefined;
    _ = &f;
}

// error
// backend=stage2
// target=native
//
// :1:18: error: expected integer tag type, found 'f32'
