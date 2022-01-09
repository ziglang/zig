const std = @import("std");
const math = std.math;
const mem = std.mem;

// Copies elements from a source `src` slice into a destination `dst` slice.
// The copy never returns an error but might not be complete if the destination is too small.
// Returns the number of elements copied, which will be the minimum of `src.len` and `dst.len`.
pub fn copy(dst: []u8, src: []const u8) usize {
    if (dst.len <= src.len) {
        mem.copy(u8, dst[0..], src[0..dst.len]);
    } else {
        mem.copy(u8, dst[0..src.len], src[0..]);
    }
    return math.min(dst.len, src.len);
}
