const std = @import("../index.zig");
const os = std.os;
const expect = std.testing.expect;
const io = std.io;
const mem = std.mem;

const a = std.debug.global_allocator;

const builtin = @import("builtin");
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;

test "makePath, put some files in it, deleteTree" {
    try os.makePath(a, "os_test_tmp" ++ os.path.sep_str ++ "b" ++ os.path.sep_str ++ "c");
    try io.writeFile("os_test_tmp" ++ os.path.sep_str ++ "b" ++ os.path.sep_str ++ "c" ++ os.path.sep_str ++ "file.txt", "nonsense");
    try io.writeFile("os_test_tmp" ++ os.path.sep_str ++ "b" ++ os.path.sep_str ++ "file2.txt", "blah");
    try os.deleteTree(a, "os_test_tmp");
    if (os.Dir.open(a, "os_test_tmp")) |dir| {
        @panic("expected error");
    } else |err| {
        expect(err == error.FileNotFound);
    }
}

test "access file" {
    try os.makePath(a, "os_test_tmp");
    if (os.File.access("os_test_tmp" ++ os.path.sep_str ++ "file.txt")) |ok| {
        @panic("expected error");
    } else |err| {
        expect(err == error.FileNotFound);
    }

    try io.writeFile("os_test_tmp" ++ os.path.sep_str ++ "file.txt", "");
    try os.File.access("os_test_tmp" ++ os.path.sep_str ++ "file.txt");
    try os.deleteTree(a, "os_test_tmp");
}

fn testThreadIdFn(thread_id: *os.Thread.Id) void {
    thread_id.* = os.Thread.getCurrentId();
}

test "std.os.Thread.getCurrentId" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var thread_current_id: os.Thread.Id = undefined;
    const thread = try os.spawnThread(&thread_current_id, testThreadIdFn);
    const thread_id = thread.handle();
    thread.wait();
    switch (builtin.os) {
        builtin.Os.windows => expect(os.Thread.getCurrentId() != thread_current_id),
        else => {
            expect(thread_current_id == thread_id);
        },
    }
}

test "spawn threads" {
    if (builtin.single_threaded) return error.SkipZigTest;

    var shared_ctx: i32 = 1;

    const thread1 = try std.os.spawnThread({}, start1);
    const thread2 = try std.os.spawnThread(&shared_ctx, start2);
    const thread3 = try std.os.spawnThread(&shared_ctx, start2);
    const thread4 = try std.os.spawnThread(&shared_ctx, start2);

    thread1.wait();
    thread2.wait();
    thread3.wait();
    thread4.wait();

    expect(shared_ctx == 4);
}

fn start1(ctx: void) u8 {
    return 0;
}

fn start2(ctx: *i32) u8 {
    _ = @atomicRmw(i32, ctx, AtomicRmwOp.Add, 1, AtomicOrder.SeqCst);
    return 0;
}

test "cpu count" {
    const cpu_count = try std.os.cpuCount(a);
    expect(cpu_count >= 1);
}

test "AtomicFile" {
    var buffer: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(buffer[0..]).allocator;
    const test_out_file = "tmp_atomic_file_test_dest.txt";
    const test_content =
        \\ hello!
        \\ this is a test file
    ;
    {
        var af = try os.AtomicFile.init(test_out_file, os.File.default_mode);
        defer af.deinit();
        try af.file.write(test_content);
        try af.finish();
    }
    const content = try io.readFileAlloc(allocator, test_out_file);
    expect(mem.eql(u8, content, test_content));

    try os.deleteFile(test_out_file);
}

test "thread local storage" {
    if (builtin.single_threaded) return error.SkipZigTest;
    const thread1 = try std.os.spawnThread({}, testTls);
    const thread2 = try std.os.spawnThread({}, testTls);
    testTls({});
    thread1.wait();
    thread2.wait();
}

threadlocal var x: i32 = 1234;
fn testTls(context: void) void {
    if (x != 1234) @panic("bad start value");
    x += 1;
    if (x != 1235) @panic("bad end value");
}
