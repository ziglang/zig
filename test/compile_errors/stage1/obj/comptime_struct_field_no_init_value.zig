const Foo = struct {
    comptime b: i32,
};
export fn entry() void {
    var f: Foo = undefined;
    _ = f;
}

// comptime struct field, no init value
//
// tmp.zig:2:5: error: comptime field without default initialization value
