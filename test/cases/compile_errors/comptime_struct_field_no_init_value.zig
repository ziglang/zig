const Foo = struct {
    comptime b: i32,
};
export fn entry() void {
    var f: Foo = undefined;
    _ = &f;
}

// error
// backend=stage2
// target=native
//
// :2:5: error: comptime field without default initialization value
