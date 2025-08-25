export fn entry1() void {
    const spartan_count: u16 = 300;
    const byte: u8 = @intCast(spartan_count);
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
    _ = .{ &spartan_count, &byte };
}
export fn entry4() void {
    var signed: i8 = -1;
    var unsigned: u64 = signed;
    _ = .{ &signed, &unsigned };
}

// error
// backend=stage2
// target=native
//
// :3:31: error: type 'u8' cannot represent integer value '300'
// :8:22: error: type 'u8' cannot represent integer value '300'
// :13:20: error: expected type 'u8', found 'u16'
// :13:20: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :18:25: error: expected type 'u64', found 'i8'
// :18:25: note: unsigned 64-bit int cannot represent all possible signed 8-bit values
