export fn a(x: [*]u8) void {
    _ = x * 1;
}

export fn b(x: *u8) void {
    _ = x * x;
}

export fn c() void {
    const x: []u8 = undefined;
    const y: []u8 = undefined;
    _ = x - y;
}

export fn d() void {
    var x: [*]u8 = undefined;
    var y: [*]u16 = undefined;
    _ = &x;
    _ = &y;
    _ = x - y;
}

comptime {
    const x: *u8 = @ptrFromInt(1);
    const y: *u16 = @ptrFromInt(2);
    _ = x - y;
}

comptime {
    const x: [*]u0 = @ptrFromInt(1);
    _ = x + 1;
}

comptime {
    const x: *u0 = @ptrFromInt(1);
    const y: *u0 = @ptrFromInt(2);
    _ = x - y;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: invalid pointer-integer arithmetic operator
// :2:11: note: pointer-integer arithmetic only supports addition and subtraction
// :6:11: error: invalid pointer-pointer arithmetic operator
// :6:11: note: pointer-pointer arithmetic only supports subtraction
// :12:11: error: invalid operands to binary expression: 'pointer' and 'pointer'
// :20:11: error: incompatible pointer arithmetic operands '[*]u8' and '[*]u16'
// :26:11: error: incompatible pointer arithmetic operands '*u8' and '*u16'
// :31:11: error: pointer arithmetic requires element type 'u0' to have runtime bits
// :37:11: error: pointer arithmetic requires element type 'u0' to have runtime bits
