const std = @import("std");
const link = @import("link.zig");
const Module = @import("Module.zig");
const Allocator = std.mem.Allocator;
const zir = @import("zir.zig");
const Package = @import("Package.zig");

test "self-hosted" {
    var ctx: TestContext = undefined;
    try ctx.init();
    defer ctx.deinit();

    try @import("stage2_tests").addCases(&ctx);

    try ctx.run();
}

pub const TestContext = struct {
    zir_cmp_output_cases: std.ArrayList(ZIRCompareOutputCase),
    zir_transform_cases: std.ArrayList(ZIRTransformCase),

    pub const ZIRCompareOutputCase = struct {
        name: []const u8,
        src_list: []const []const u8,
        expected_stdout_list: []const []const u8,
    };

    pub const ZIRTransformCase = struct {
        name: []const u8,
        src: [:0]const u8,
        expected_zir: []const u8,
        cross_target: std.zig.CrossTarget,
    };

    pub fn addZIRCompareOutput(
        ctx: *TestContext,
        name: []const u8,
        src_list: []const []const u8,
        expected_stdout_list: []const []const u8,
    ) void {
        ctx.zir_cmp_output_cases.append(.{
            .name = name,
            .src_list = src_list,
            .expected_stdout_list = expected_stdout_list,
        }) catch unreachable;
    }

    pub fn addZIRTransform(
        ctx: *TestContext,
        name: []const u8,
        cross_target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_zir: []const u8,
    ) void {
        ctx.zir_transform_cases.append(.{
            .name = name,
            .src = src,
            .expected_zir = expected_zir,
            .cross_target = cross_target,
        }) catch unreachable;
    }

    fn init(self: *TestContext) !void {
        self.* = .{
            .zir_cmp_output_cases = std.ArrayList(ZIRCompareOutputCase).init(std.heap.page_allocator),
            .zir_transform_cases = std.ArrayList(ZIRTransformCase).init(std.heap.page_allocator),
        };
    }

    fn deinit(self: *TestContext) void {
        self.zir_cmp_output_cases.deinit();
        self.zir_transform_cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("zir", self.zir_cmp_output_cases.items.len +
            self.zir_transform_cases.items.len);
        defer root_node.end();

        const native_info = try std.zig.system.NativeTargetInfo.detect(std.heap.page_allocator, .{});

        for (self.zir_cmp_output_cases.items) |case| {
            std.testing.base_allocator_instance.reset();
            try self.runOneZIRCmpOutputCase(std.testing.allocator, root_node, case, native_info.target);
            try std.testing.allocator_instance.validate();
        }
        for (self.zir_transform_cases.items) |case| {
            std.testing.base_allocator_instance.reset();
            const info = try std.zig.system.NativeTargetInfo.detect(std.testing.allocator, case.cross_target);
            try self.runOneZIRTransformCase(std.testing.allocator, root_node, case, info.target);
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
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const tmp_src_path = "test-case.zir";
        const root_pkg = try Package.create(allocator, tmp.dir, ".", tmp_src_path);
        defer root_pkg.destroy();

        var prg_node = root_node.start(case.name, case.src_list.len);
        prg_node.activate();
        defer prg_node.end();

        var module = try Module.init(allocator, .{
            .target = target,
            .output_mode = .Exe,
            .optimize_mode = .Debug,
            .bin_file_dir = tmp.dir,
            .bin_file_path = "a.out",
            .root_pkg = root_pkg,
        });
        defer module.deinit();

        for (case.src_list) |source, i| {
            var src_node = prg_node.start("update", 2);
            src_node.activate();
            defer src_node.end();

            try tmp.dir.writeFile(tmp_src_path, source);

            var update_node = src_node.start("parse,analysis,codegen", null);
            update_node.activate();
            try module.makeBinFileWritable();
            try module.update();
            update_node.end();

            var exec_result = x: {
                var exec_node = src_node.start("execute", null);
                exec_node.activate();
                defer exec_node.end();

                try module.makeBinFileExecutable();
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
            const expected_stdout = case.expected_stdout_list[i];
            if (!std.mem.eql(u8, expected_stdout, exec_result.stdout)) {
                std.debug.panic(
                    "update index {}, mismatched stdout\n====Expected (len={}):====\n{}\n====Actual (len={}):====\n{}\n========\n",
                    .{ i, expected_stdout.len, expected_stdout, exec_result.stdout.len, exec_result.stdout },
                );
            }
        }
    }

    fn runOneZIRTransformCase(
        self: *TestContext,
        allocator: *Allocator,
        root_node: *std.Progress.Node,
        case: ZIRTransformCase,
        target: std.Target,
    ) !void {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        var prg_node = root_node.start(case.name, 3);
        prg_node.activate();
        defer prg_node.end();

        const tmp_src_path = "test-case.zir";
        try tmp.dir.writeFile(tmp_src_path, case.src);

        const root_pkg = try Package.create(allocator, tmp.dir, ".", tmp_src_path);
        defer root_pkg.destroy();

        var module = try Module.init(allocator, .{
            .target = target,
            .output_mode = .Obj,
            .optimize_mode = .Debug,
            .bin_file_dir = tmp.dir,
            .bin_file_path = "test-case.o",
            .root_pkg = root_pkg,
        });
        defer module.deinit();

        var module_node = prg_node.start("parse/analysis/codegen", null);
        module_node.activate();
        try module.update();
        module_node.end();

        var emit_node = prg_node.start("emit", null);
        emit_node.activate();
        var new_zir_module = try zir.emit(allocator, module);
        defer new_zir_module.deinit(allocator);
        emit_node.end();

        var write_node = prg_node.start("write", null);
        write_node.activate();
        var out_zir = std.ArrayList(u8).init(allocator);
        defer out_zir.deinit();
        try new_zir_module.writeToStream(allocator, out_zir.outStream());
        write_node.end();

        std.testing.expectEqualSlices(u8, case.expected_zir, out_zir.items);
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
