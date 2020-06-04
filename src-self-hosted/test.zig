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

const ErrorMsg = struct {
    msg: []const u8,
    line: u32,
    column: u32,
};

pub const TestContext = struct {
    // TODO: remove these. They are deprecated.
    zir_cmp_output_cases: std.ArrayList(ZIRCompareOutputCase),
    // TODO: remove
    zir_transform_cases: std.ArrayList(ZIRTransformCase),
    // TODO: remove
    zir_error_cases: std.ArrayList(ZIRErrorCase),

    /// TODO: find a way to treat cases as individual tests as far as
    /// `zig test` is concerned. If we have 100 tests, they should *not* be
    /// considered as *one*. "ZIR" isn't really a *test*, it's a *category* of
    /// tests.
    zir_cases: std.ArrayList(ZIRCase),

    // TODO: remove
    pub const ZIRCompareOutputCase = struct {
        name: []const u8,
        src_list: []const []const u8,
        expected_stdout_list: []const []const u8,
    };

    // TODO: remove
    pub const ZIRTransformCase = struct {
        name: []const u8,
        cross_target: std.zig.CrossTarget,
        updates: std.ArrayList(Update),

        pub const Update = struct {
            expected: Expected,
            src: [:0]const u8,
        };

        pub const Expected = union(enum) {
            zir: []const u8,
            errors: []const []const u8,
        };

        pub fn addZIR(case: *ZIRTransformCase, src: [:0]const u8, zir_text: []const u8) void {
            case.updates.append(.{
                .src = src,
                .expected = .{ .zir = zir_text },
            }) catch unreachable;
        }

        pub fn addError(case: *ZIRTransformCase, src: [:0]const u8, errors: []const []const u8) void {
            case.updates.append(.{
                .src = src,
                .expected = .{ .errors = errors },
            }) catch unreachable;
        }
    };

    // TODO: remove
    pub const ZIRErrorCase = struct {
        name: []const u8,
        src: [:0]const u8,
        expected_errors: []const ErrorMsg,
        cross_target: std.zig.CrossTarget,
    };

    pub const ZIRUpdateType = enum {
        /// A transformation stage transforms the input ZIR and tests against
        /// the expected output
        Transformation,
        /// An error stage attempts to compile bad code, and ensures that it
        /// fails to compile, and for the expected reasons
        Error,
        /// An execution stage compiles and runs the input ZIR, feeding in
        /// provided input and ensuring that the outputs match what is expected
        Execution,
        /// A compilation stage checks that the ZIR compiles without any issues
        Compiles,
    };

    pub const ZIRUpdate = struct {
        /// The input to the current stage. We simulate an incremental update
        /// with the file's contents changed to this value each stage.
        ///
        /// This value can change entirely between stages, which would be akin
        /// to deleting the source file and creating a new one from scratch; or
        /// you can keep it mostly consistent, with small changes, testing the
        /// effects of the incremental compilation.
        src: [:0]const u8,
        case: union(ZIRUpdateType) {
            /// The expected output ZIR
            Transformation: []const u8,
            /// A slice containing the expected errors *in sequential order*.
            Error: []const ErrorMsg,

            /// Input to feed to the program, and expected outputs.
            ///
            /// If stdout, stderr, and exit_code are all null, addZIRCase will
            /// discard the test. To test for successful compilation, use a
            /// dedicated Compile stage instead.
            Execution: struct {
                stdin: ?[]const u8,
                stdout: ?[]const u8,
                stderr: ?[]const u8,
                exit_code: ?u8,
            },
            /// A Compiles test checks only that compilation of the given ZIR
            /// succeeds. To test outputs, use an Execution test. It is good to
            /// use a Compiles test before an Execution, as the overhead should
            /// be low (due to incremental compilation) and TODO: provide a way
            /// to check changed / new / etc decls in testing mode
            /// (usingnamespace a debug info struct with a comptime flag?)
            Compiles: void,
        },
    };

    /// A ZIRCase consists of a set of *stages*. A stage can transform ZIR,
    /// compile it, ensure that compilation fails, and more. The same Module is
    /// used for each stage, so each stage's source is treated as a single file
    /// being updated by the test harness and incrementally compiled.
    pub const ZIRCase = struct {
        name: []const u8,
        /// The platform the ZIR targets. For non-native platforms, an emulator
        /// such as QEMU is required for tests to complete.
        ///
        target: std.zig.CrossTarget,
        stages: []ZIRUpdate,
    };

    pub fn addZIRCase(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        stages: []ZIRUpdate,
    ) !void {
        const case = .{
            .name = name,
            .target = target,
            .stages = stages,
        };
        try ctx.cases.append(case);
    }

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
        const case = ctx.zir_transform_cases.addOne() catch unreachable;
        case.* = .{
            .name = name,
            .cross_target = cross_target,
            .updates = std.ArrayList(ZIRTransformCase.Update).init(std.heap.page_allocator),
        };
        case.updates.append(.{
            .src = src,
            .expected = .{ .zir = expected_zir },
        }) catch unreachable;
    }

    pub fn addZIRError(
        ctx: *TestContext,
        name: []const u8,
        cross_target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        var array = std.ArrayList(ErrorMsg).init(ctx.zir_error_cases.allocator);
        for (expected_errors) |e| {
            var cur = e;
            const err = cur[0..7];
            if (!std.mem.eql(u8, err, "error: ")) {
                std.debug.panic("Only error messages are currently supported, received {}\n", .{e});
            }
            cur = cur[7..];
            var line_index = std.mem.indexOf(u8, cur, ":");
            if (line_index == null) {
                std.debug.panic("Invalid test: error must be specified as 'error: line:column: msg', found '{}'", .{e});
            }
            const line = std.fmt.parseInt(u32, cur[0..line_index.?], 10) catch @panic("Unable to parse line number");
            cur = cur[line_index.? + 1 ..];
            const column_index = std.mem.indexOf(u8, cur, ":");
            if (column_index == null) {
                std.debug.panic("Invalid test: error must be specified as 'error: line:column: msg', found '{}'", .{e});
            }
            const column = std.fmt.parseInt(u32, cur[0..column_index.?], 10) catch @panic("Unable to parse column number");
            std.debug.assert(cur[column_index.? + 1] == ' ');
            const msg = cur[column_index.? + 2 ..];

            if (line == 0 or column == 0) {
                @panic("Invalid test: error line and column must be specified starting at one!");
            }

            array.append(.{
                .msg = msg,
                .line = line - 1,
                .column = column - 1,
            }) catch unreachable;
        }
        ctx.zir_error_cases.append(.{
            .name = name,
            .src = src,
            .expected_errors = array.toOwnedSlice(),
            .cross_target = cross_target,
        }) catch unreachable;
    }

    fn init(self: *TestContext) !void {
        const allocator = std.heap.page_allocator;
        self.* = .{
            .zir_cmp_output_cases = std.ArrayList(ZIRCompareOutputCase).init(allocator),
            .zir_transform_cases = std.ArrayList(ZIRTransformCase).init(allocator),
            .zir_error_cases = std.ArrayList(ZIRErrorCase).init(allocator),
            .zir_cases = std.ArrayList(ZIRCase).init(allocator),
        };
    }

    fn deinit(self: *TestContext) void {
        self.zir_cmp_output_cases.deinit();
        self.zir_transform_cases.deinit();
        for (self.zir_error_cases.items) |e| {
            self.zir_error_cases.allocator.free(e.expected_errors);
        }
        self.zir_error_cases.deinit();
        self.zir_cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("zir", self.zir_cmp_output_cases.items.len +
            self.zir_transform_cases.items.len);
        defer root_node.end();

        const native_info = try std.zig.system.NativeTargetInfo.detect(std.heap.page_allocator, .{});

        for (self.zir_cases.items) |case| {
            std.testing.base_allocator_instance.reset();
            const info = try std.zig.system.NativeTargetInfo.detect(std.testing.allocator, case.target);
            try self.runOneZIRCase(std.testing.allocator, root_node, case, info.target);
            try std.testing.allocator_instance.validate();
        }

        // TODO: wipe the rest of this function
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
        for (self.zir_error_cases.items) |case| {
            std.testing.base_allocator_instance.reset();
            const info = try std.zig.system.NativeTargetInfo.detect(std.testing.allocator, case.cross_target);
            try self.runOneZIRErrorCase(std.testing.allocator, root_node, case, info.target);
            try std.testing.allocator_instance.validate();
        }
    }

    fn runOneZIRCase(self: *TestContext, allocator: *Allocator, root_node: *std.Progress.Node, case: ZIRCase, target: std.Target) !void {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const tmp_src_path = "test_case.zir";
        const root_pkg = try Package.create(allocator, tmp.dir, ".", tmp_src_path);
        defer root_pkg.destroy();

        var prg_node = root_node.start(case.name, case.stages.len);
        prg_node.activate();
        defer prg_node.end();

        var module = try Module.init(allocator, .{
            .target = target,
            // This is an Executable, as opposed to e.g. a *library*. This does
            // not mean no ZIR is generated.
            //
            // TODO: support tests for object file building, and library builds
            // and linking. This will require a rework to support multi-file
            // tests.
            .output_mode = .Exe,
            // TODO: support testing optimizations
            .optimize_mode = .Debug,
            .bin_file_dir = tmp.dir,
            .bin_file_path = "test_case",
            .root_pkg = root_pkg,
        });
        defer module.deinit();

        for (case.stages) |s| {
            // TODO: remove before committing. This is for ZLS ;)
            const stage: ZIRUpdate = s;

            var stage_node = prg_node.start("update", 4);
            stage_node.activate();
            defer stage_node.end();

            var sync_node = stage_node.start("write", null);
            sync_node.activate();
            try tmp.dir.writeFile(tmp_src_path, stage.src);
            sync_node.end();

            var module_node = stage_node.start("parse/analysis/codegen", null);
            module_node.activate();
            try module.update();
            module_node.end();

            switch (stage.case) {
                .Transformation => |expected_output| {
                    var emit_node = stage_node.start("emit", null);
                    emit_node.activate();
                    var new_zir_module = try zir.emit(allocator, module);
                    defer new_zir_module.deinit(allocator);
                    emit_node.end();

                    var write_node = stage_node.start("write", null);
                    write_node.activate();
                    var out_zir = std.ArrayList(u8).init(allocator);
                    defer out_zir.deinit();
                    try new_zir_module.writeToStream(allocator, out_zir.outStream());
                    write_node.end();

                    std.testing.expectEqualSlices(u8, expected_output, out_zir.items);
                },
                else => return error.unimplemented,
            }
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

        var update_node = root_node.start(case.name, case.updates.items.len);
        update_node.activate();
        defer update_node.end();

        const tmp_src_path = "test-case.zir";
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

        for (case.updates.items) |update| {
            var prg_node = update_node.start("", 3);
            prg_node.activate();
            defer prg_node.end();

            try tmp.dir.writeFile(tmp_src_path, update.src);

            var module_node = prg_node.start("parse/analysis/codegen", null);
            module_node.activate();
            try module.update();
            module_node.end();

            switch (update.expected) {
                .zir => |expected_zir| {
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

                    std.testing.expectEqualSlices(u8, expected_zir, out_zir.items);
                },
                .errors => |expected_errors| {
                    var all_errors = try module.getAllErrorsAlloc();
                    defer all_errors.deinit(module.allocator);
                    for (expected_errors) |expected_error| {
                        for (all_errors.list) |full_err_msg| {
                            const text = try std.fmt.allocPrint(allocator, ":{}:{}: error: {}", .{
                                full_err_msg.line + 1,
                                full_err_msg.column + 1,
                                full_err_msg.msg,
                            });
                            defer allocator.free(text);
                            if (std.mem.eql(u8, text, expected_error)) {
                                break;
                            }
                        } else {
                            std.debug.warn(
                                "{}\nExpected this error:\n================\n{}\n================\nBut found these errors:\n================\n",
                                .{ case.name, expected_error },
                            );
                            for (all_errors.list) |full_err_msg| {
                                std.debug.warn(":{}:{}: error: {}\n", .{
                                    full_err_msg.line + 1,
                                    full_err_msg.column + 1,
                                    full_err_msg.msg,
                                });
                            }
                            std.debug.warn("================\nTest failed\n", .{});
                            std.process.exit(1);
                        }
                    }
                },
            }
        }
    }

    fn runOneZIRErrorCase(
        self: *TestContext,
        allocator: *Allocator,
        root_node: *std.Progress.Node,
        case: ZIRErrorCase,
        target: std.Target,
    ) !void {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        var prg_node = root_node.start(case.name, 1);
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
        const failed = f: {
            module.update() catch break :f true;
            break :f false;
        };
        module_node.end();
        var err: ?anyerror = null;

        var handled_errors = allocator.alloc(bool, case.expected_errors.len) catch unreachable;
        defer allocator.free(handled_errors);
        for (handled_errors) |*e| {
            e.* = false;
        }

        var all_errors = try module.getAllErrorsAlloc();
        defer all_errors.deinit(allocator);
        for (all_errors.list) |e| {
            var handled = false;
            for (case.expected_errors) |ex, i| {
                if (e.line == ex.line and e.column == ex.column and std.mem.eql(u8, ex.msg, e.msg)) {
                    if (handled_errors[i]) {
                        err = error.ErrorReceivedMultipleTimes;
                        std.debug.warn("Received error multiple times: {}\n", .{e.msg});
                    } else {
                        handled_errors[i] = true;
                        handled = true;
                    }
                    break;
                }
            }
            if (!handled) {
                err = error.ErrorNotExpected;
                std.debug.warn("Received an unexpected error: {}:{}: {}\n", .{ e.line, e.column, e.msg });
            }
        }

        for (handled_errors) |e, i| {
            if (!e) {
                err = error.MissingExpectedError;
                const er = case.expected_errors[i];
                std.debug.warn("Did not receive error: {}:{}: {}\n", .{ er.line, er.column, er.msg });
            }
        }

        if (err) |e| {
            return e;
        }
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
