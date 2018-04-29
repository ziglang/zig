const std = @import("../index.zig");
const os = std.os;
const assert = std.debug.assert;
const io = std.io;

const a = std.debug.global_allocator;

const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

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

test "access file" {
    if (builtin.os == builtin.Os.windows) {
        return;
    }

    try os.makePath(a, "os_test_tmp");
    if (os.File.access(a, "os_test_tmp/file.txt", os.default_file_mode)) |ok| {
        unreachable;
    } else |err| {
        assert(err == error.NotFound);
    }

    try io.writeFile(a, "os_test_tmp/file.txt", "");
    assert((try os.File.access(a, "os_test_tmp/file.txt", os.default_file_mode)) == true);
    try os.deleteTree(a, "os_test_tmp");
}

test "spawn threads" {
    if (builtin.os == builtin.Os.windows) {
        // TODO implement threads on windows
        return;
    }

    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var shared_ctx: i32 = 1;

    const thread1 = try std.os.spawnThreadAllocator(&direct_allocator.allocator, {}, start1);
    const thread4 = try std.os.spawnThreadAllocator(&direct_allocator.allocator, &shared_ctx, start2);

    var stack1: [20 * 1024]u8 = undefined;
    var stack2: [20 * 1024]u8 = undefined;

    const thread2 = try std.os.spawnThread(stack1[0..], &shared_ctx, start2);
    const thread3 = try std.os.spawnThread(stack2[0..], &shared_ctx, start2);

    thread1.wait();
    thread2.wait();
    thread3.wait();
    thread4.wait();

    assert(shared_ctx == 4);
}

fn start1(ctx: void) u8 {
    return 0;
}

fn start2(ctx: &i32) u8 {
    _ = @atomicRmw(i32, ctx, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
    return 0;
}
