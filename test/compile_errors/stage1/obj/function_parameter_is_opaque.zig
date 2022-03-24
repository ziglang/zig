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

// function parameter is opaque
//
// tmp.zig:3:28: error: parameter of opaque type 'FooType' not allowed
// tmp.zig:8:28: error: parameter of type '@Type(.Null)' not allowed
// tmp.zig:12:11: error: parameter of opaque type 'FooType' not allowed
// tmp.zig:17:11: error: parameter of type '@Type(.Null)' not allowed
