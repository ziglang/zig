const std = @import("std");

test "lazy sizeof comparison with zero" {
    const Empty = struct {};
    const T = *Empty;

    try std.testing.expect(hasNoBits(T));
}

fn hasNoBits(comptime T: type) bool {
    if (@import("builtin").zig_backend != .stage1) {
        // It is an accepted proposal to make `@sizeOf` for pointers independent
        // of whether the element type is zero bits.
        // This language change has not been implemented in stage1.
        return @sizeOf(T) == @sizeOf(*i32);
    }
    return @sizeOf(T) == 0;
}
