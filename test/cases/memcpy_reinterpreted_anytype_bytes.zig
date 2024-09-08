fn tracef(args: anytype) void {
    var packed_args: [4]u8 = undefined;
    const val: i32 = args[0];
    const src: *const [4]u8 = @ptrCast(&val);
    @memcpy(&packed_args, src);
}

pub export fn main() void {
    tracef(.{4});
}

// compile
//
