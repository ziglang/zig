const FooType = opaque {};
export fn entry1() void {
    const someFuncPtr: fn (FooType) void = undefined;
    _ = someFuncPtr;
}

fn foo(p: FooType) void {
    _ = p;
}
export fn entry3() void {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :3:28: error: parameter of opaque type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
// :7:8: error: parameter of opaque type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
