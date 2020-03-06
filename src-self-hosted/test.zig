const std = @import("std");
const mem = std.mem;
const Target = std.Target;
const Compilation = @import("compilation.zig").Compilation;
const introspect = @import("introspect.zig");
const testing = std.testing;
const errmsg = @import("errmsg.zig");
const ZigCompiler = @import("compilation.zig").ZigCompiler;

var ctx: TestContext = undefined;

test "stage2" {
    // TODO provide a way to run tests in evented I/O mode
    if (!std.io.is_async) return error.SkipZigTest;

    // TODO https://github.com/ziglang/zig/issues/1364
    // TODO https://github.com/ziglang/zig/issues/3117
    if (true) return error.SkipZigTest;

    try ctx.init();
    defer ctx.deinit();

    try @import("stage2_tests").addCases(&ctx);

    try ctx.run();
}

const file1 = "1.zig";
// TODO https://github.com/ziglang/zig/issues/3783
const allocator = std.heap.page_allocator;

pub const TestContext = struct {
    zig_compiler: ZigCompiler,
    zig_lib_dir: []u8,
    file_index: std.atomic.Int(usize),
    group: std.event.Group(anyerror!void),
    any_err: anyerror!void,

    const tmp_dir_name = "stage2_test_tmp";

    fn init(self: *TestContext) !void {
        self.* = TestContext{
            .any_err = {},
            .zig_compiler = undefined,
            .zig_lib_dir = undefined,
            .group = undefined,
            .file_index = std.atomic.Int(usize).init(0),
        };

        self.zig_compiler = try ZigCompiler.init(allocator);
        errdefer self.zig_compiler.deinit();

        self.group = std.event.Group(anyerror!void).init(allocator);
        errdefer self.group.wait() catch {};

        self.zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        errdefer allocator.free(self.zig_lib_dir);

        try std.fs.cwd().makePath(tmp_dir_name);
        errdefer std.fs.deleteTree(tmp_dir_name) catch {};
    }

    fn deinit(self: *TestContext) void {
        std.fs.deleteTree(tmp_dir_name) catch {};
        allocator.free(self.zig_lib_dir);
        self.zig_compiler.deinit();
    }

    fn run(self: *TestContext) !void {
        std.event.Loop.startCpuBoundOperation();
        self.any_err = self.group.wait();
        return self.any_err;
    }

    fn testCompileError(
        self: *TestContext,
        source: []const u8,
        path: []const u8,
        line: usize,
        column: usize,
        msg: []const u8,
    ) !void {
        var file_index_buf: [20]u8 = undefined;
        const file_index = try std.fmt.bufPrint(file_index_buf[0..], "{}", .{self.file_index.incr()});
        const file1_path = try std.fs.path.join(allocator, [_][]const u8{ tmp_dir_name, file_index, file1 });

        if (std.fs.path.dirname(file1_path)) |dirname| {
            try std.fs.cwd().makePath(dirname);
        }

        // TODO async I/O
        try std.io.writeFile(file1_path, source);

        var comp = try Compilation.create(
            &self.zig_compiler,
            "test",
            file1_path,
            .Native,
            .Obj,
            .Debug,
            true, // is_static
            self.zig_lib_dir,
        );
        errdefer comp.destroy();

        comp.start();

        try self.group.call(getModuleEvent, comp, source, path, line, column, msg);
    }

    fn testCompareOutputLibC(
        self: *TestContext,
        source: []const u8,
        expected_output: []const u8,
    ) !void {
        var file_index_buf: [20]u8 = undefined;
        const file_index = try std.fmt.bufPrint(file_index_buf[0..], "{}", .{self.file_index.incr()});
        const file1_path = try std.fs.path.join(allocator, [_][]const u8{ tmp_dir_name, file_index, file1 });

        const output_file = try std.fmt.allocPrint(allocator, "{}-out{}", .{ file1_path, (Target{ .Native = {} }).exeFileExt() });
        if (std.fs.path.dirname(file1_path)) |dirname| {
            try std.fs.cwd().makePath(dirname);
        }

        // TODO async I/O
        try std.io.writeFile(file1_path, source);

        var comp = try Compilation.create(
            &self.zig_compiler,
            "test",
            file1_path,
            .Native,
            .Exe,
            .Debug,
            false,
            self.zig_lib_dir,
        );
        errdefer comp.destroy();

        _ = try comp.addLinkLib("c", true);
        comp.link_out_file = output_file;
        comp.start();

        try self.group.call(getModuleEventSuccess, comp, output_file, expected_output);
    }

    async fn getModuleEventSuccess(
        comp: *Compilation,
        exe_file: []const u8,
        expected_output: []const u8,
    ) anyerror!void {
        defer comp.destroy();
        const build_event = comp.events.get();

        switch (build_event) {
            .Ok => {
                const argv = [_][]const u8{exe_file};
                // TODO use event loop
                const child = try std.ChildProcess.exec(allocator, argv, null, null, 1024 * 1024);
                switch (child.term) {
                    .Exited => |code| {
                        if (code != 0) {
                            return error.BadReturnCode;
                        }
                    },
                    else => {
                        return error.Crashed;
                    },
                }
                if (!mem.eql(u8, child.stdout, expected_output)) {
                    return error.OutputMismatch;
                }
            },
            .Error => @panic("Cannot return error: https://github.com/ziglang/zig/issues/3190"), // |err| return err,
            .Fail => |msgs| {
                const stderr = std.io.getStdErr();
                try stderr.write("build incorrectly failed:\n");
                for (msgs) |msg| {
                    defer msg.destroy();
                    try msg.printToFile(stderr, .Auto);
                }
            },
        }
    }

    async fn getModuleEvent(
        comp: *Compilation,
        source: []const u8,
        path: []const u8,
        line: usize,
        column: usize,
        text: []const u8,
    ) anyerror!void {
        defer comp.destroy();
        const build_event = comp.events.get();

        switch (build_event) {
            .Ok => {
                @panic("build incorrectly succeeded");
            },
            .Error => |err| {
                @panic("build incorrectly failed");
            },
            .Fail => |msgs| {
                testing.expect(msgs.len != 0);
                for (msgs) |msg| {
                    if (mem.endsWith(u8, msg.realpath, path) and mem.eql(u8, msg.text, text)) {
                        const span = msg.getSpan();
                        const first_token = msg.getTree().tokens.at(span.first);
                        const last_token = msg.getTree().tokens.at(span.first);
                        const start_loc = msg.getTree().tokenLocationPtr(0, first_token);
                        if (start_loc.line + 1 == line and start_loc.column + 1 == column) {
                            return;
                        }
                    }
                }
                std.debug.warn("\n=====source:=======\n{}\n====expected:========\n{}:{}:{}: error: {}\n", .{
                    source,
                    path,
                    line,
                    column,
                    text,
                });
                std.debug.warn("\n====found:========\n", .{});
                const stderr = std.io.getStdErr();
                for (msgs) |msg| {
                    defer msg.destroy();
                    try msg.printToFile(stderr, errmsg.Color.Auto);
                }
                std.debug.warn("============\n", .{});
                return error.TestFailed;
            },
        }
    }
};
