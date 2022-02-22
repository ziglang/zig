const builtin = @import("builtin");

const NoteParams = struct {};

const Container = struct {
    params: ?NoteParams,
};

test "fixed" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    var ctr = Container{
        .params = NoteParams{},
    };
    _ = ctr;
}
