const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const process = std.process;
const aro = @import("aro");
const Translator = @import("Translator.zig");

const fast_exit = @import("builtin").mode != .Debug;

var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;

pub fn main() u8 {
    const gpa = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = process.argsAlloc(arena) catch {
        std.debug.print("ran out of memory allocating arguments\n", .{});
        if (fast_exit) process.exit(1);
        return 1;
    };

    var stderr_buf: [1024]u8 = undefined;
    var stderr = std.fs.File.stderr().writer(&stderr_buf);
    var diagnostics: aro.Diagnostics = .{
        .output = .{ .to_writer = .{
            .color = .detect(stderr.file),
            .writer = &stderr.interface,
        } },
    };

    var comp = aro.Compilation.initDefault(gpa, arena, &diagnostics, std.fs.cwd()) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("ran out of memory initializing C compilation\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    defer comp.deinit();

    var driver: aro.Driver = .{ .comp = &comp, .diagnostics = &diagnostics, .aro_name = "aro" };
    defer driver.deinit();

    var toolchain: aro.Toolchain = .{ .driver = &driver, .filesystem = .{ .real = comp.cwd } };
    defer toolchain.deinit();

    translate(&driver, &toolchain, args) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("ran out of memory translating\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
        error.FatalError => {
            if (fast_exit) process.exit(1);
            return 1;
        },
        error.WriteFailed => {
            std.debug.print("unable to write to stdout\n", .{});
            if (fast_exit) process.exit(1);
            return 1;
        },
    };
    if (fast_exit) process.exit(@intFromBool(comp.diagnostics.errors != 0));
    return @intFromBool(comp.diagnostics.errors != 0);
}

pub const usage =
    \\Usage {s}: [options] file [CC options]
    \\
    \\Options:
    \\  --help              Print this message
    \\  --version           Print translate-c version
    \\  -fmodule-libs       Import libraries as modules
    \\  -fno-module-libs    (default) Install libraries next to output file
    \\
    \\
;

fn translate(d: *aro.Driver, tc: *aro.Toolchain, args: [][:0]u8) !void {
    const gpa = d.comp.gpa;

    const aro_args = args: {
        var i: usize = 0;
        for (args) |arg| {
            args[i] = arg;
            if (mem.eql(u8, arg, "--help")) {
                var stdout_buf: [512]u8 = undefined;
                var stdout = std.fs.File.stdout().writer(&stdout_buf);
                try stdout.interface.print(usage, .{args[0]});
                try stdout.interface.flush();
                return;
            } else if (mem.eql(u8, arg, "--version")) {
                var stdout_buf: [512]u8 = undefined;
                var stdout = std.fs.File.stdout().writer(&stdout_buf);
                // TODO add version
                try stdout.interface.writeAll("0.0.0-dev\n");
                try stdout.interface.flush();
                return;
            } else {
                i += 1;
            }
        }
        break :args args[0..i];
    };
    const user_macros = macros: {
        var macro_buf: std.ArrayListUnmanaged(u8) = .empty;
        defer macro_buf.deinit(gpa);

        var discard_buf: [256]u8 = undefined;
        var discarding: std.Io.Writer.Discarding = .init(&discard_buf);
        assert(!try d.parseArgs(&discarding.writer, &macro_buf, aro_args));
        if (macro_buf.items.len > std.math.maxInt(u32)) {
            return d.fatal("user provided macro source exceeded max size", .{});
        }

        const content = try macro_buf.toOwnedSlice(gpa);
        errdefer gpa.free(content);

        break :macros try d.comp.addSourceFromOwnedBuffer("<command line>", content, .user);
    };

    if (d.inputs.items.len != 1) {
        return d.fatal("expected exactly one input file", .{});
    }
    const source = d.inputs.items[0];

    tc.discover() catch |er| switch (er) {
        error.OutOfMemory => return error.OutOfMemory,
        error.TooManyMultilibs => return d.fatal("found more than one multilib with the same priority", .{}),
    };
    tc.defineSystemIncludes() catch |er| switch (er) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AroIncludeNotFound => return d.fatal("unable to find Aro builtin headers", .{}),
    };

    const builtin_macros = d.comp.generateBuiltinMacros(.include_system_defines) catch |err| switch (err) {
        error.FileTooBig => return d.fatal("builtin macro source exceeded max size", .{}),
        else => |e| return e,
    };

    var pp = try aro.Preprocessor.initDefault(d.comp);
    defer pp.deinit();

    var name_buf: [std.fs.max_name_bytes]u8 = undefined;
    // Omit the source file from the dep file so that it can be tracked separately.
    // In the Zig compiler we want to omit it from the cache hash since it will
    // be written to a tmp file then renamed into place, meaning the path will be
    // wrong as soon as the work is done.
    var opt_dep_file = try d.initDepFile(source, &name_buf, true);
    defer if (opt_dep_file) |*dep_file| dep_file.deinit(gpa);

    if (opt_dep_file) |*dep_file| pp.dep_file = dep_file;

    try pp.preprocessSources(&.{ source, builtin_macros, user_macros });

    var c_tree = try pp.parse();
    defer c_tree.deinit();

    if (d.diagnostics.errors != 0) {
        if (fast_exit) process.exit(1);
        return error.FatalError;
    }

    var out_buf: [4096]u8 = undefined;
    if (opt_dep_file) |dep_file| {
        const dep_file_name = try d.getDepFileName(source, out_buf[0..std.fs.max_name_bytes]);

        const file = if (dep_file_name) |path|
            d.comp.cwd.createFile(path, .{}) catch |er|
                return d.fatal("unable to create dependency file '{s}': {s}", .{ path, aro.Driver.errorDescription(er) })
        else
            std.fs.File.stdout();
        defer if (dep_file_name != null) file.close();

        var file_writer = file.writer(&out_buf);
        dep_file.write(&file_writer.interface) catch
            return d.fatal("unable to write dependency file: {s}", .{aro.Driver.errorDescription(file_writer.err.?)});
    }

    const rendered_zig = try Translator.translate(.{
        .gpa = gpa,
        .comp = d.comp,
        .pp = &pp,
        .tree = &c_tree,
    });
    defer gpa.free(rendered_zig);

    var close_out_file = false;
    var out_file_path: []const u8 = "<stdout>";
    var out_file: std.fs.File = .stdout();
    defer if (close_out_file) out_file.close();

    if (d.output_name) |path| blk: {
        if (std.mem.eql(u8, path, "-")) break :blk;
        if (std.fs.path.dirname(path)) |dirname| {
            std.fs.cwd().makePath(dirname) catch |err|
                return d.fatal("failed to create path to '{s}': {s}", .{ path, aro.Driver.errorDescription(err) });
        }
        out_file = std.fs.cwd().createFile(path, .{}) catch |err| {
            return d.fatal("failed to create output file '{s}': {s}", .{ path, aro.Driver.errorDescription(err) });
        };
        close_out_file = true;
        out_file_path = path;
    }

    var out_writer = out_file.writer(&out_buf);
    out_writer.interface.writeAll(rendered_zig) catch {};
    out_writer.interface.flush() catch {};
    if (out_writer.err) |write_err|
        return d.fatal("failed to write result to '{s}': {s}", .{ out_file_path, aro.Driver.errorDescription(write_err) });

    if (fast_exit) process.exit(0);
}

test {
    _ = Translator;
    _ = @import("helpers.zig");
    _ = @import("PatternList.zig");
}
