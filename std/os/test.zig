const std = @import("../index.zig");
const os = std.os;
const assert = std.debug.assert;
const io = std.io;

const a = std.debug.global_allocator;

const builtin = @import("builtin");

test "makePath, put some files in it, deleteTree" {
    if (builtin.os == builtin.Os.windows) {
        // TODO implement os.Dir for windows
        // https://github.com/zig-lang/zig/issues/709
        return;
    }
    try os.makePath(a, "os_test_tmp/b/c");
    try io.writeFile(a, "os_test_tmp/b/c/file.txt", "nonsense");
    try io.writeFile(a, "os_test_tmp/b/file2.txt", "blah");
    try os.deleteTree(a, "os_test_tmp");
    if (os.Dir.open(a, "os_test_tmp")) |dir| {
        @panic("expected error");
    } else |err| {
        assert(err == error.PathNotFound);
    }
}
