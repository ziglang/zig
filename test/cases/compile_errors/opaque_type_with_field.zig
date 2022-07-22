const Opaque = opaque { foo: i32 };
export fn entry() void {
    const foo: ?*Opaque = null;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :1:25: error: opaque types cannot have fields
