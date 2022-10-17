const std = @import("std");
const builtin = @import("builtin");

test "linksection" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO

    const prefix = switch (builtin.object_format) {
        .elf => ".",
        .macho => "__TEXT,__",
        else => return error.SkipZigTest,
    };
    const suffix = "ZigTest";

    const S = struct {
        var global_in_section: *const fn () void linksection(prefix ++ "Global" ++ suffix) = undefined;
        fn function_in_section() linksection(prefix ++ "Fn" ++ suffix) void {}
        fn generic_function_in_section(comptime name: []const u8) linksection(prefix ++ "GenFn" ++ name ++ suffix) void {}
    };

    S.global_in_section = &S.function_in_section;
    S.generic_function_in_section("A");
    S.generic_function_in_section("B");

    const allocator = std.heap.page_allocator;

    const exe_file = try std.fs.openSelfExe(.{});
    defer exe_file.close();

    const exe_contents = try exe_file.reader().readAllAlloc(allocator, 10 << 20);
    defer allocator.free(exe_contents);

    for (&[_][]const u8{ "Global", "Fn", "GenFnA", "GenFnB" }) |kind| {
        // This format helps ensure we don't have another match in rodata.
        const name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ kind, suffix });
        defer allocator.free(name);

        // Prefix is checked separately to be completely sure.
        const index = std.mem.indexOfPos(u8, exe_contents, 1, name);
        try std.testing.expect(index != null);
        try std.testing.expectEqual(prefix[prefix.len - 1], exe_contents[index.? - 1]);
    }
}
