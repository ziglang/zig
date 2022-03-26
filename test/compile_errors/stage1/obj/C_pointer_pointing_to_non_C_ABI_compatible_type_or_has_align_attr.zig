const Foo = struct {};
export fn a() void {
    const T = [*c]Foo;
    var t: T = undefined;
    _ = t;
}

// C pointer pointing to non C ABI compatible type or has align attr
//
// tmp.zig:3:19: error: C pointers cannot point to non-C-ABI-compatible type 'Foo'
