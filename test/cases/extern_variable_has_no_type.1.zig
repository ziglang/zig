export fn entry() void {
    _ = foo;
}
extern var foo;

// error
//
// :4:8: error: unable to infer variable type
