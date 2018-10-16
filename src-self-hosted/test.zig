const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const Target = @import("target.zig").Target;
const Compilation = @import("compilation.zig").Compilation;
const introspect = @import("introspect.zig");
const assertOrPanic = std.debug.assertOrPanic;
const errmsg = @import("errmsg.zig");
const ZigCompiler = @import("compilation.zig").ZigCompiler;

var ctx: TestContext = undefined;

test "stage2" {
    try ctx.init();
    defer ctx.deinit();

    try @import("../test/stage2/compile_errors.zig").addCases(&ctx);
    try @import("../test/stage2/compare_output.zig").addCases(&ctx);

    try ctx.run();
}

const file1 = "1.zig";
const allocator = std.heap.c_allocator;

pub const TestContext = struct.{
    loop: std.event.Loop,
    zig_compiler: ZigCompiler,
    zig_lib_dir: []u8,
    file_index: std.atomic.Int(usize),
    group: std.event.Group(error!void),
    any_err: error!void,

    const tmp_dir_name = "stage2_test_tmp";

    fn init(self: *TestContext) !void {
        self.* = TestContext.{
            .any_err = {},
            .loop = undefined,
            .zig_compiler = undefined,
            .zig_lib_dir = undefined,
            .group = undefined,
            .file_index = std.atomic.Int(usize).init(0),
        };

        try self.loop.initSingleThreaded(allocator);
        errdefer self.loop.deinit();

        self.zig_compiler = try ZigCompiler.init(&self.loop);
        errdefer self.zig_compiler.deinit();

        self.group = std.event.Group(error!void).init(&self.loop);
        errdefer self.group.deinit();

        self.zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        errdefer allocator.free(self.zig_lib_dir);

        try std.os.makePath(allocator, tmp_dir_name);
        errdefer std.os.deleteTree(allocator, tmp_dir_name) catch {};
    }

    fn deinit(self: *TestContext) void {
        std.os.deleteTree(allocator, tmp_dir_name) catch {};
        allocator.free(self.zig_lib_dir);
        self.zig_compiler.deinit();
        self.loop.deinit();
    }

    fn run(self: *TestContext) !void {
        const handle = try self.loop.call(waitForGroup, self);
        defer cancel handle;
        self.loop.run();
        return self.any_err;
    }

    async fn waitForGroup(self: *TestContext) void {
        self.any_err = await (async self.group.wait() catch unreachable);
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
        const file_index = try std.fmt.bufPrint(file_index_buf[0..], "{}", self.file_index.incr());
        const file1_path = try std.os.path.join(allocator, tmp_dir_name, file_index, file1);

        if (std.os.path.dirname(file1_path)) |dirname| {
            try std.os.makePath(allocator, dirname);
        }

        // TODO async I/O
        try std.io.writeFile(file1_path, source);

        var comp = try Compilation.create(
            &self.zig_compiler,
            "test",
            file1_path,
            Target.Native,
            Compilation.Kind.Obj,
            builtin.Mode.Debug,
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
        const file_index = try std.fmt.bufPrint(file_index_buf[0..], "{}", self.file_index.incr());
        const file1_path = try std.os.path.join(allocator, tmp_dir_name, file_index, file1);

        const output_file = try std.fmt.allocPrint(allocator, "{}-out{}", file1_path, Target(Target.Native).exeFileExt());
        if (std.os.path.dirname(file1_path)) |dirname| {
            try std.os.makePath(allocator, dirname);
        }

        // TODO async I/O
        try std.io.writeFile(file1_path, source);

        var comp = try Compilation.create(
            &self.zig_compiler,
            "test",
            file1_path,
            Target.Native,
            Compilation.Kind.Exe,
            builtin.Mode.Debug,
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
    ) !void {
        // TODO this should not be necessary
        const exe_file_2 = try std.mem.dupe(allocator, u8, exe_file);

        defer comp.destroy();
        const build_event = await (async comp.events.get() catch unreachable);

        switch (build_event) {
            Compilation.Event.Ok => {
                const argv = []const []const u8.{exe_file_2};
                // TODO use event loop
                const child = try std.os.ChildProcess.exec(allocator, argv, null, null, 1024 * 1024);
                switch (child.term) {
                    std.os.ChildProcess.Term.Exited => |code| {
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
            Compilation.Event.Error => |err| return err,
            Compilation.Event.Fail => |msgs| {
                var stderr = try std.io.getStdErr();
                try stderr.write("build incorrectly failed:\n");
                for (msgs) |msg| {
                    defer msg.destroy();
                    try msg.printToFile(stderr, errmsg.Color.Auto);
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
    ) !void {
        defer comp.destroy();
        const build_event = await (async comp.events.get() catch unreachable);

        switch (build_event) {
            Compilation.Event.Ok => {
                @panic("build incorrectly succeeded");
            },
            Compilation.Event.Error => |err| {
                @panic("build incorrectly failed");
            },
            Compilation.Event.Fail => |msgs| {
                assertOrPanic(msgs.len != 0);
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
                std.debug.warn(
                    "\n=====source:=======\n{}\n====expected:========\n{}:{}:{}: error: {}\n",
                    source,
                    path,
                    line,
                    column,
                    text,
                );
                std.debug.warn("\n====found:========\n");
                var stderr = try std.io.getStdErr();
                for (msgs) |msg| {
                    defer msg.destroy();
                    try msg.printToFile(stderr, errmsg.Color.Auto);
                }
                std.debug.warn("============\n");
                return error.TestFailed;
            },
        }
    }
};
