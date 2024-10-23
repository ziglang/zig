const std = @import("std");

// big enums should not hit the eval branch quota
pub fn main() void {
    const big = struct {
        const Big = @Type(.{ .@"enum" = .{
            .tag_type = u16,
            .fields = make_fields: {
                var fields: [1001]std.builtin.Type.EnumField = undefined;
                for (&fields, 0..) |*field, i| {
                    field.* = .{ .name = std.fmt.comptimePrint("field_{d}", .{i}), .value = i };
                }
                fields[1000] = .{ .name = "field_9999", .value = 9999 };
                break :make_fields &fields;
            },
            .decls = &.{},
            .is_exhaustive = true,
        } });
    };

    var set = std.enums.EnumSet(big.Big).init(.{});
    _ = &set;

    var map = std.enums.EnumMap(big.Big, u8).init(undefined);
    map = std.enums.EnumMap(big.Big, u8).initFullWith(undefined);
    map = std.enums.EnumMap(big.Big, u8).initFullWithDefault(123, .{});

    var multiset = std.enums.EnumMultiset(big.Big).init(.{});
    _ = &multiset;

    var bounded_multiset = std.enums.BoundedEnumMultiset(big.Big, u8).init(.{});
    _ = &bounded_multiset;

    var array = std.enums.EnumArray(big.Big, u8).init(undefined);
    array = std.enums.EnumArray(big.Big, u8).initDefault(123, .{});
}
