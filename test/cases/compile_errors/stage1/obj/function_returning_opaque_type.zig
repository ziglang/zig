const FooType = opaque {};
export fn bar() !FooType {
    return error.InvalidValue;
}
export fn bav() !@TypeOf(null) {
    return error.InvalidValue;
}
export fn baz() !@TypeOf(undefined) {
    return error.InvalidValue;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:18: error: Opaque return type 'FooType' not allowed
// tmp.zig:1:1: note: type declared here
// tmp.zig:5:18: error: Null return type '@Type(.Null)' not allowed
// tmp.zig:8:18: error: Undefined return type '@Type(.Undefined)' not allowed
