const Foo = struct { a: u32 };
export fn a() void {
    const T = [*c]Foo;
    const t: T = undefined;
    _ = t;
}

// error
// backend=stage2
// target=native
//
// :3:19: error: C pointers cannot point to non-C-ABI-compatible type 'tmp.Foo'
// :3:19: note: only extern structs and ABI sized packed structs are extern compatible
// :1:13: note: struct declared here
