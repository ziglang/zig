const FooType = opaque {};
export fn bar() FooType {
    return error.InvalidValue;
}

// error
// backend=stage2
// target=native
//
// :2:17: error: opaque return type 'tmp.FooType' not allowed
// :1:17: note: opaque declared here
