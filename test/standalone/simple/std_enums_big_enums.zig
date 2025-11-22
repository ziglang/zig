const std = @import("std");

// big enums should not hit the eval branch quota
pub fn main() void {
    const big = struct {
        const Big = Big: {
            @setEvalBranchQuota(500000);
            var names: [1001][]const u8 = undefined;
            var values: [1001]u16 = undefined;
            for (values[0..1000], names[0..1000], 0..1000) |*val, *name, i| {
                name.* = std.fmt.comptimePrint("field_{d}", .{i});
                val.* = i;
            }
            names[1000] = "field_9999";
            values[1000] = 9999;
            break :Big @Enum(u16, .exhaustive, &names, &values);
        };
    };

    var set = std.enums.EnumSet(big.Big).init(.{});
    _ = &set;

    var map = std.enums.EnumMap(big.Big, u8).init(undefined);
    map = std.enums.EnumMap(big.Big, u8).initFullWith(undefined);
    map = std.enums.EnumMap(big.Big, u8).initFullWithDefault(123, .{});

    var multiset = std.enums.EnumMultiset(big.Big).init(.{});
    _ = &multiset;

    @setEvalBranchQuota(4000);

    var bounded_multiset = std.enums.BoundedEnumMultiset(big.Big, u8).init(.{});
    _ = &bounded_multiset;

    var array = std.enums.EnumArray(big.Big, u8).init(undefined);
    array = std.enums.EnumArray(big.Big, u8).initDefault(123, .{});
}
