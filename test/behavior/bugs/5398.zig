const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

pub const Mesh = struct {
    id: u32,
};
pub const Material = struct {
    transparent: bool = true,
    emits_shadows: bool = true,
    render_color: bool = true,
};
pub const Renderable = struct {
    material: Material,
    // The compiler inserts some padding here to ensure Mesh is correctly aligned.
    mesh: Mesh,
};

var renderable: Renderable = undefined;

test "assignment of field with padding" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    renderable = Renderable{
        .mesh = Mesh{ .id = 0 },
        .material = Material{
            .transparent = false,
            .emits_shadows = false,
        },
    };
    try testing.expectEqual(false, renderable.material.transparent);
    try testing.expectEqual(false, renderable.material.emits_shadows);
    try testing.expectEqual(true, renderable.material.render_color);
}
