const builtin = @import("builtin");

const xxx = struct {
    pub fn bar(self: *xxx) void {
        _ = self;
    }
};
test "bug 704" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var x: xxx = undefined;
    x.bar();
}
