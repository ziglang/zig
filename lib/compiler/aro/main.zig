const std = @import("std");
const Allocator = mem.Allocator;
const mem = std.mem;
const process = std.process;
const aro = @import("aro");
const Compilation = aro.Compilation;
const Diagnostics = aro.Diagnostics;
const Driver = aro.Driver;
const Toolchain = aro.Toolchain;
const assembly_backend = @import("assembly_backend");

var debug_allocator: std.heap.DebugAllocator(.{
    .stack_trace_frames = 0,
    // A unique value so that when a default-constructed
    // GeneralPurposeAllocator is incorrectly passed to testing allocator, or
    // vice versa, panic occurs.
    .canary = @truncate(0xc647026dc6875134),
}) = .{};

pub fn main() u8 {
    const gpa = if (@import("builtin").link_libc)
        std.heap.raw_c_allocator
    else
        debug_allocator.allocator();
    defer if (!@import("builtin").link_libc) {
        _ = debug_allocator.deinit();
    };

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var threaded: std.Io.Threaded = .init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    const fast_exit = @import("builtin").mode != .Debug;

    const args = process.argsAlloc(arena) catch {
        std.debug.print("out of memory\n", .{});
        if (fast_exit) process.exit(1);
        return 1;
    };

    const aro_name = std.fs.selfExePathAlloc(gpa) catch {
        std.debug.print("unable to find Aro executable path\n", .{});
        if (fast_exit) process.exit(1);
        return 1;
    };
    defer gpa.free(aro_name);

    var stderr_buf: [1024]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&stderr_buf);
    var diagnostics: Diagnostics = .{
        .output = .{ .to_writer = .{
            .color = .detect(stderr.file),
            .writer = &stderr.interface,
        } },
    };

    var comp = Compilation.initDefault(gpa, arena, io, &diagnostics, std.fs.cwd()) catch |er| switch (er) {
        error.OutOfMemory => {
            std.debug.print("out of memory\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    defer comp.deinit();

    var driver: Driver = .{ .comp = &comp, .aro_name = aro_name, .diagnostics = &diagnostics };
    defer driver.deinit();

    var toolchain: Toolchain = .{ .driver = &driver };
    defer toolchain.deinit();

    driver.main(&toolchain, args, fast_exit, assembly_backend.genAsm) catch |er| switch (er) {
        error.OutOfMemory => {
            std.debug.print("out of memory\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
        error.FatalError => {
            driver.printDiagnosticsStats();
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    if (fast_exit) process.exit(@intFromBool(comp.diagnostics.errors != 0));
    return @intFromBool(diagnostics.errors != 0);
}
