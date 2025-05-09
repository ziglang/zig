const std = @import("std.zig");

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
