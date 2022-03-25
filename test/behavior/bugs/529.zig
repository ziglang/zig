const A = extern struct {
    field: c_int,
};

extern fn issue529(?*A) void;

comptime {
    _ = @import("529_other_file_2.zig");
}

test "issue 529 fixed" {
    if (@import("builtin").zig_backend != .stage1) return error.SkipZigTest; // TODO

    @import("529_other_file.zig").issue529(null);
    issue529(null);
}
