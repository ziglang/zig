const FooType = opaque {};
export fn entry1() void {
    const someFuncPtr: fn (FooType) void = undefined;
    _ = someFuncPtr;
}

export fn entry2() void {
    const someFuncPtr: fn (@TypeOf(null)) void = undefined;
    _ = someFuncPtr;
}

fn foo(p: FooType) void {_ = p;}
export fn entry3() void {
    _ = foo;
}

fn bar(p: @TypeOf(null)) void {_ = p;}
export fn entry4() void {
    _ = bar;
}

// error
// backend=stage2
// target=native
//
// :3:28: error: parameter of opaque type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
// :8:28: error: parameter of type '@TypeOf(null)' not allowed
// :12:8: error: parameter of opaque type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
// :17:8: error: parameter of type '@TypeOf(null)' not allowed
