const Foo = enum(f32) {
    A,
};
export fn entry() void {
    var f: Foo = undefined;
    _ = &f;
}

// error
//
// :1:18: error: expected integer tag type, found 'f32'
