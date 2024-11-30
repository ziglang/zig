extern fn Text(str: []const u8, num: i32) callconv(.c) void;
export fn entry() void {
    _ = Text;
}

// error
// target=x86_64-linux
//
// :1:16: error: parameter of type '[]const u8' not allowed in function with calling convention 'x86_64_sysv'
// :1:16: note: slices have no guaranteed in-memory representation
