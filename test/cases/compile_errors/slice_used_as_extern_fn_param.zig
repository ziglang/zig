extern fn Text(str: []const u8, num: i32) callconv(.C) void;
export fn entry() void {
    _ = Text;
}

// error
// backend=stage2
// target=native
//
// :1:16: error: parameter of type '[]const u8' not allowed in function with calling convention 'C'
// :1:16: note: slices have no guaranteed in-memory representation
