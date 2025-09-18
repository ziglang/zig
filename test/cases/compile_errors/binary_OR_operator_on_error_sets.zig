pub const A = error.A;
pub const AB = A | error.B;
export fn entry() void {
    const x: AB = undefined;
    _ = x;
}

// error
//
// :2:18: error: invalid operands to binary bitwise expression: 'error_set' and 'error_set'
