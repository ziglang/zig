const c = @cImport({
    if (foo == 0) {}
});
extern var foo: i32;
export fn entry() void {
    _ = c;
}

// error
//
// :2:13: error: unable to evaluate comptime expression
// :2:9: note: operation is runtime due to this operand
// :1:11: note: operand to '@cImport' is evaluated at comptime
