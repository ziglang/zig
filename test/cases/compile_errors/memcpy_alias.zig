var arr: [10]u64 = undefined;
export fn foo() void {
    @memcpy(arr[0..6], arr[4..10]);
}

comptime {
    var types: [4]type = .{ u8, u16, u32, u64 };
    @memcpy(types[2..4], types[1..3]);
}

// error
//
// :3:5: error: '@memcpy' arguments alias
// :8:5: error: '@memcpy' arguments alias
