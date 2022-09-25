const builtin = @import("builtin");

const Item = struct { field: u8 };
const Thing = struct {
    array: [1]Item,
};
test {
    if (builtin.zig_backend == .stage1) return error.SkipZigTest;

    _ = Thing{ .array = undefined };
}
