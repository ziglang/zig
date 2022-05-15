export fn entry1() void {
    const T = u65536;
    _ = T;
}
export fn entry2() void {
    var x: i65536 = 1;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: primitive integer type 'u65536' exceeds maximum bit width of 65535
// tmp.zig:6:12: error: primitive integer type 'i65536' exceeds maximum bit width of 65535
