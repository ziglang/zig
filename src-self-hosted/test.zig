const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const Target = @import("target.zig").Target;
const Compilation = @import("compilation.zig").Compilation;
const introspect = @import("introspect.zig");
const assertOrPanic = std.debug.assertOrPanic;
const errmsg = @import("errmsg.zig");
const EventLoopLocal = @import("compilation.zig").EventLoopLocal;

test "compile errors" {
    var ctx: TestContext = undefined;
    try ctx.init();
    defer ctx.deinit();

    try @import("../test/stage2/compile_errors.zig").addCases(&ctx);
    //try @import("../test/stage2/compare_output.zig").addCases(&ctx);

    try ctx.run();
}

const file1 = "1.zig";
const allocator = std.heap.c_allocator;

pub const TestContext = struct {
    loop: std.event.Loop,
    event_loop_local: EventLoopLocal,
    zig_lib_dir: []u8,
    zig_cache_dir: []u8,
    file_index: std.atomic.Int(usize),
    group: std.event.Group(error!void),
    any_err: error!void,

    const tmp_dir_name = "stage2_test_tmp";

    fn init(self: *TestContext) !void {
        self.* = TestContext{
            .any_err = {},
            .loop = undefined,
            .event_loop_local = undefined,
            .zig_lib_dir = undefined,
            .zig_cache_dir = undefined,
            .group = undefined,
            .file_index = std.atomic.Int(usize).init(0),
        };

        try self.loop.initMultiThreaded(allocator);
        errdefer self.loop.deinit();

        self.event_loop_local = try EventLoopLocal.init(&self.loop);
        errdefer self.event_loop_local.deinit();

        self.group = std.event.Group(error!void).init(&self.loop);
        errdefer self.group.cancelAll();

        self.zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        errdefer allocator.free(self.zig_lib_dir);

        self.zig_cache_dir = try introspect.resolveZigCacheDir(allocator);
        errdefer allocator.free(self.zig_cache_dir);

        try std.os.makePath(allocator, tmp_dir_name);
        errdefer std.os.deleteTree(allocator, tmp_dir_name) catch {};
    }

    fn deinit(self: *TestContext) void {
        std.os.deleteTree(allocator, tmp_dir_name) catch {};
        allocator.free(self.zig_cache_dir);
        allocator.free(self.zig_lib_dir);
        self.event_loop_local.deinit();
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
        try std.io.writeFile(allocator, file1_path, source);

        var comp = try Compilation.create(
            &self.event_loop_local,
            "test",
            file1_path,
            Target.Native,
            Compilation.Kind.Obj,
            builtin.Mode.Debug,
            true, // is_static
            self.zig_lib_dir,
            self.zig_cache_dir,
        );
        errdefer comp.destroy();

        try comp.build();

        try self.group.call(getModuleEvent, comp, source, path, line, column, msg);
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
                    if (mem.endsWith(u8, msg.path, path) and mem.eql(u8, msg.text, text)) {
                        const first_token = msg.tree.tokens.at(msg.span.first);
                        const last_token = msg.tree.tokens.at(msg.span.first);
                        const start_loc = msg.tree.tokenLocationPtr(0, first_token);
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
                    try errmsg.printToFile(&stderr, msg, errmsg.Color.Auto);
                }
                std.debug.warn("============\n");
                return error.TestFailed;
            },
        }
    }
};
