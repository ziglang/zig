const Foo = union {
    A: i32,
    B: f32,
    C: bool,
};
export fn entry(foo: Foo) void {
    _ = foo;
}

// error
// target=x86_64-linux
//
// :6:17: error: parameter of type 'tmp.Foo' not allowed in function with calling convention 'x86_64_sysv'
// :6:17: note: only extern unions and ABI sized packed unions are extern compatible
// :1:13: note: union declared here
