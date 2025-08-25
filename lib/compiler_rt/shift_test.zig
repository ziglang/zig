const testing = @import("std").testing;
const shift = @import("shift.zig");

// arithmetic shift left
const __ashlsi3 = shift.__ashlsi3;
const __ashldi3 = shift.__ashldi3;
const __ashlti3 = shift.__ashlti3;

// arithmetic shift right
const __ashrsi3 = shift.__ashrsi3;
const __ashrdi3 = shift.__ashrdi3;
const __ashrti3 = shift.__ashrti3;

// logic shift right
const __lshrsi3 = shift.__lshrsi3;
const __lshrdi3 = shift.__lshrdi3;
const __lshrti3 = shift.__lshrti3;

fn test__ashlsi3(a: i32, b: i32, expected: u32) !void {
    const x = __ashlsi3(a, b);
    try testing.expectEqual(expected, @as(u32, @bitCast(x)));
}
fn test__ashldi3(a: i64, b: i32, expected: u64) !void {
    const x = __ashldi3(a, b);
    try testing.expectEqual(expected, @as(u64, @bitCast(x)));
}
fn test__ashlti3(a: i128, b: i32, expected: u128) !void {
    const x = __ashlti3(a, b);
    try testing.expectEqual(expected, @as(u128, @bitCast(x)));
}

test "ashlsi3" {
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 0, 0x12ABCDEF);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 1, 0x25579BDE);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 2, 0x4AAF37BC);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 3, 0x955E6F78);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 4, 0x2ABCDEF0);

    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 28, 0xF0000000);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 29, 0xE0000000);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 30, 0xC0000000);
    try test__ashlsi3(@as(i32, @bitCast(@as(u32, 0x12ABCDEF))), 31, 0x80000000);
}

test "ashldi3" {
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 0, 0x123456789ABCDEF);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 1, 0x2468ACF13579BDE);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 2, 0x48D159E26AF37BC);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 3, 0x91A2B3C4D5E6F78);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 4, 0x123456789ABCDEF0);

    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 28, 0x789ABCDEF0000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 29, 0xF13579BDE0000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 30, 0xE26AF37BC0000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 31, 0xC4D5E6F780000000);

    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 32, 0x89ABCDEF00000000);

    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 33, 0x13579BDE00000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 34, 0x26AF37BC00000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 35, 0x4D5E6F7800000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 36, 0x9ABCDEF000000000);

    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 60, 0xF000000000000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 61, 0xE000000000000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 62, 0xC000000000000000);
    try test__ashldi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 63, 0x8000000000000000);
}

test "ashlti3" {
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 0, 0xFEDCBA9876543215FEDCBA9876543215);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 1, 0xFDB97530ECA8642BFDB97530ECA8642A);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 2, 0xFB72EA61D950C857FB72EA61D950C854);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 3, 0xF6E5D4C3B2A190AFF6E5D4C3B2A190A8);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 4, 0xEDCBA9876543215FEDCBA98765432150);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 28, 0x876543215FEDCBA98765432150000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 29, 0x0ECA8642BFDB97530ECA8642A0000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 30, 0x1D950C857FB72EA61D950C8540000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 31, 0x3B2A190AFF6E5D4C3B2A190A80000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 32, 0x76543215FEDCBA987654321500000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 33, 0xECA8642BFDB97530ECA8642A00000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 34, 0xD950C857FB72EA61D950C85400000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 35, 0xB2A190AFF6E5D4C3B2A190A800000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 36, 0x6543215FEDCBA9876543215000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 60, 0x5FEDCBA9876543215000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 61, 0xBFDB97530ECA8642A000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 62, 0x7FB72EA61D950C854000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 63, 0xFF6E5D4C3B2A190A8000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 64, 0xFEDCBA98765432150000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 65, 0xFDB97530ECA8642A0000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 66, 0xFB72EA61D950C8540000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 67, 0xF6E5D4C3B2A190A80000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 68, 0xEDCBA987654321500000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 92, 0x87654321500000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 93, 0x0ECA8642A00000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 94, 0x1D950C85400000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 95, 0x3B2A190A800000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 96, 0x76543215000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 97, 0xECA8642A000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 98, 0xD950C854000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 99, 0xB2A190A8000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 100, 0x65432150000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 124, 0x50000000000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 125, 0xA0000000000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 126, 0x40000000000000000000000000000000);
    try test__ashlti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 127, 0x80000000000000000000000000000000);
}

fn test__ashrsi3(a: i32, b: i32, expected: u32) !void {
    const x = __ashrsi3(a, b);
    try testing.expectEqual(expected, @as(u32, @bitCast(x)));
}
fn test__ashrdi3(a: i64, b: i32, expected: u64) !void {
    const x = __ashrdi3(a, b);
    try testing.expectEqual(expected, @as(u64, @bitCast(x)));
}
fn test__ashrti3(a: i128, b: i32, expected: u128) !void {
    const x = __ashrti3(a, b);
    try testing.expectEqual(expected, @as(u128, @bitCast(x)));
}

test "ashrsi3" {
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 0, 0xFEDBCA98);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 1, 0xFF6DE54C);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 2, 0xFFB6F2A6);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 3, 0xFFDB7953);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 4, 0xFFEDBCA9);

    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 28, 0xFFFFFFFF);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 31, 0xFFFFFFFF);

    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 0, 0x8CEF8CEF);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 1, 0xC677C677);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 2, 0xE33BE33B);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 3, 0xF19DF19D);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 4, 0xF8CEF8CE);

    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 28, 0xFFFFFFF8);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 29, 0xFFFFFFFC);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 30, 0xFFFFFFFE);
    try test__ashrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 31, 0xFFFFFFFF);
}

test "ashrdi3" {
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 0, 0x123456789ABCDEF);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 1, 0x91A2B3C4D5E6F7);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 2, 0x48D159E26AF37B);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 3, 0x2468ACF13579BD);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 4, 0x123456789ABCDE);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 28, 0x12345678);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 29, 0x91A2B3C);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 30, 0x48D159E);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 31, 0x2468ACF);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 32, 0x1234567);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 33, 0x91A2B3);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 34, 0x48D159);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 35, 0x2468AC);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 36, 0x123456);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 60, 0);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 61, 0);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 62, 0);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 63, 0);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 0, 0xFEDCBA9876543210);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 1, 0xFF6E5D4C3B2A1908);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 2, 0xFFB72EA61D950C84);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 3, 0xFFDB97530ECA8642);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 4, 0xFFEDCBA987654321);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 28, 0xFFFFFFFFEDCBA987);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 29, 0xFFFFFFFFF6E5D4C3);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 30, 0xFFFFFFFFFB72EA61);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 31, 0xFFFFFFFFFDB97530);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 32, 0xFFFFFFFFFEDCBA98);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 33, 0xFFFFFFFFFF6E5D4C);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 34, 0xFFFFFFFFFFB72EA6);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 35, 0xFFFFFFFFFFDB9753);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 36, 0xFFFFFFFFFFEDCBA9);

    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 60, 0xFFFFFFFFFFFFFFFA);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 61, 0xFFFFFFFFFFFFFFFD);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 62, 0xFFFFFFFFFFFFFFFE);
    try test__ashrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 63, 0xFFFFFFFFFFFFFFFF);
}

test "ashrti3" {
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 0, 0xFEDCBA9876543215FEDCBA9876543215);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 1, 0xFF6E5D4C3B2A190AFF6E5D4C3B2A190A);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 2, 0xFFB72EA61D950C857FB72EA61D950C85);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 3, 0xFFDB97530ECA8642BFDB97530ECA8642);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 4, 0xFFEDCBA9876543215FEDCBA987654321);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 28, 0xFFFFFFFFEDCBA9876543215FEDCBA987);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 29, 0xFFFFFFFFF6E5D4C3B2A190AFF6E5D4C3);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 30, 0xFFFFFFFFFB72EA61D950C857FB72EA61);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 31, 0xFFFFFFFFFDB97530ECA8642BFDB97530);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 32, 0xFFFFFFFFFEDCBA9876543215FEDCBA98);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 33, 0xFFFFFFFFFF6E5D4C3B2A190AFF6E5D4C);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 34, 0xFFFFFFFFFFB72EA61D950C857FB72EA6);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 35, 0xFFFFFFFFFFDB97530ECA8642BFDB9753);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 36, 0xFFFFFFFFFFEDCBA9876543215FEDCBA9);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 60, 0xFFFFFFFFFFFFFFFFEDCBA9876543215F);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 61, 0xFFFFFFFFFFFFFFFFF6E5D4C3B2A190AF);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 62, 0xFFFFFFFFFFFFFFFFFB72EA61D950C857);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 63, 0xFFFFFFFFFFFFFFFFFDB97530ECA8642B);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 64, 0xFFFFFFFFFFFFFFFFFEDCBA9876543215);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 65, 0xFFFFFFFFFFFFFFFFFF6E5D4C3B2A190A);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 66, 0xFFFFFFFFFFFFFFFFFFB72EA61D950C85);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 67, 0xFFFFFFFFFFFFFFFFFFDB97530ECA8642);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 68, 0xFFFFFFFFFFFFFFFFFFEDCBA987654321);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 92, 0xFFFFFFFFFFFFFFFFFFFFFFFFEDCBA987);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 93, 0xFFFFFFFFFFFFFFFFFFFFFFFFF6E5D4C3);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 94, 0xFFFFFFFFFFFFFFFFFFFFFFFFFB72EA61);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 95, 0xFFFFFFFFFFFFFFFFFFFFFFFFFDB97530);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 96, 0xFFFFFFFFFFFFFFFFFFFFFFFFFEDCBA98);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 97, 0xFFFFFFFFFFFFFFFFFFFFFFFFFF6E5D4C);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 98, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFB72EA6);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 99, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFDB9753);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 100, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFEDCBA9);

    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 124, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 125, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 126, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    try test__ashrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA9876543215))), 127, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
}

fn test__lshrsi3(a: i32, b: i32, expected: u32) !void {
    const x = __lshrsi3(a, b);
    try testing.expectEqual(expected, @as(u32, @bitCast(x)));
}
fn test__lshrdi3(a: i64, b: i32, expected: u64) !void {
    const x = __lshrdi3(a, b);
    try testing.expectEqual(expected, @as(u64, @bitCast(x)));
}
fn test__lshrti3(a: i128, b: i32, expected: u128) !void {
    const x = __lshrti3(a, b);
    try testing.expectEqual(expected, @as(u128, @bitCast(x)));
}

test "lshrsi3" {
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 0, 0xFEDBCA98);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 1, 0x7F6DE54C);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 2, 0x3FB6F2A6);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 3, 0x1FDB7953);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 4, 0xFEDBCA9);

    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 28, 0xF);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 29, 0x7);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 30, 0x3);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0xFEDBCA98))), 31, 0x1);

    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 0, 0x8CEF8CEF);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 1, 0x4677C677);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 2, 0x233BE33B);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 3, 0x119DF19D);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 4, 0x8CEF8CE);

    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 28, 0x8);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 29, 0x4);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 30, 0x2);
    try test__lshrsi3(@as(i32, @bitCast(@as(u32, 0x8CEF8CEF))), 31, 0x1);
}

test "lshrdi3" {
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 0, 0x123456789ABCDEF);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 1, 0x91A2B3C4D5E6F7);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 2, 0x48D159E26AF37B);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 3, 0x2468ACF13579BD);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 4, 0x123456789ABCDE);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 28, 0x12345678);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 29, 0x91A2B3C);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 30, 0x48D159E);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 31, 0x2468ACF);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 32, 0x1234567);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 33, 0x91A2B3);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 34, 0x48D159);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 35, 0x2468AC);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 36, 0x123456);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 60, 0);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 61, 0);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 62, 0);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0x0123456789ABCDEF))), 63, 0);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 0, 0xFEDCBA9876543210);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 1, 0x7F6E5D4C3B2A1908);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 2, 0x3FB72EA61D950C84);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 3, 0x1FDB97530ECA8642);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 4, 0xFEDCBA987654321);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 28, 0xFEDCBA987);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 29, 0x7F6E5D4C3);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 30, 0x3FB72EA61);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 31, 0x1FDB97530);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 32, 0xFEDCBA98);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 33, 0x7F6E5D4C);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 34, 0x3FB72EA6);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 35, 0x1FDB9753);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xFEDCBA9876543210))), 36, 0xFEDCBA9);

    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 60, 0xA);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 61, 0x5);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 62, 0x2);
    try test__lshrdi3(@as(i64, @bitCast(@as(u64, 0xAEDCBA9876543210))), 63, 0x1);
}

test "lshrti3" {
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 0, 0xFEDCBA9876543215FEDCBA987654321F);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 1, 0x7F6E5D4C3B2A190AFF6E5D4C3B2A190F);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 2, 0x3FB72EA61D950C857FB72EA61D950C87);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 3, 0x1FDB97530ECA8642BFDB97530ECA8643);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 4, 0xFEDCBA9876543215FEDCBA987654321);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 28, 0xFEDCBA9876543215FEDCBA987);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 29, 0x7F6E5D4C3B2A190AFF6E5D4C3);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 30, 0x3FB72EA61D950C857FB72EA61);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 31, 0x1FDB97530ECA8642BFDB97530);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 32, 0xFEDCBA9876543215FEDCBA98);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 33, 0x7F6E5D4C3B2A190AFF6E5D4C);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 34, 0x3FB72EA61D950C857FB72EA6);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 35, 0x1FDB97530ECA8642BFDB9753);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 36, 0xFEDCBA9876543215FEDCBA9);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 60, 0xFEDCBA9876543215F);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 61, 0x7F6E5D4C3B2A190AF);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 62, 0x3FB72EA61D950C857);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 63, 0x1FDB97530ECA8642B);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 64, 0xFEDCBA9876543215);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 65, 0x7F6E5D4C3B2A190A);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 66, 0x3FB72EA61D950C85);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 67, 0x1FDB97530ECA8642);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 68, 0xFEDCBA987654321);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 92, 0xFEDCBA987);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 93, 0x7F6E5D4C3);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 94, 0x3FB72EA61);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 95, 0x1FDB97530);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 96, 0xFEDCBA98);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 97, 0x7F6E5D4C);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 98, 0x3FB72EA6);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 99, 0x1FDB9753);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 100, 0xFEDCBA9);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 124, 0xF);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 125, 0x7);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 126, 0x3);
    try test__lshrti3(@as(i128, @bitCast(@as(u128, 0xFEDCBA9876543215FEDCBA987654321F))), 127, 0x1);
}
