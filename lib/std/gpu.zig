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
pub inline fn location(comptime ptr: anytype, comptime loc: u32) void {
    asm volatile (
        \\OpDecorate %ptr Location $loc
        :
        : [ptr] "" (ptr),
          [loc] "c" (loc),
    );
}

/// Forms the main linkage for `input` and `output` address spaces.
/// `ptr` must be a reference to variable or struct field.
pub inline fn binding(comptime ptr: anytype, comptime set: u32, comptime bind: u32) void {
    asm volatile (
        \\OpDecorate %ptr DescriptorSet $set
        \\OpDecorate %ptr Binding $bind
        :
        : [ptr] "" (ptr),
          [set] "c" (set),
          [bind] "c" (bind),
    );
}
