const Foo = struct {};
export fn a() void {
    const T = [*c]Foo;
    var t: T = undefined;
    _ = t;
}

// error
// backend=stage2
// target=native
//
// :3:19: error: C pointers cannot point to non-C-ABI-compatible type 'tmp.Foo'
// :3:19: note: only structs with packed or extern layout are extern compatible
// :1:13: note: struct declared here
