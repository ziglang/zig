pub const A = error.A;
pub const AB = A | error.B;
export fn entry() void {
    var x: AB = undefined;
    _ = x;
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:2:18: error: invalid operands to binary expression: 'error{A}' and 'error{B}'
