const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const Target = @import("target.zig").Target;
const Module = @import("module.zig").Module;
const introspect = @import("introspect.zig");
const assertOrPanic = std.debug.assertOrPanic;
const errmsg = @import("errmsg.zig");

test "compile errors" {
    var ctx: TestContext = undefined;
    try ctx.init();
    defer ctx.deinit();

    try ctx.testCompileError(
        \\export fn entry() void {}
        \\export fn entry() void {}
    , file1, 2, 8, "exported symbol collision: 'entry'");

    try ctx.run();
}

const file1 = "1.zig";

const TestContext = struct {
    loop: std.event.Loop,
    zig_lib_dir: []u8,
    direct_allocator: std.heap.DirectAllocator,
    arena: std.heap.ArenaAllocator,
    zig_cache_dir: []u8,
    file_index: std.atomic.Int(usize),
    group: std.event.Group(error!void),
    any_err: error!void,

    const tmp_dir_name = "stage2_test_tmp";

    fn init(self: *TestContext) !void {
        self.* = TestContext{
            .any_err = {},
            .direct_allocator = undefined,
            .arena = undefined,
            .loop = undefined,
            .zig_lib_dir = undefined,
            .zig_cache_dir = undefined,
            .group = undefined,
            .file_index = std.atomic.Int(usize).init(0),
        };

        self.direct_allocator = std.heap.DirectAllocator.init();
        errdefer self.direct_allocator.deinit();

        self.arena = std.heap.ArenaAllocator.init(&self.direct_allocator.allocator);
        errdefer self.arena.deinit();

        // TODO faster allocator for coroutines that is thread-safe/lock-free
        try self.loop.initMultiThreaded(&self.direct_allocator.allocator);
        errdefer self.loop.deinit();

        self.group = std.event.Group(error!void).init(&self.loop);
        errdefer self.group.cancelAll();

        self.zig_lib_dir = try introspect.resolveZigLibDir(&self.arena.allocator);
        errdefer self.arena.allocator.free(self.zig_lib_dir);

        self.zig_cache_dir = try introspect.resolveZigCacheDir(&self.arena.allocator);
        errdefer self.arena.allocator.free(self.zig_cache_dir);

        try std.os.makePath(&self.arena.allocator, tmp_dir_name);
        errdefer std.os.deleteTree(&self.arena.allocator, tmp_dir_name) catch {};
    }

    fn deinit(self: *TestContext) void {
        std.os.deleteTree(&self.arena.allocator, tmp_dir_name) catch {};
        self.arena.allocator.free(self.zig_cache_dir);
        self.arena.allocator.free(self.zig_lib_dir);
        self.loop.deinit();
        self.arena.deinit();
        self.direct_allocator.deinit();
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
        const file_index = try std.fmt.bufPrint(file_index_buf[0..], "{}", self.file_index.next());
        const file1_path = try std.os.path.join(&self.arena.allocator, tmp_dir_name, file_index, file1);

        if (std.os.path.dirname(file1_path)) |dirname| {
            try std.os.makePath(&self.arena.allocator, dirname);
        }

        // TODO async I/O
        try std.io.writeFile(&self.arena.allocator, file1_path, source);

        var module = try Module.create(
            &self.loop,
            "test",
            file1_path,
            Target.Native,
            Module.Kind.Obj,
            builtin.Mode.Debug,
            self.zig_lib_dir,
            self.zig_cache_dir,
        );
        errdefer module.destroy();

        try module.build();

        try self.group.call(getModuleEvent, module, source, path, line, column, msg);
    }

    async fn getModuleEvent(
        module: *Module,
        source: []const u8,
        path: []const u8,
        line: usize,
        column: usize,
        text: []const u8,
    ) !void {
        defer module.destroy();
        const build_event = await (async module.events.get() catch unreachable);

        switch (build_event) {
            Module.Event.Ok => {
                @panic("build incorrectly succeeded");
            },
            Module.Event.Error => |err| {
                @panic("build incorrectly failed");
            },
            Module.Event.Fail => |msgs| {
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
