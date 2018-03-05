const std = @import("../index.zig");
const os = std.os;
const io = std.io;

const a = std.debug.global_allocator;

test "makePath, put some files in it, deleteTree" {
    try os.makePath(a, "os_test_tmp/b/c");
    try io.writeFile(a, "os_test_tmp/b/c/file.txt", "nonsense");
    try io.writeFile(a, "os_test_tmp/b/file2.txt", "blah");
    try os.deleteTree(a, "os_test_tmp");
}
