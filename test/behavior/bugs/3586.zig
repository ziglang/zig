const builtin = @import("builtin");

const NoteParams = struct {};

const Container = struct {
    params: ?NoteParams,
};

test "fixed" {
    if (builtin.zig_backend == .zsf_sparc64) return error.SkipZigTest; // TODO

    var ctr = Container{
        .params = NoteParams{},
    };
    _ = ctr;
}
