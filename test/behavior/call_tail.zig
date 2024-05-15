const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

var base: usize = undefined;
var result_off: [7]usize = undefined;
var result_len: [7]usize = undefined;
var result_index: usize = 0;

noinline fn insertionSort(data: []u64) void {
    result_off[result_index] = @intFromPtr(data.ptr) - base;
    result_len[result_index] = data.len;
    result_index += 1;
    if (data.len > 1) {
        var least_i: usize = 0;
        var i: usize = 1;
        while (i < data.len) : (i += 1) {
            if (data[i] < data[least_i])
                least_i = i;
        }
        std.mem.swap(u64, &data[0], &data[least_i]);

        // there used to be a bug where
        // `data[1..]` is created on the stack
        // and pointed to by the first argument register
        // then stack is invalidated by the tailcall and
        // overwritten by callee
        // https://github.com/ziglang/zig/issues/9703
        return @call(.always_tail, insertionSort, .{data[1..]});
    }
}

test "arguments pointed to on stack into tailcall" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    switch (builtin.cpu.arch) {
        .wasm32,
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        .powerpc,
        .powerpcle,
        .powerpc64,
        .powerpc64le,
        => return error.SkipZigTest,
        else => {},
    }
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_c and builtin.os.tag == .windows) return error.SkipZigTest; // MSVC doesn't support always tail calls

    var data = [_]u64{ 1, 6, 2, 7, 1, 9, 3 };
    base = @intFromPtr(&data);
    insertionSort(data[0..]);
    try expect(result_len[0] == 7);
    try expect(result_len[1] == 6);
    try expect(result_len[2] == 5);
    try expect(result_len[3] == 4);
    try expect(result_len[4] == 3);
    try expect(result_len[5] == 2);
    try expect(result_len[6] == 1);

    try expect(result_off[0] == 0);
    try expect(result_off[1] == 8);
    try expect(result_off[2] == 16);
    try expect(result_off[3] == 24);
    try expect(result_off[4] == 32);
    try expect(result_off[5] == 40);
    try expect(result_off[6] == 48);
}
