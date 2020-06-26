const std = @import("std");
const link = @import("link.zig");
const Module = @import("Module.zig");
const Allocator = std.mem.Allocator;
const zir = @import("zir.zig");
const Package = @import("Package.zig");

test "self-hosted" {
    var ctx = TestContext.init();
    defer ctx.deinit();

    try @import("stage2_tests").addCases(&ctx);

    try ctx.run();
}

const ErrorMsg = struct {
    msg: []const u8,
    line: u32,
    column: u32,
};

pub const TestContext = struct {
    /// TODO: find a way to treat cases as individual tests (shouldn't show "1 test passed" if there are 200 cases)
    cases: std.ArrayList(Case),

    pub const Update = struct {
        /// The input to the current update. We simulate an incremental update
        /// with the file's contents changed to this value each update.
        ///
        /// This value can change entirely between updates, which would be akin
        /// to deleting the source file and creating a new one from scratch; or
        /// you can keep it mostly consistent, with small changes, testing the
        /// effects of the incremental compilation.
        src: [:0]const u8,
        case: union(enum) {
            /// A transformation update transforms the input ZIR and tests against
            /// the expected output ZIR.
            Transformation: [:0]const u8,
            /// An error update attempts to compile bad code, and ensures that it
            /// fails to compile, and for the expected reasons.
            /// A slice containing the expected errors *in sequential order*.
            Error: []const ErrorMsg,
            /// An execution update compiles and runs the input, testing the
            /// stdout against the expected results
            Execution: []const u8,
        },
    };

    pub const TestType = enum {
        Zig,
        ZIR,
    };

    /// A Case consists of a set of *updates*. The same Module is used for each
    /// update, so each update's source is treated as a single file being
    /// updated by the test harness and incrementally compiled.
    pub const Case = struct {
        name: []const u8,
        /// The platform the test targets. For non-native platforms, an emulator
        /// such as QEMU is required for tests to complete.
        target: std.zig.CrossTarget,
        output_mode: std.builtin.OutputMode,
        updates: std.ArrayList(Update),
        @"type": TestType,

        /// Adds a subcase in which the module is updated with new ZIR, and the
        /// resulting ZIR is validated.
        pub fn addTransform(self: *Case, src: [:0]const u8, result: [:0]const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .Transformation = result },
            }) catch unreachable;
        }

        pub fn addCompareOutput(self: *Case, src: [:0]const u8, result: []const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .Execution = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with invalid ZIR, and
        /// ensures that compilation fails for the expected reasons.
        ///
        /// Errors must be specified in sequential order.
        pub fn addError(self: *Case, src: [:0]const u8, errors: []const []const u8) void {
            var array = self.updates.allocator.alloc(ErrorMsg, errors.len) catch unreachable;
            for (errors) |e, i| {
                if (e[0] != ':') {
                    @panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n");
                }
                var cur = e[1..];
                var line_index = std.mem.indexOf(u8, cur, ":");
                if (line_index == null) {
                    @panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n");
                }
                const line = std.fmt.parseInt(u32, cur[0..line_index.?], 10) catch @panic("Unable to parse line number");
                cur = cur[line_index.? + 1 ..];
                const column_index = std.mem.indexOf(u8, cur, ":");
                if (column_index == null) {
                    @panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n");
                }
                const column = std.fmt.parseInt(u32, cur[0..column_index.?], 10) catch @panic("Unable to parse column number");
                cur = cur[column_index.? + 2 ..];
                if (!std.mem.eql(u8, cur[0..7], "error: ")) {
                    @panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n");
                }
                const msg = cur[7..];

                if (line == 0 or column == 0) {
                    @panic("Invalid test: error line and column must be specified starting at one!");
                }

                array[i] = .{
                    .msg = msg,
                    .line = line - 1,
                    .column = column - 1,
                };
            }
            self.updates.append(.{ .src = src, .case = .{ .Error = array } }) catch unreachable;
        }

        pub fn compiles(self: *Case, src: [:0]const u8) void {
            self.addError(src, &[_][]const u8{});
        }
    };

    pub fn addExe(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        T: TestType,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .@"type" = T,
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn exe(ctx: *TestContext, name: []const u8, target: std.zig.CrossTarget) *Case {
        return ctx.addExe(name, target, .Zig);
    }

    pub fn exeZIR(ctx: *TestContext, name: []const u8, target: std.zig.CrossTarget) *Case {
        return ctx.addExe(name, target, .ZIR);
    }

    pub fn addObj(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        T: TestType,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Obj,
            .@"type" = T,
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn obj(ctx: *TestContext, name: []const u8, target: std.zig.CrossTarget) *Case {
        return ctx.addObj(name, target, .Zig);
    }

    pub fn objZIR(ctx: *TestContext, name: []const u8, target: std.zig.CrossTarget) *Case {
        return ctx.addObj(name, target, .ZIR);
    }

    pub fn addCompareOutput(
        ctx: *TestContext,
        name: []const u8,
        T: TestType,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.addExe(name, .{}, T).addCompareOutput(src, expected_stdout);
    }

    pub fn compareOutput(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        return ctx.addCompareOutput(name, .Zig, src, expected_stdout);
    }

    pub fn compareOutputZIR(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.addCompareOutput(name, .ZIR, src, expected_stdout);
    }

    pub fn addTransform(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        T: TestType,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addObj(name, target, T).addTransform(src, result);
    }

    pub fn transform(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addTransform(name, target, .Zig, src, result);
    }

    pub fn transformZIR(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addTransform(name, target, .ZIR, src, result);
    }

    pub fn addError(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        T: TestType,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addObj(name, target, T).addError(src, expected_errors);
    }

    pub fn compileError(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, .Zig, src, expected_errors);
    }

    pub fn compileErrorZIR(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, .ZIR, src, expected_errors);
    }

    pub fn addCompiles(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        T: TestType,
        src: [:0]const u8,
    ) void {
        ctx.addObj(name, target, T).compiles(src);
    }

    pub fn incrementalFailure(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target, .Zig);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    pub fn incrementalFailureZIR(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target, .ZIR);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    pub fn compiles(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, .Zig, src);
    }

    pub fn compilesZIR(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, .ZIR, src);
    }

    fn init() TestContext {
        const allocator = std.heap.page_allocator;
        return .{ .cases = std.ArrayList(Case).init(allocator) };
    }

    fn deinit(self: *TestContext) void {
        for (self.cases.items) |c| {
            for (c.updates.items) |u| {
                if (u.case == .Error) {
                    c.updates.allocator.free(u.case.Error);
                }
            }
            c.updates.deinit();
        }
        self.cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("tests", self.cases.items.len);
        defer root_node.end();

        const native_info = try std.zig.system.NativeTargetInfo.detect(std.heap.page_allocator, .{});

        for (self.cases.items) |case| {
            std.testing.base_allocator_instance.reset();

            var prg_node = root_node.start(case.name, case.updates.items.len);
            prg_node.activate();
            defer prg_node.end();

            // So that we can see which test case failed when the leak checker goes off.
            progress.refresh();

            const info = try std.zig.system.NativeTargetInfo.detect(std.testing.allocator, case.target);
            try self.runOneCase(std.testing.allocator, &prg_node, case, info.target);
            try std.testing.allocator_instance.validate();
        }
    }

    fn runOneCase(self: *TestContext, allocator: *Allocator, root_node: *std.Progress.Node, case: Case, target: std.Target) !void {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const tmp_src_path = if (case.type == .Zig) "test_case.zig" else if (case.type == .ZIR) "test_case.zir" else unreachable;
        const root_pkg = try Package.create(allocator, tmp.dir, ".", tmp_src_path);
        defer root_pkg.destroy();

        var prg_node = root_node.start(case.name, case.updates.items.len);
        prg_node.activate();
        defer prg_node.end();

        const bin_name = try std.zig.binNameAlloc(allocator, "test_case", target, case.output_mode, null);
        defer allocator.free(bin_name);

        var module = try Module.init(allocator, .{
            .target = target,
            // This is an Executable, as opposed to e.g. a *library*. This does
            // not mean no ZIR is generated.
            //
            // TODO: support tests for object file building, and library builds
            // and linking. This will require a rework to support multi-file
            // tests.
            .output_mode = case.output_mode,
            // TODO: support testing optimizations
            .optimize_mode = .Debug,
            .bin_file_dir = tmp.dir,
            .bin_file_path = bin_name,
            .root_pkg = root_pkg,
            .keep_source_files_loaded = true,
        });
        defer module.deinit();

        for (case.updates.items) |update, update_index| {
            var update_node = prg_node.start("update", 4);
            update_node.activate();
            defer update_node.end();

            var sync_node = update_node.start("write", null);
            sync_node.activate();
            try tmp.dir.writeFile(tmp_src_path, update.src);
            sync_node.end();

            var module_node = update_node.start("parse/analysis/codegen", null);
            module_node.activate();
            try module.makeBinFileWritable();
            try module.update();
            module_node.end();

            switch (update.case) {
                .Transformation => |expected_output| {
                    var emit_node = update_node.start("emit", null);
                    emit_node.activate();
                    var new_zir_module = try zir.emit(allocator, module);
                    defer new_zir_module.deinit(allocator);
                    emit_node.end();

                    var write_node = update_node.start("write", null);
                    write_node.activate();
                    var out_zir = std.ArrayList(u8).init(allocator);
                    defer out_zir.deinit();
                    try new_zir_module.writeToStream(allocator, out_zir.outStream());
                    write_node.end();

                    std.testing.expectEqualSlices(u8, expected_output, out_zir.items);
                },
                .Error => |e| {
                    var handled_errors = try allocator.alloc(bool, e.len);
                    defer allocator.free(handled_errors);
                    for (handled_errors) |*h| {
                        h.* = false;
                    }
                    var all_errors = try module.getAllErrorsAlloc();
                    defer all_errors.deinit(allocator);
                    for (all_errors.list) |a| {
                        for (e) |ex, i| {
                            if (a.line == ex.line and a.column == ex.column and std.mem.eql(u8, ex.msg, a.msg)) {
                                handled_errors[i] = true;
                                break;
                            }
                        } else {
                            std.debug.warn("{}\nUnexpected error:\n================\n:{}:{}: error: {}\n================\nTest failed.\n", .{ case.name, a.line + 1, a.column + 1, a.msg });
                            std.process.exit(1);
                        }
                    }

                    for (handled_errors) |h, i| {
                        if (!h) {
                            const er = e[i];
                            std.debug.warn("{}\nDid not receive error:\n================\n{}:{}: {}\n================\nTest failed.\n", .{ case.name, er.line, er.column, er.msg });
                            std.process.exit(1);
                        }
                    }
                },
                .Execution => |expected_stdout| {
                    var exec_result = x: {
                        var exec_node = update_node.start("execute", null);
                        exec_node.activate();
                        defer exec_node.end();

                        try module.makeBinFileExecutable();

                        const exe_path = try std.fmt.allocPrint(allocator, "." ++ std.fs.path.sep_str ++ "{}", .{bin_name});
                        defer allocator.free(exe_path);

                        break :x try std.ChildProcess.exec(.{
                            .allocator = allocator,
                            .argv = &[_][]const u8{exe_path},
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
                    if (!std.mem.eql(u8, expected_stdout, exec_result.stdout)) {
                        std.debug.panic(
                            "update index {}, mismatched stdout\n====Expected (len={}):====\n{}\n====Actual (len={}):====\n{}\n========\n",
                            .{ update_index, expected_stdout.len, expected_stdout, exec_result.stdout.len, exec_result.stdout },
                        );
                    }
                },
            }
        }
    }
};
