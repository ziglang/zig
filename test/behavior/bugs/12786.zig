const std = @import("std");

fn NamespacedGlobals(comptime modules: anytype) type {
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = &.{
                .{
                    .name = "globals",
                    .type = modules.mach.globals,
                    .default_value = null,
                    .is_comptime = false,
                    .alignment = @alignOf(modules.mach.globals),
                },
            },
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

test {
    _ = NamespacedGlobals(.{
        .mach = .{
            .globals = struct {},
        },
    });
}
