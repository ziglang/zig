const Foo = struct {};
export fn a() void {
    const T = [*c]Foo;
    var t: T = undefined;
    _ = t;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:19: error: C pointers cannot point to non-C-ABI-compatible type 'Foo'
