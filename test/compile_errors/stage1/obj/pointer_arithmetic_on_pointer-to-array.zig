export fn foo() void {
    var x: [10]u8 = undefined;
    var y = &x;
    var z = y + 1;
    _ = z;
}

// pointer arithmetic on pointer-to-array
//
// tmp.zig:4:17: error: integer value 1 cannot be coerced to type '*[10]u8'
