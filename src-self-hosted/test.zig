const std = @import("std");
const link = @import("link.zig");
const ir = @import("ir.zig");
const Allocator = std.mem.Allocator;

var global_ctx: TestContext = undefined;

test "self-hosted" {
    try global_ctx.init();
    defer global_ctx.deinit();

    try @import("stage2_tests").addCases(&global_ctx);

    try global_ctx.run();
}

pub const TestContext = struct {
    zir_cmp_output_cases: std.ArrayList(ZIRCompareOutputCase),

    pub const ZIRCompareOutputCase = struct {
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    };

    pub fn addZIRCompareOutput(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.zir_cmp_output_cases.append(.{
            .name = name,
            .src = src,
            .expected_stdout = expected_stdout,
        }) catch unreachable;
    }

    fn init(self: *TestContext) !void {
        self.* = .{
            .zir_cmp_output_cases = std.ArrayList(ZIRCompareOutputCase).init(std.heap.page_allocator),
        };
    }

    fn deinit(self: *TestContext) void {
        self.zir_cmp_output_cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("zir", self.zir_cmp_output_cases.items.len);
        defer root_node.end();

        const native_info = try std.zig.system.NativeTargetInfo.detect(std.heap.page_allocator, .{});

        for (self.zir_cmp_output_cases.items) |case| {
            std.testing.base_allocator_instance.reset();
            try self.runOneZIRCmpOutputCase(std.testing.allocator, root_node, case, native_info.target);
            try std.testing.allocator_instance.validate();
        }
    }

    fn runOneZIRCmpOutputCase(
        self: *TestContext,
        allocator: *Allocator,
        root_node: *std.Progress.Node,
        case: ZIRCompareOutputCase,
        target: std.Target,
    ) !void {
        var tmp = std.testing.tmpDir(.{ .share_with_child_process = true });
        defer tmp.cleanup();

        var prg_node = root_node.start(case.name, 4);
        prg_node.activate();
        defer prg_node.end();

        var zir_module = x: {
            var parse_node = prg_node.start("parse", null);
            parse_node.activate();
            defer parse_node.end();

            break :x try ir.text.parse(allocator, case.src);
        };
        defer zir_module.deinit(allocator);
        if (zir_module.errors.len != 0) {
            debugPrintErrors(case.src, zir_module.errors);
            return error.ParseFailure;
        }

        var analyzed_module = x: {
            var analyze_node = prg_node.start("analyze", null);
            analyze_node.activate();
            defer analyze_node.end();

            break :x try ir.analyze(allocator, zir_module, target);
        };
        defer analyzed_module.deinit(allocator);
        if (analyzed_module.errors.len != 0) {
            debugPrintErrors(case.src, analyzed_module.errors);
            return error.ParseFailure;
        }

        var link_result = x: {
            var link_node = prg_node.start("link", null);
            link_node.activate();
            defer link_node.end();

            break :x try link.updateExecutableFilePath(
                allocator,
                analyzed_module,
                tmp.dir,
                "a.out",
            );
        };
        defer link_result.deinit(allocator);
        if (link_result.errors.len != 0) {
            debugPrintErrors(case.src, link_result.errors);
            return error.LinkFailure;
        }

        var exec_result = x: {
            var exec_node = prg_node.start("execute", null);
            exec_node.activate();
            defer exec_node.end();

            break :x try std.ChildProcess.exec(.{
                .allocator = allocator,
                .argv = &[_][]const u8{"./a.out"},
                .cwd_dir = tmp.dir,
            });
        };
        defer allocator.free(exec_result.stdout);
        defer allocator.free(exec_result.stderr);
        switch (exec_result.term) {
            .Exited => |code| {
                if (code != 0) {
                    std.debug.warn("elf file exited with code {}\n", .{code});
                    return error.BinaryBadExitCode;
                }
            },
            else => return error.BinaryCrashed,
        }
        std.testing.expectEqualSlices(u8, case.expected_stdout, exec_result.stdout);
    }
};

fn debugPrintErrors(src: []const u8, errors: var) void {
    std.debug.warn("\n", .{});
    var nl = true;
    var line: usize = 1;
    for (src) |byte| {
        if (nl) {
            std.debug.warn("{: >3}| ", .{line});
            nl = false;
        }
        if (byte == '\n') {
            nl = true;
            line += 1;
        }
        std.debug.warn("{c}", .{byte});
    }
    std.debug.warn("\n", .{});
    for (errors) |err_msg| {
        const loc = std.zig.findLineColumn(src, err_msg.byte_offset);
        std.debug.warn("{}:{}: error: {}\n", .{ loc.line + 1, loc.column + 1, err_msg.msg });
    }
}
