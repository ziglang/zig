pub const A = error.A;
pub const AB = A | error.B;
export fn entry() void {
    var x: AB = undefined;
    _ = x;
}

// binary OR operator on error sets
//
// tmp.zig:2:18: error: invalid operands to binary expression: 'error{A}' and 'error{B}'
