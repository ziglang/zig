export fn f() void {
    const a: noreturn = {};
    _ = a;
}

// unreachable variable
//
// tmp.zig:2:25: error: expected type 'noreturn', found 'void'
