const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
const StructField = std.builtin.Type.StructField;
const Declaration = std.builtin.Type.Declaration;

const text =
    \\f1
    \\f2
    \\f3
;

test "issue 6456" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    comptime {
        var fields: []const StructField = &[0]StructField{};

        var it = std.mem.tokenize(u8, text, "\n");
        while (it.next()) |name| {
            fields = fields ++ &[_]StructField{StructField{
                .alignment = 0,
                .name = name,
                .type = usize,
                .default_value = &@as(?usize, null),
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
