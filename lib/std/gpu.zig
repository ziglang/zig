const std = @import("std.zig");

pub const position_in = @extern(*addrspace(.input) @Vector(4, f32), .{ .name = "position" });
pub const position_out = @extern(*addrspace(.output) @Vector(4, f32), .{ .name = "position" });
pub const point_size_in = @extern(*addrspace(.input) f32, .{ .name = "point_size" });
pub const point_size_out = @extern(*addrspace(.output) f32, .{ .name = "point_size" });
pub extern const invocation_id: u32 addrspace(.input);
pub extern const frag_coord: @Vector(4, f32) addrspace(.input);
pub extern const point_coord: @Vector(2, f32) addrspace(.input);
// TODO: direct/indirect values
// pub extern const front_facing: bool addrspace(.input);
// TODO: runtime array
// pub extern const sample_mask;
pub extern var frag_depth: f32 addrspace(.output);
pub extern const num_workgroups: @Vector(3, u32) addrspace(.input);
pub extern const workgroup_size: @Vector(3, u32) addrspace(.input);
pub extern const workgroup_id: @Vector(3, u32) addrspace(.input);
pub extern const local_invocation_id: @Vector(3, u32) addrspace(.input);
pub extern const global_invocation_id: @Vector(3, u32) addrspace(.input);
pub extern const vertex_index: u32 addrspace(.input);
pub extern const instance_index: u32 addrspace(.input);

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn location(comptime ptr: anytype, comptime loc: u32) void {
    asm volatile (
        \\OpDecorate %ptr Location $loc
        :
        : [ptr] "" (ptr),
          [loc] "c" (loc),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub fn binding(comptime ptr: anytype, comptime set: u32, comptime bind: u32) void {
    asm volatile (
        \\OpDecorate %ptr DescriptorSet $set
        \\OpDecorate %ptr Binding $bind
        :
        : [ptr] "" (ptr),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}

pub const ExecutionMode = union(Tag) {
    /// Sets origin of the framebuffer to the upper-left corner
    origin_upper_left,
    /// Sets origin of the framebuffer to the lower-left corner
    origin_lower_left,
    /// Indicates that the fragment shader writes to `frag_depth`,
    /// replacing the fixed-function depth value.
    depth_replacing,
    /// Indicates that per-fragment tests may assume that
    /// any `frag_depth` built in-decorated value written by the shader is
    /// greater-than-or-equal to the fragment’s interpolated depth value
    depth_greater,
    /// Indicates that per-fragment tests may assume that
    /// any `frag_depth` built in-decorated value written by the shader is
    /// less-than-or-equal to the fragment’s interpolated depth value
    depth_less,
    /// Indicates that per-fragment tests may assume that
    /// any `frag_depth` built in-decorated value written by the shader is
    /// the same as the fragment’s interpolated depth value
    depth_unchanged,
    /// Indicates the workgroup size in the x, y, and z dimensions.
    local_size: LocalSize,

    pub const Tag = enum(u32) {
        origin_upper_left = 7,
        origin_lower_left = 8,
        depth_replacing = 12,
        depth_greater = 14,
        depth_less = 15,
        depth_unchanged = 16,
        local_size = 17,
    };

    pub const LocalSize = struct { x: u32, y: u32, z: u32 };
};

/// Declare the mode entry point executes in.
pub fn executionMode(comptime entry_point: anytype, comptime mode: ExecutionMode) void {
    const cc = @typeInfo(@TypeOf(entry_point)).@"fn".calling_convention;
    switch (mode) {
        .origin_upper_left,
        .origin_lower_left,
        .depth_replacing,
        .depth_greater,
        .depth_less,
        .depth_unchanged,
        => {
            if (cc != .spirv_fragment) {
                @compileError(
                    \\invalid execution mode '
                ++ @tagName(mode) ++
                    \\' for function with '
                ++ @tagName(cc) ++
                    \\' calling convention
                );
            }
            asm volatile (
                \\OpExecutionMode %entry_point $mode
                :
                : [entry_point] "" (entry_point),
                  [mode] "c" (@intFromEnum(mode)),
            );
        },
        .local_size => |size| {
            if (cc != .spirv_kernel) {
                @compileError(
                    \\invalid execution mode 'local_size' for function with '
                ++ @tagName(cc) ++
                    \\' calling convention
                );
            }
            asm volatile (
                \\OpExecutionMode %entry_point LocalSize $x $y $z
                :
                : [entry_point] "" (entry_point),
                  [x] "c" (size.x),
                  [y] "c" (size.y),
                  [z] "c" (size.z),
            );
        },
    }
}
