const cmp = @import("cmp.zig");
const testing = @import("std").testing;

fn test__cmpsi2(a: i32, b: i32, expected: i32) !void {
    const result = cmp.__cmpsi2(a, b);
    try testing.expectEqual(expected, result);
}

test "cmpsi2" {
    // minInt == -2147483648
    // maxInt == 2147483647
    // minInt/2 == -1073741824
    // maxInt/2 == 1073741823
    // 1. equality minInt, minInt+1, minInt/2, -1, 0, 1, maxInt/2, maxInt-1, maxInt
    try test__cmpsi2(-2147483648, -2147483648, 1);
    try test__cmpsi2(-2147483647, -2147483647, 1);
    try test__cmpsi2(-1073741824, -1073741824, 1);
    try test__cmpsi2(-1, -1, 1);
    try test__cmpsi2(0, 0, 1);
    try test__cmpsi2(1, 1, 1);
    try test__cmpsi2(1073741823, 1073741823, 1);
    try test__cmpsi2(2147483646, 2147483646, 1);
    try test__cmpsi2(2147483647, 2147483647, 1);
    // 2. cmp minInt,   {        minInt + 1, minInt/2, -1,0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(-2147483648, -2147483647, 0);
    try test__cmpsi2(-2147483648, -1073741824, 0);
    try test__cmpsi2(-2147483648, -1, 0);
    try test__cmpsi2(-2147483648, 0, 0);
    try test__cmpsi2(-2147483648, 1, 0);
    try test__cmpsi2(-2147483648, 1073741823, 0);
    try test__cmpsi2(-2147483648, 2147483646, 0);
    try test__cmpsi2(-2147483648, 2147483647, 0);
    // 3. cmp minInt+1, {minInt,             minInt/2, -1,0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(-2147483647, -2147483648, 2);
    try test__cmpsi2(-2147483647, -1073741824, 0);
    try test__cmpsi2(-2147483647, -1, 0);
    try test__cmpsi2(-2147483647, 0, 0);
    try test__cmpsi2(-2147483647, 1, 0);
    try test__cmpsi2(-2147483647, 1073741823, 0);
    try test__cmpsi2(-2147483647, 2147483646, 0);
    try test__cmpsi2(-2147483647, 2147483647, 0);
    // 4. cmp minInt/2, {minInt, minInt + 1,           -1,0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(-1073741824, -2147483648, 2);
    try test__cmpsi2(-1073741824, -2147483647, 2);
    try test__cmpsi2(-1073741824, -1, 0);
    try test__cmpsi2(-1073741824, 0, 0);
    try test__cmpsi2(-1073741824, 1, 0);
    try test__cmpsi2(-1073741824, 1073741823, 0);
    try test__cmpsi2(-1073741824, 2147483646, 0);
    try test__cmpsi2(-1073741824, 2147483647, 0);
    // 5. cmp -1,       {minInt, minInt + 1, minInt/2,    0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(-1, -2147483648, 2);
    try test__cmpsi2(-1, -2147483647, 2);
    try test__cmpsi2(-1, -1073741824, 2);
    try test__cmpsi2(-1, 0, 0);
    try test__cmpsi2(-1, 1, 0);
    try test__cmpsi2(-1, 1073741823, 0);
    try test__cmpsi2(-1, 2147483646, 0);
    try test__cmpsi2(-1, 2147483647, 0);
    // 6. cmp 0,        {minInt, minInt + 1, minInt/2, -1,  1, maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(0, -2147483648, 2);
    try test__cmpsi2(0, -2147483647, 2);
    try test__cmpsi2(0, -1073741824, 2);
    try test__cmpsi2(0, -1, 2);
    try test__cmpsi2(0, 1, 0);
    try test__cmpsi2(0, 1073741823, 0);
    try test__cmpsi2(0, 2147483646, 0);
    try test__cmpsi2(0, 2147483647, 0);
    // 7. cmp 1,        {minInt, minInt + 1, minInt/2, -1,0,  maxInt/2, maxInt-1, maxInt}
    try test__cmpsi2(1, -2147483648, 2);
    try test__cmpsi2(1, -2147483647, 2);
    try test__cmpsi2(1, -1073741824, 2);
    try test__cmpsi2(1, -1, 2);
    try test__cmpsi2(1, 0, 2);
    try test__cmpsi2(1, 1073741823, 0);
    try test__cmpsi2(1, 2147483646, 0);
    try test__cmpsi2(1, 2147483647, 0);
    // 8. cmp maxInt/2, {minInt, minInt + 1, minInt/2, -1, 0, 1,          maxInt-1, maxInt}
    try test__cmpsi2(1073741823, -2147483648, 2);
    try test__cmpsi2(1073741823, -2147483647, 2);
    try test__cmpsi2(1073741823, -1073741824, 2);
    try test__cmpsi2(1073741823, -1, 2);
    try test__cmpsi2(1073741823, 0, 2);
    try test__cmpsi2(1073741823, 1, 2);
    try test__cmpsi2(1073741823, 2147483646, 0);
    try test__cmpsi2(1073741823, 2147483647, 0);
    // 9. cmp maxInt-1, {minInt, minInt + 1, minInt/2, -1, 0, 1, maxInt/2,           maxInt}
    try test__cmpsi2(2147483646, -2147483648, 2);
    try test__cmpsi2(2147483646, -2147483647, 2);
    try test__cmpsi2(2147483646, -1073741824, 2);
    try test__cmpsi2(2147483646, -1, 2);
    try test__cmpsi2(2147483646, 0, 2);
    try test__cmpsi2(2147483646, 1, 2);
    try test__cmpsi2(2147483646, 1073741823, 2);
    try test__cmpsi2(2147483646, 2147483647, 0);
    // 10.cmp maxInt,   {minInt, minInt + 1, minInt/2, -1, 0, 1, maxInt/2, maxInt-1,       }
    try test__cmpsi2(2147483647, -2147483648, 2);
    try test__cmpsi2(2147483647, -2147483647, 2);
    try test__cmpsi2(2147483647, -1073741824, 2);
    try test__cmpsi2(2147483647, -1, 2);
    try test__cmpsi2(2147483647, 0, 2);
    try test__cmpsi2(2147483647, 1, 2);
    try test__cmpsi2(2147483647, 1073741823, 2);
    try test__cmpsi2(2147483647, 2147483646, 2);
}
