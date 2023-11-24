const cmp = @import("cmp.zig");
const testing = @import("std").testing;

fn test__ucmpsi2(a: u32, b: u32, expected: i32) !void {
    const result = cmp.__ucmpsi2(a, b);
    try testing.expectEqual(expected, result);
}

test "ucmpsi2" {
    // minInt == 0
    // maxInt == 4294967295
    // minInt/2 == 0
    // maxInt/2 == 2147483647
    // 1. equality   0, 1 maxInt/2, maxInt-1, maxInt
    try test__ucmpsi2(0, 0, 1);
    try test__ucmpsi2(1, 1, 1);
    try test__ucmpsi2(2147483647, 2147483647, 1);
    try test__ucmpsi2(4294967294, 4294967294, 1);
    try test__ucmpsi2(4294967295, 4294967295, 1);
    // 2. cmp minInt,   {0, 1, maxInt/2, maxInt-1, maxInt}
    try test__ucmpsi2(0, 1, 0);
    try test__ucmpsi2(0, 2147483647, 0);
    try test__ucmpsi2(0, 4294967294, 0);
    try test__ucmpsi2(0, 4294967295, 0);
    // 3. cmp minInt+1, {minInt, 0,    maxInt/2, maxInt-1, maxInt}
    try test__ucmpsi2(1, 0, 2);
    try test__ucmpsi2(1, 2147483647, 0);
    try test__ucmpsi2(1, 4294967294, 0);
    try test__ucmpsi2(1, 4294967295, 0);
    // 4. cmp minInt/2==minInt, {}
    // 5. cmp -1        {}
    // 6. cmp 0==minInt,{}
    // 7. cmp 1==minInt+1,        {}
    // 8. cmp maxInt/2, {0, maxInt-1, maxInt}
    try test__ucmpsi2(2147483647, 0, 2);
    try test__ucmpsi2(2147483647, 1, 2);
    try test__ucmpsi2(2147483647, 4294967294, 0);
    try test__ucmpsi2(2147483647, 4294967295, 0);
    // 9. cmp maxInt-1, {0,1,2, maxInt/2, maxInt}
    try test__ucmpsi2(4294967294, 0, 2);
    try test__ucmpsi2(4294967294, 1, 2);
    try test__ucmpsi2(4294967294, 2147483647, 2);
    try test__ucmpsi2(4294967294, 4294967295, 0);
    // 10.cmp maxInt,   {0,1,2, maxInt/2, maxInt-1}
    try test__ucmpsi2(4294967295, 0, 2);
    try test__ucmpsi2(4294967295, 1, 2);
    try test__ucmpsi2(4294967295, 2147483647, 2);
    try test__ucmpsi2(4294967295, 4294967294, 2);
}
