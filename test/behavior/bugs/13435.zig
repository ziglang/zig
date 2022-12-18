const std = @import("std");

fn CreateUnion(comptime T: type) type {
    return @Type(.{
        .Union = .{
            .layout = .Auto,
            .tag_type = null,
            .fields = &[_]std.builtin.Type.UnionField{
                .{
                    .name = "field",
                    .type = T,
                    .alignment = @alignOf(T),
                },
            },
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

test {
    _ = CreateUnion(struct {});
}
