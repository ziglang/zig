export fn entry1() void {
    const spartan_count: u16 = 300;
    const byte = @intCast(u8, spartan_count);
    _ = byte;
}
export fn entry2() void {
    const spartan_count: u16 = 300;
    const byte: u8 = spartan_count;
    _ = byte;
}
export fn entry3() void {
    var spartan_count: u16 = 300;
    var byte: u8 = spartan_count;
    _ = byte;
}
export fn entry4() void {
    var signed: i8 = -1;
    var unsigned: u64 = signed;
    _ = unsigned;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:18: error: cast from 'u16' to 'u8' truncates bits
// tmp.zig:8:22: error: integer value 300 cannot be coerced to type 'u8'
// tmp.zig:13:20: error: expected type 'u8', found 'u16'
// tmp.zig:13:20: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// tmp.zig:18:25: error: expected type 'u64', found 'i8'
// tmp.zig:18:25: note: unsigned 64-bit int cannot represent all possible signed 8-bit values
