const std = @import("std");
const abi = std.Build.abi.fuzz;
const native_endian = @import("builtin").cpu.arch.endian();

fn testOne(in: abi.Slice) callconv(.c) void {
    std.debug.assertReadable(in.toSlice());
}

pub fn main() !void {
    var debug_gpa_ctx: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_gpa_ctx.deinit();
    const gpa = debug_gpa_ctx.allocator();

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();
    _ = args.skip(); // executable name

    const cache_dir_path = args.next() orelse @panic("expected cache directory path argument");
    var cache_dir = try std.fs.cwd().openDir(cache_dir_path, .{});
    defer cache_dir.close();

    abi.fuzzer_init(.fromSlice(cache_dir_path));
    abi.fuzzer_init_test(testOne, .fromSlice("test"));
    abi.fuzzer_new_input(.fromSlice(""));
    abi.fuzzer_new_input(.fromSlice("hello"));

    const pc_digest = abi.fuzzer_coverage_id();
    const coverage_file_path = "v/" ++ std.fmt.hex(pc_digest);
    const coverage_file = try cache_dir.openFile(coverage_file_path, .{});
    defer coverage_file.close();

    var read_buf: [@sizeOf(abi.SeenPcsHeader)]u8 = undefined;
    var r = coverage_file.reader(&read_buf);
    const pcs_header = r.interface.takeStruct(abi.SeenPcsHeader, native_endian) catch return r.err.?;

    if (pcs_header.pcs_len == 0)
        return error.ZeroPcs;
    const expected_len = @sizeOf(abi.SeenPcsHeader) +
        try std.math.divCeil(usize, pcs_header.pcs_len, @bitSizeOf(usize)) * @sizeOf(usize) +
        pcs_header.pcs_len * @sizeOf(usize);
    if (try coverage_file.getEndPos() != expected_len)
        return error.WrongEnd;
}
