const cmp = @import("cmp.zig");
const testing = @import("std").testing;

fn test__cmpdi2(a: i64, b: i64, expected: i64) !void {
    const result = cmp.__cmpdi2(a, b);
    try testing.expectEqual(expected, result);
}

test "cmpdi2" {
    // minInt == -9223372036854775808
    // maxInt == 9223372036854775807
    // minInt/2 == -4611686018427387904
    // maxInt/2 == 4611686018427387903
    // 1. equality minInt, minInt+1, minInt/2, 0, maxInt/2, maxInt-1, maxInt
    try test__cmpdi2(-9223372036854775808, -9223372036854775808, 1);
    try test__cmpdi2(-9223372036854775807, -9223372036854775807, 1);
    try test__cmpdi2(-4611686018427387904, -4611686018427387904, 1);
    try test__cmpdi2(-1, -1, 1);
    try test__cmpdi2(0, 0, 1);
    try test__cmpdi2(1, 1, 1);
    try test__cmpdi2(4611686018427387903, 4611686018427387903, 1);
    try test__cmpdi2(9223372036854775806, 9223372036854775806, 1);
    try test__cmpdi2(9223372036854775807, 9223372036854775807, 1);
    // 2. cmp minInt,   {        minInt + 1, minInt/2, -1, 0, 1, maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(-9223372036854775808, -9223372036854775807, 0);
    try test__cmpdi2(-9223372036854775808, -4611686018427387904, 0);
    try test__cmpdi2(-9223372036854775808, -1, 0);
    try test__cmpdi2(-9223372036854775808, 0, 0);
    try test__cmpdi2(-9223372036854775808, 1, 0);
    try test__cmpdi2(-9223372036854775808, 4611686018427387903, 0);
    try test__cmpdi2(-9223372036854775808, 9223372036854775806, 0);
    try test__cmpdi2(-9223372036854775808, 9223372036854775807, 0);
    // 3. cmp minInt+1, {minInt,             minInt/2, -1,0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(-9223372036854775807, -9223372036854775808, 2);
    try test__cmpdi2(-9223372036854775807, -4611686018427387904, 0);
    try test__cmpdi2(-9223372036854775807, -1, 0);
    try test__cmpdi2(-9223372036854775807, 0, 0);
    try test__cmpdi2(-9223372036854775807, 1, 0);
    try test__cmpdi2(-9223372036854775807, 4611686018427387903, 0);
    try test__cmpdi2(-9223372036854775807, 9223372036854775806, 0);
    try test__cmpdi2(-9223372036854775807, 9223372036854775807, 0);
    // 4. cmp minInt/2, {minInt, minInt + 1,           -1,0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(-4611686018427387904, -9223372036854775808, 2);
    try test__cmpdi2(-4611686018427387904, -9223372036854775807, 2);
    try test__cmpdi2(-4611686018427387904, -1, 0);
    try test__cmpdi2(-4611686018427387904, 0, 0);
    try test__cmpdi2(-4611686018427387904, 1, 0);
    try test__cmpdi2(-4611686018427387904, 4611686018427387903, 0);
    try test__cmpdi2(-4611686018427387904, 9223372036854775806, 0);
    try test__cmpdi2(-4611686018427387904, 9223372036854775807, 0);
    // 5. cmp -1,       {minInt, minInt + 1, minInt/2,    0,1, maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(-1, -9223372036854775808, 2);
    try test__cmpdi2(-1, -9223372036854775807, 2);
    try test__cmpdi2(-1, -4611686018427387904, 2);
    try test__cmpdi2(-1, 0, 0);
    try test__cmpdi2(-1, 1, 0);
    try test__cmpdi2(-1, 4611686018427387903, 0);
    try test__cmpdi2(-1, 9223372036854775806, 0);
    try test__cmpdi2(-1, 9223372036854775807, 0);
    // 6. cmp 0,        {minInt, minInt + 1, minInt/2, -1,  1, maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(0, -9223372036854775808, 2);
    try test__cmpdi2(0, -9223372036854775807, 2);
    try test__cmpdi2(0, -4611686018427387904, 2);
    try test__cmpdi2(0, -1, 2);
    try test__cmpdi2(0, 1, 0);
    try test__cmpdi2(0, 4611686018427387903, 0);
    try test__cmpdi2(0, 9223372036854775806, 0);
    try test__cmpdi2(0, 9223372036854775807, 0);
    // 7. cmp 1,        {minInt, minInt + 1, minInt/2, -1,0,  maxInt/2, maxInt-1, maxInt}
    try test__cmpdi2(1, -9223372036854775808, 2);
    try test__cmpdi2(1, -9223372036854775807, 2);
    try test__cmpdi2(1, -4611686018427387904, 2);
    try test__cmpdi2(1, -1, 2);
    try test__cmpdi2(1, 0, 2);
    try test__cmpdi2(1, 4611686018427387903, 0);
    try test__cmpdi2(1, 9223372036854775806, 0);
    try test__cmpdi2(1, 9223372036854775807, 0);
    // 8. cmp maxInt/2, {minInt, minInt + 1, minInt/2, -1,0,1,           maxInt-1, maxInt}
    try test__cmpdi2(4611686018427387903, -9223372036854775808, 2);
    try test__cmpdi2(4611686018427387903, -9223372036854775807, 2);
    try test__cmpdi2(4611686018427387903, -4611686018427387904, 2);
    try test__cmpdi2(4611686018427387903, -1, 2);
    try test__cmpdi2(4611686018427387903, 0, 2);
    try test__cmpdi2(4611686018427387903, 1, 2);
    try test__cmpdi2(4611686018427387903, 9223372036854775806, 0);
    try test__cmpdi2(4611686018427387903, 9223372036854775807, 0);
    // 9. cmp maxInt-1, {minInt, minInt + 1, minInt/2, -1,0,1, maxInt/2,           maxInt}
    try test__cmpdi2(9223372036854775806, -9223372036854775808, 2);
    try test__cmpdi2(9223372036854775806, -9223372036854775807, 2);
    try test__cmpdi2(9223372036854775806, -4611686018427387904, 2);
    try test__cmpdi2(9223372036854775806, -1, 2);
    try test__cmpdi2(9223372036854775806, 0, 2);
    try test__cmpdi2(9223372036854775806, 1, 2);
    try test__cmpdi2(9223372036854775806, 4611686018427387903, 2);
    try test__cmpdi2(9223372036854775806, 9223372036854775807, 0);
    // 10.cmp maxInt,   {minInt, minInt + 1, minInt/2, -1,0,1, maxInt/2, maxInt-1,       }
    try test__cmpdi2(9223372036854775807, -9223372036854775808, 2);
    try test__cmpdi2(9223372036854775807, -9223372036854775807, 2);
    try test__cmpdi2(9223372036854775807, -4611686018427387904, 2);
    try test__cmpdi2(9223372036854775807, -1, 2);
    try test__cmpdi2(9223372036854775807, 0, 2);
    try test__cmpdi2(9223372036854775807, 1, 2);
    try test__cmpdi2(9223372036854775807, 4611686018427387903, 2);
    try test__cmpdi2(9223372036854775807, 9223372036854775806, 2);
}
