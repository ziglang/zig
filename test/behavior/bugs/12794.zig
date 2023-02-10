const std = @import("std");

fn NamespacedComponents(comptime modules: anytype) type {
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .is_tuple = false,
            .fields = &.{.{
                .name = "components",
                .type = @TypeOf(modules.components),
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(@TypeOf(modules.components)),
            }},
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

fn namespacedComponents(comptime modules: anytype) NamespacedComponents(modules) {
    var x: NamespacedComponents(modules) = undefined;
    x.components = modules.components;
    return x;
}

pub fn World(comptime modules: anytype) type {
    const all_components = namespacedComponents(modules);
    _ = all_components;
    return struct {};
}

test {
    _ = World(.{
        .components = .{
            .location = struct {},
        },
    });
}
