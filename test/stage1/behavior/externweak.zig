const builtin = @import("builtin");
const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

test "externWeak" {
    if (builtin.os != .linux) return error.SkipZigTest;

    const p1 = @externWeak("__ehdr_start", *u8);
    expectEqual(?*u8, @TypeOf(p1));

    const p2 = @externWeak("__ehdr_start", *u8);
    expect(p1 == p2);

    // Different kind of optional layout
    const p3 = @externWeak("__ehdr_start", *allowzero u8);
    expect((p1 == null and p3 == null) or (p1.? == p3.?));

    // Destination result_loc is null
    _ = @externWeak("__ehdr_start", *u8);
    _ = @externWeak("__ehdr_start", *allowzero u8);
}
