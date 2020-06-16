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
    // TODO: remove these. They are deprecated.
    zir_cmp_output_cases: std.ArrayList(ZIRCompareOutputCase),

    /// TODO: find a way to treat cases as individual tests (shouldn't show "1 test passed" if there are 200 cases)
    zir_cases: std.ArrayList(ZIRCase),

    // TODO: remove
    pub const ZIRCompareOutputCase = struct {
        name: []const u8,
        src_list: []const []const u8,
        expected_stdout_list: []const []const u8,
    };

    pub const ZIRUpdateType = enum {
        /// A transformation update transforms the input ZIR and tests against
        /// the expected output
        Transformation,
        /// An error update attempts to compile bad code, and ensures that it
        /// fails to compile, and for the expected reasons
        Error,
        /// An execution update compiles and runs the input ZIR, feeding in
        /// provided input and ensuring that the outputs match what is expected
        Execution,
        /// A compilation update checks that the ZIR compiles without any issues
        Compiles,
    };

    pub const ZIRUpdate = struct {
        /// The input to the current update. We simulate an incremental update
        /// with the file's contents changed to this value each update.
        ///
        /// This value can change entirely between updates, which would be akin
        /// to deleting the source file and creating a new one from scratch; or
        /// you can keep it mostly consistent, with small changes, testing the
        /// effects of the incremental compilation.
        src: [:0]const u8,
        case: union(ZIRUpdateType) {
            /// The expected output ZIR
            Transformation: [:0]const u8,
            /// A slice containing the expected errors *in sequential order*.
            Error: []const ErrorMsg,

            /// Input to feed to the program, and expected outputs.
            ///
            /// If stdout, stderr, and exit_code are all null, addZIRCase will
            /// discard the test. To test for successful compilation, use a
            /// dedicated Compile update instead.
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

    /// A ZIRCase consists of a set of *updates*. A update can transform ZIR,
    /// compile it, ensure that compilation fails, and more. The same Module is
    /// used for each update, so each update's source is treated as a single file
    /// being updated by the test harness and incrementally compiled.
    pub const ZIRCase = struct {
        name: []const u8,
        /// The platform the ZIR targets. For non-native platforms, an emulator
        /// such as QEMU is required for tests to complete.
        target: std.zig.CrossTarget,
        updates: std.ArrayList(ZIRUpdate),

        /// Adds a subcase in which the module is updated with new ZIR, and the
        /// resulting ZIR is validated.
        pub fn addTransform(self: *ZIRCase, src: [:0]const u8, result: [:0]const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .Transformation = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with invalid ZIR, and
        /// ensures that compilation fails for the expected reasons.
        ///
        /// Errors must be specified in sequential order.
        pub fn addError(self: *ZIRCase, src: [:0]const u8, errors: []const []const u8) void {
            var array = self.updates.allocator.alloc(ErrorMsg, errors.len) catch unreachable;
            for (errors) |e, i| {
                if (e[0] != ':') {
                    std.debug.panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n", .{});
                }
                var cur = e[1..];
                var line_index = std.mem.indexOf(u8, cur, ":");
                if (line_index == null) {
                    std.debug.panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n", .{});
                }
                const line = std.fmt.parseInt(u32, cur[0..line_index.?], 10) catch @panic("Unable to parse line number");
                cur = cur[line_index.? + 1 ..];
                const column_index = std.mem.indexOf(u8, cur, ":");
                if (column_index == null) {
                    std.debug.panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n", .{});
                }
                const column = std.fmt.parseInt(u32, cur[0..column_index.?], 10) catch @panic("Unable to parse column number");
                cur = cur[column_index.? + 2 ..];
                if (!std.mem.eql(u8, cur[0..7], "error: ")) {
                    std.debug.panic("Invalid test: error must be specified as follows:\n:line:column: error: message\n=========\n", .{});
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
    };

    pub fn addZIRMulti(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
    ) *ZIRCase {
        const case = ZIRCase{
            .name = name,
            .target = target,
            .updates = std.ArrayList(ZIRUpdate).init(ctx.zir_cases.allocator),
        };
        ctx.zir_cases.append(case) catch unreachable;
        return &ctx.zir_cases.items[ctx.zir_cases.items.len - 1];
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
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        var c = ctx.addZIRMulti(name, target);
        c.addTransform(src, result);
    }

    pub fn addZIRError(
        ctx: *TestContext,
        name: []const u8,
        target: std.zig.CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        var c = ctx.addZIRMulti(name, target);
        c.addError(src, expected_errors);
    }

    fn init() TestContext {
        const allocator = std.heap.page_allocator;
        return .{
            .zir_cmp_output_cases = std.ArrayList(ZIRCompareOutputCase).init(allocator),
            .zir_cases = std.ArrayList(ZIRCase).init(allocator),
        };
    }

    fn deinit(self: *TestContext) void {
        self.zir_cmp_output_cases.deinit();
        for (self.zir_cases.items) |c| {
            for (c.updates.items) |u| {
                if (u.case == .Error) {
                    c.updates.allocator.free(u.case.Error);
                }
            }
            c.updates.deinit();
        }
        self.zir_cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("zir", self.zir_cases.items.len);
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
    }

    fn runOneZIRCase(self: *TestContext, allocator: *Allocator, root_node: *std.Progress.Node, case: ZIRCase, target: std.Target) !void {
        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        const tmp_src_path = "test_case.zir";
        const root_pkg = try Package.create(allocator, tmp.dir, ".", tmp_src_path);
        defer root_pkg.destroy();

        var prg_node = root_node.start(case.name, case.updates.items.len);
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
            .output_mode = .Obj,
            // TODO: support testing optimizations
            .optimize_mode = .Debug,
            .bin_file_dir = tmp.dir,
            .bin_file_path = "test_case.o",
            .root_pkg = root_pkg,
        });
        defer module.deinit();

        for (case.updates.items) |update| {
            var update_node = prg_node.start("update", 4);
            update_node.activate();
            defer update_node.end();

            var sync_node = update_node.start("write", null);
            sync_node.activate();
            try tmp.dir.writeFile(tmp_src_path, update.src);
            sync_node.end();

            var module_node = update_node.start("parse/analysis/codegen", null);
            module_node.activate();
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
};
