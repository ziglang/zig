pub export fn entry1() void {
    const s = @src();
    comptime var a: []const u8 = s.file;
    comptime var b: []const u8 = s.fn_name;
    comptime var c: u32 = s.column;
    comptime var d: u32 = s.line;
    _ = a; _ = b; _ = c; _ = d;
}

// error
// backend=stage2
// target=native
//
// :6:28: error: cannot store runtime value in compile time variable
