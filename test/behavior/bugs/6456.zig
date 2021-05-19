const std = @import("std");
const testing = std.testing;
const StructField = std.builtin.TypeInfo.StructField;
const Declaration = std.builtin.TypeInfo.Declaration;

const text =
    \\f1
    \\f2
    \\f3
;

test "issue 6456" {
    comptime {
        var fields: []const StructField = &[0]StructField{};

        var it = std.mem.tokenize(text, "\n");
        while (it.next()) |name| {
            fields = fields ++ &[_]StructField{StructField{
                .alignment = 0,
                .name = name,
                .field_type = usize,
                .default_value = @as(?usize, null),
                .is_comptime = false,
            }};
        }

        const T = @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &[_]Declaration{},
            },
        });

        const gen_fields = @typeInfo(T).Struct.fields;
        try testing.expectEqual(3, gen_fields.len);
        try testing.expectEqualStrings("f1", gen_fields[0].name);
        try testing.expectEqualStrings("f2", gen_fields[1].name);
        try testing.expectEqualStrings("f3", gen_fields[2].name);
    }
}
