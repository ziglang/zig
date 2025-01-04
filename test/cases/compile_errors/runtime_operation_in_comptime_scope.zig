export fn entry1() void {
    foo();
}

comptime {
    qux();
}

inline fn foo() void {
    _ = bar();
}

fn bar() type {
    qux();
    return u8;
}

fn qux() void {
    rt = 123;
}

var rt: u32 = undefined;

// error
//
// :19:8: error: unable to evaluate comptime expression
// :19:5: note: operation is runtime due to this operand
// :14:8: note: called at comptime from here
// :10:12: note: called at comptime from here
// :13:10: note: function with comptime-only return type 'type' is evaluated at comptime
// :13:10: note: types are not available at runtime
// :2:8: note: called from here
// :19:8: error: unable to evaluate comptime expression
// :19:5: note: operation is runtime due to this operand
// :6:8: note: called at comptime from here
// :5:1: note: 'comptime' keyword forces comptime evaluation
