const std = @import("std");

test "lazy sizeof comparison with zero" {
    const Empty = struct {};
    const T = *Empty;

    std.testing.expect(hasNoBits(T));
}

fn hasNoBits(comptime T: type) bool {
    return @sizeOf(T) == 0;
}
