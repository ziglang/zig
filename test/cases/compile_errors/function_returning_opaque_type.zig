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
// backend=stage2
// target=native
//
// :2:18: error: opaque return type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
// :5:18: error: return type '@TypeOf(null)' not allowed
// :8:18: error: return type '@TypeOf(undefined)' not allowed
