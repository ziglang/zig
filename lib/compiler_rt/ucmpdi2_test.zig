const cmp = @import("cmp.zig");
const testing = @import("std").testing;

fn test__ucmpdi2(a: u64, b: u64, expected: i32) !void {
    const result = cmp.__ucmpdi2(a, b);
    try testing.expectEqual(expected, result);
}

test "ucmpdi2" {
    // minInt == 0
    // maxInt == 18446744073709551615
    // minInt/2 == 0
    // maxInt/2 == 9223372036854775807
    // 1. equality minInt, minInt/2, 0, maxInt/2, maxInt
    try test__ucmpdi2(0, 0, 1);
    try test__ucmpdi2(1, 1, 1);
    try test__ucmpdi2(9223372036854775807, 9223372036854775807, 1);
    try test__ucmpdi2(18446744073709551614, 18446744073709551614, 1);
    try test__ucmpdi2(18446744073709551615, 18446744073709551615, 1);
    // 2. cmp minInt,   {minInt + 1, maxInt/2, maxInt-1, maxInt}
    try test__ucmpdi2(0, 1, 0);
    try test__ucmpdi2(0, 9223372036854775807, 0);
    try test__ucmpdi2(0, 18446744073709551614, 0);
    try test__ucmpdi2(0, 18446744073709551615, 0);
    // 3. cmp minInt+1, {minInt, maxInt/2, maxInt-1, maxInt}
    try test__ucmpdi2(1, 0, 2);
    try test__ucmpdi2(1, 9223372036854775807, 0);
    try test__ucmpdi2(1, 18446744073709551614, 0);
    try test__ucmpdi2(1, 18446744073709551615, 0);
    // 4. cmp minInt/2, {}
    // 5. cmp -1,       {}
    // 6. cmp 0,        {}
    // 7. cmp 1,        {}
    // 8. cmp maxInt/2, {minInt, minInt+1, maxInt-1, maxInt}
    try test__ucmpdi2(9223372036854775807, 0, 2);
    try test__ucmpdi2(9223372036854775807, 1, 2);
    try test__ucmpdi2(9223372036854775807, 18446744073709551614, 0);
    try test__ucmpdi2(9223372036854775807, 18446744073709551615, 0);
    // 9. cmp maxInt-1, {minInt, minInt + 1, maxInt/2, maxInt}
    try test__ucmpdi2(18446744073709551614, 0, 2);
    try test__ucmpdi2(18446744073709551614, 1, 2);
    try test__ucmpdi2(18446744073709551614, 9223372036854775807, 2);
    try test__ucmpdi2(18446744073709551614, 18446744073709551615, 0);
    // 10.cmp maxInt,   {minInt, 1, maxInt/2, maxInt-1}
    try test__ucmpdi2(18446744073709551615, 0, 2);
    try test__ucmpdi2(18446744073709551615, 1, 2);
    try test__ucmpdi2(18446744073709551615, 9223372036854775807, 2);
    try test__ucmpdi2(18446744073709551615, 18446744073709551614, 2);
}
