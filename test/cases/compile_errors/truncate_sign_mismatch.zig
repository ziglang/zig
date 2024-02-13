export fn entry1() i8 {
    var x: u32 = 10;
    return @truncate((&x).*);
}
export fn entry2() u8 {
    var x: i32 = -10;
    return @truncate((&x).*);
}
export fn entry3() i8 {
    comptime var x: u32 = 10;
    return @truncate((&x).*);
}
export fn entry4() u8 {
    comptime var x: i32 = -10;
    return @truncate((&x).*);
}

// error
// backend=stage2
// target=native
//
// :3:26: error: expected signed integer type, found 'u32'
// :7:26: error: expected unsigned integer type, found 'i32'
// :11:26: error: expected signed integer type, found 'u32'
// :15:26: error: expected unsigned integer type, found 'i32'
