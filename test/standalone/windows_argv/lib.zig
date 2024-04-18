const std = @import("std");

/// Returns 1 on success, 0 on failure
export fn verify(argc: c_int, argv: [*]const [*:0]const u16) c_int {
    const argv_slice = argv[0..@intCast(argc)];
    testArgv(argv_slice) catch |err| switch (err) {
        error.OutOfMemory => @panic("oom"),
        error.Overflow => @panic("bytes needed to contain args would overflow usize"),
        error.ArgvMismatch => return 0,
    };
    return 1;
}

fn testArgv(expected_args: []const [*:0]const u16) !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const allocator = arena_state.allocator();

    const args = try std.process.argsAlloc(allocator);
    var wtf8_buf = std.ArrayList(u8).init(allocator);

    var eql = true;
    if (args.len != expected_args.len) eql = false;

    const min_len = @min(expected_args.len, args.len);
    for (expected_args[0..min_len], args[0..min_len], 0..) |expected_arg, arg_wtf8, i| {
        wtf8_buf.clearRetainingCapacity();
        try std.unicode.wtf16LeToWtf8ArrayList(&wtf8_buf, std.mem.span(expected_arg));
        if (!std.mem.eql(u8, wtf8_buf.items, arg_wtf8)) {
            std.debug.print("{}: expected: \"{}\"\n", .{ i, std.zig.fmtEscapes(wtf8_buf.items) });
            std.debug.print("{}:   actual: \"{}\"\n", .{ i, std.zig.fmtEscapes(arg_wtf8) });
            eql = false;
        }
    }
    if (!eql) {
        for (expected_args[min_len..], min_len..) |arg, i| {
            wtf8_buf.clearRetainingCapacity();
            try std.unicode.wtf16LeToWtf8ArrayList(&wtf8_buf, std.mem.span(arg));
            std.debug.print("{}: expected: \"{}\"\n", .{ i, std.zig.fmtEscapes(wtf8_buf.items) });
        }
        for (args[min_len..], min_len..) |arg, i| {
            std.debug.print("{}:   actual: \"{}\"\n", .{ i, std.zig.fmtEscapes(arg) });
        }
        const peb = std.os.windows.peb();
        const lpCmdLine: [*:0]u16 = @ptrCast(peb.ProcessParameters.CommandLine.Buffer);
        wtf8_buf.clearRetainingCapacity();
        try std.unicode.wtf16LeToWtf8ArrayList(&wtf8_buf, std.mem.span(lpCmdLine));
        std.debug.print("command line: \"{}\"\n", .{std.zig.fmtEscapes(wtf8_buf.items)});
        std.debug.print("expected argv:\n", .{});
        std.debug.print("&.{{\n", .{});
        for (expected_args) |arg| {
            wtf8_buf.clearRetainingCapacity();
            try std.unicode.wtf16LeToWtf8ArrayList(&wtf8_buf, std.mem.span(arg));
            std.debug.print("    \"{}\",\n", .{std.zig.fmtEscapes(wtf8_buf.items)});
        }
        std.debug.print("}}\n", .{});
        return error.ArgvMismatch;
    }
}
