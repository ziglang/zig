const __fixunstfsi = @import("fixunstfsi.zig").__fixunstfsi;
const testing = @import("std").testing;

fn test__fixunstfsi(a: f128, expected: u32) void {
    const x = __fixunstfsi(a);
    testing.expect(x == expected);
}

const inf128 = @bitCast(f128, @as(u128, 0x7fff0000000000000000000000000000));

test "fixunstfsi" {
    if (@import("std").Target.current.os.tag == .windows) {
        // TODO https://github.com/ziglang/zig/issues/508
        return error.SkipZigTest;
    }
    test__fixunstfsi(inf128, 0xffffffff);
    test__fixunstfsi(0, 0x0);
    test__fixunstfsi(0x1.23456789abcdefp+5, 0x24);
    test__fixunstfsi(0x1.23456789abcdefp-3, 0x0);
    test__fixunstfsi(0x1.23456789abcdefp+20, 0x123456);
    test__fixunstfsi(0x1.23456789abcdefp+40, 0xffffffff);
    test__fixunstfsi(0x1.23456789abcdefp+256, 0xffffffff);
    test__fixunstfsi(-0x1.23456789abcdefp+3, 0x0);

    test__fixunstfsi(0x1.p+32, 0xFFFFFFFF);
}
