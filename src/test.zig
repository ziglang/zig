const std = @import("std");
const link = @import("link.zig");
const Compilation = @import("Compilation.zig");
const Allocator = std.mem.Allocator;
const zir = @import("zir.zig");
const Package = @import("Package.zig");
const introspect = @import("introspect.zig");
const build_options = @import("build_options");
const enable_qemu: bool = build_options.enable_qemu;
const enable_wine: bool = build_options.enable_wine;
const enable_wasmtime: bool = build_options.enable_wasmtime;
const glibc_multi_install_dir: ?[]const u8 = build_options.glibc_multi_install_dir;
const ThreadPool = @import("ThreadPool.zig");
const CrossTarget = std.zig.CrossTarget;

const c_header = @embedFile("link/cbe.h");

test "self-hosted" {
    var ctx = TestContext.init();
    defer ctx.deinit();

    try @import("stage2_tests").addCases(&ctx);

    try ctx.run();
}

const ErrorMsg = union(enum) {
    src: struct {
        msg: []const u8,
        line: u32,
        column: u32,
    },
    plain: struct {
        msg: []const u8,
    },

    fn init(other: Compilation.AllErrors.Message) ErrorMsg {
        switch (other) {
            .src => |src| return .{
                .src = .{
                    .msg = src.msg,
                    .line = @intCast(u32, src.line),
                    .column = @intCast(u32, src.column),
                },
            },
            .plain => |plain| return .{
                .plain = .{
                    .msg = plain.msg,
                },
            },
        }
    }

    pub fn format(
        self: ErrorMsg,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self) {
            .src => |src| {
                return writer.print(":{d}:{d}: error: {s}", .{
                    src.line + 1,
                    src.column + 1,
                    src.msg,
                });
            },
            .plain => |plain| {
                return writer.print("error: {s}", .{plain.msg});
            },
        }
    }
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
            /// A transformation update transforms the input and tests against
            /// the expected output ZIR.
            Transformation: [:0]const u8,
            /// Check the main binary output file against an expected set of bytes.
            /// This is most useful with, for example, `-ofmt=c`.
            CompareObjectFile: []const u8,
            /// An error update attempts to compile bad code, and ensures that it
            /// fails to compile, and for the expected reasons.
            /// A slice containing the expected errors *in sequential order*.
            Error: []const ErrorMsg,
            /// An execution update compiles and runs the input, testing the
            /// stdout against the expected results
            /// This is a slice containing the expected message.
            Execution: []const u8,
            /// A header update compiles the input with the equivalent of
            /// `-femit-h` and tests the produced header against the
            /// expected result
            Header: []const u8,
        },
    };

    pub const File = struct {
        /// Contents of the importable file. Doesn't yet support incremental updates.
        src: [:0]const u8,
        path: []const u8,
    };

    pub const Extension = enum {
        Zig,
        ZIR,
    };

    /// A `Case` consists of a list of `Update`. The same `Compilation` is used for each
    /// update, so each update's source is treated as a single file being
    /// updated by the test harness and incrementally compiled.
    pub const Case = struct {
        /// The name of the test case. This is shown if a test fails, and
        /// otherwise ignored.
        name: []const u8,
        /// The platform the test targets. For non-native platforms, an emulator
        /// such as QEMU is required for tests to complete.
        target: CrossTarget,
        /// In order to be able to run e.g. Execution updates, this must be set
        /// to Executable.
        output_mode: std.builtin.OutputMode,
        updates: std.ArrayList(Update),
        extension: Extension,
        object_format: ?std.builtin.ObjectFormat = null,
        emit_h: bool = false,

        files: std.ArrayList(File),

        /// Adds a subcase in which the module is updated with `src`, and the
        /// resulting ZIR is validated against `result`.
        pub fn addTransform(self: *Case, src: [:0]const u8, result: [:0]const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .Transformation = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with `src`, and a C
        /// header is generated.
        pub fn addHeader(self: *Case, src: [:0]const u8, result: [:0]const u8) void {
            self.emit_h = true;
            self.updates.append(.{
                .src = src,
                .case = .{ .Header = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with `src`, compiled,
        /// run, and the output is tested against `result`.
        pub fn addCompareOutput(self: *Case, src: [:0]const u8, result: []const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .Execution = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with `src`, compiled,
        /// and the object file data is compared against `result`.
        pub fn addCompareObjectFile(self: *Case, src: [:0]const u8, result: []const u8) void {
            self.updates.append(.{
                .src = src,
                .case = .{ .CompareObjectFile = result },
            }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with `src`, which
        /// should contain invalid input, and ensures that compilation fails
        /// for the expected reasons, given in sequential order in `errors` in
        /// the form `:line:column: error: message`.
        pub fn addError(self: *Case, src: [:0]const u8, errors: []const []const u8) void {
            var array = self.updates.allocator.alloc(ErrorMsg, errors.len) catch unreachable;
            for (errors) |e, i| {
                if (e[0] != ':') {
                    array[i] = .{ .plain = .{ .msg = e } };
                    continue;
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
                    .src = .{
                        .msg = msg,
                        .line = line - 1,
                        .column = column - 1,
                    },
                };
            }
            self.updates.append(.{ .src = src, .case = .{ .Error = array } }) catch unreachable;
        }

        /// Adds a subcase in which the module is updated with `src`, and
        /// asserts that it compiles without issue
        pub fn compiles(self: *Case, src: [:0]const u8) void {
            self.addError(src, &[_][]const u8{});
        }
    };

    pub fn addExe(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        extension: Extension,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .extension = extension,
            .files = std.ArrayList(File).init(ctx.cases.allocator),
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    /// Adds a test case for Zig input, producing an executable
    pub fn exe(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addExe(name, target, .Zig);
    }

    /// Adds a test case for ZIR input, producing an executable
    pub fn exeZIR(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addExe(name, target, .ZIR);
    }

    pub fn exeFromCompiledC(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Exe,
            .extension = .Zig,
            .object_format = .c,
            .files = std.ArrayList(File).init(ctx.cases.allocator),
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn addObj(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        extension: Extension,
    ) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Obj,
            .extension = extension,
            .files = std.ArrayList(File).init(ctx.cases.allocator),
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    /// Adds a test case for Zig input, producing an object file.
    pub fn obj(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addObj(name, target, .Zig);
    }

    /// Adds a test case for ZIR input, producing an object file.
    pub fn objZIR(ctx: *TestContext, name: []const u8, target: CrossTarget) *Case {
        return ctx.addObj(name, target, .ZIR);
    }

    /// Adds a test case for Zig or ZIR input, producing C code.
    pub fn addC(ctx: *TestContext, name: []const u8, target: CrossTarget, ext: Extension) *Case {
        ctx.cases.append(Case{
            .name = name,
            .target = target,
            .updates = std.ArrayList(Update).init(ctx.cases.allocator),
            .output_mode = .Obj,
            .extension = ext,
            .object_format = .c,
            .files = std.ArrayList(File).init(ctx.cases.allocator),
        }) catch unreachable;
        return &ctx.cases.items[ctx.cases.items.len - 1];
    }

    pub fn c(ctx: *TestContext, name: []const u8, target: CrossTarget, src: [:0]const u8, comptime out: [:0]const u8) void {
        ctx.addC(name, target, .Zig).addCompareObjectFile(src, c_header ++ out);
    }

    pub fn h(ctx: *TestContext, name: []const u8, target: CrossTarget, src: [:0]const u8, comptime out: [:0]const u8) void {
        ctx.addC(name, target, .Zig).addHeader(src, c_header ++ out);
    }

    pub fn addCompareOutput(
        ctx: *TestContext,
        name: []const u8,
        extension: Extension,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        ctx.addExe(name, .{}, extension).addCompareOutput(src, expected_stdout);
    }

    /// Adds a test case that compiles the Zig source given in `src`, executes
    /// it, runs it, and tests the output against `expected_stdout`
    pub fn compareOutput(
        ctx: *TestContext,
        name: []const u8,
        src: [:0]const u8,
        expected_stdout: []const u8,
    ) void {
        return ctx.addCompareOutput(name, .Zig, src, expected_stdout);
    }

    /// Adds a test case that compiles the ZIR source given in `src`, executes
    /// it, runs it, and tests the output against `expected_stdout`
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
        target: CrossTarget,
        extension: Extension,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addObj(name, target, extension).addTransform(src, result);
    }

    /// Adds a test case that compiles the Zig given in `src` to ZIR and tests
    /// the ZIR against `result`
    pub fn transform(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addTransform(name, target, .Zig, src, result);
    }

    /// Adds a test case that cleans up the ZIR source given in `src`, and
    /// tests the resulting ZIR against `result`
    pub fn transformZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        result: [:0]const u8,
    ) void {
        ctx.addTransform(name, target, .ZIR, src, result);
    }

    pub fn addError(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        extension: Extension,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addObj(name, target, extension).addError(src, expected_errors);
    }

    /// Adds a test case that ensures that the Zig given in `src` fails to
    /// compile for the expected reasons, given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`.
    pub fn compileError(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, .Zig, src, expected_errors);
    }

    /// Adds a test case that ensures that the ZIR given in `src` fails to
    /// compile for the expected reasons, given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`.
    pub fn compileErrorZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
    ) void {
        ctx.addError(name, target, .ZIR, src, expected_errors);
    }

    pub fn addCompiles(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        extension: Extension,
        src: [:0]const u8,
    ) void {
        ctx.addObj(name, target, extension).compiles(src);
    }

    /// Adds a test case that asserts that the Zig given in `src` compiles
    /// without any errors.
    pub fn compiles(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, .Zig, src);
    }

    /// Adds a test case that asserts that the ZIR given in `src` compiles
    /// without any errors.
    pub fn compilesZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
    ) void {
        ctx.addCompiles(name, target, .ZIR, src);
    }

    /// Adds a test case that first ensures that the Zig given in `src` fails
    /// to compile for the reasons given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`, then
    /// asserts that fixing the source (updating with `fixed_src`) isn't broken
    /// by incremental compilation.
    pub fn incrementalFailure(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target, .Zig);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    /// Adds a test case that first ensures that the ZIR given in `src` fails
    /// to compile for the reasons given in sequential order in
    /// `expected_errors` in the form `:line:column: error: message`, then
    /// asserts that fixing the source (updating with `fixed_src`) isn't broken
    /// by incremental compilation.
    pub fn incrementalFailureZIR(
        ctx: *TestContext,
        name: []const u8,
        target: CrossTarget,
        src: [:0]const u8,
        expected_errors: []const []const u8,
        fixed_src: [:0]const u8,
    ) void {
        var case = ctx.addObj(name, target, .ZIR);
        case.addError(src, expected_errors);
        case.compiles(fixed_src);
    }

    fn init() TestContext {
        const allocator = std.heap.page_allocator;
        return .{ .cases = std.ArrayList(Case).init(allocator) };
    }

    fn deinit(self: *TestContext) void {
        for (self.cases.items) |case| {
            for (case.updates.items) |u| {
                if (u.case == .Error) {
                    case.updates.allocator.free(u.case.Error);
                }
            }
            case.updates.deinit();
        }
        self.cases.deinit();
        self.* = undefined;
    }

    fn run(self: *TestContext) !void {
        var progress = std.Progress{};
        const root_node = try progress.start("tests", self.cases.items.len);
        defer root_node.end();

        var zig_lib_directory = try introspect.findZigLibDir(std.testing.allocator);
        defer zig_lib_directory.handle.close();
        defer std.testing.allocator.free(zig_lib_directory.path.?);

        var thread_pool: ThreadPool = undefined;
        try thread_pool.init(std.testing.allocator);
        defer thread_pool.deinit();

        for (self.cases.items) |case| {
            if (build_options.skip_non_native and case.target.getCpuArch() != std.Target.current.cpu.arch)
                continue;

            var prg_node = root_node.start(case.name, case.updates.items.len);
            prg_node.activate();
            defer prg_node.end();

            // So that we can see which test case failed when the leak checker goes off,
            // or there's an internal error
            progress.initial_delay_ns = 0;
            progress.refresh_rate_ns = 0;

            try self.runOneCase(
                std.testing.allocator,
                &prg_node,
                case,
                zig_lib_directory,
                &thread_pool,
            );
        }
    }

    fn runOneCase(
        self: *TestContext,
        allocator: *Allocator,
        root_node: *std.Progress.Node,
        case: Case,
        zig_lib_directory: Compilation.Directory,
        thread_pool: *ThreadPool,
    ) !void {
        const target_info = try std.zig.system.NativeTargetInfo.detect(allocator, case.target);
        const target = target_info.target;

        var arena_allocator = std.heap.ArenaAllocator.init(allocator);
        defer arena_allocator.deinit();
        const arena = &arena_allocator.allocator;

        var tmp = std.testing.tmpDir(.{});
        defer tmp.cleanup();

        var cache_dir = try tmp.dir.makeOpenPath("zig-cache", .{});
        defer cache_dir.close();
        const tmp_dir_path = try std.fs.path.join(arena, &[_][]const u8{ ".", "zig-cache", "tmp", &tmp.sub_path });
        const zig_cache_directory: Compilation.Directory = .{
            .handle = cache_dir,
            .path = try std.fs.path.join(arena, &[_][]const u8{ tmp_dir_path, "zig-cache" }),
        };

        const tmp_src_path = switch (case.extension) {
            .Zig => "test_case.zig",
            .ZIR => "test_case.zir",
        };

        var root_pkg: Package = .{
            .root_src_directory = .{ .path = tmp_dir_path, .handle = tmp.dir },
            .root_src_path = tmp_src_path,
        };

        const bin_name = try std.zig.binNameAlloc(arena, .{
            .root_name = "test_case",
            .target = target,
            .output_mode = case.output_mode,
            .object_format = case.object_format,
        });

        const emit_directory: Compilation.Directory = .{
            .path = tmp_dir_path,
            .handle = tmp.dir,
        };
        const emit_bin: Compilation.EmitLoc = .{
            .directory = emit_directory,
            .basename = bin_name,
        };
        const emit_h: ?Compilation.EmitLoc = if (case.emit_h)
            .{
                .directory = emit_directory,
                .basename = "test_case.h",
            }
        else
            null;
        const comp = try Compilation.create(allocator, .{
            .local_cache_directory = zig_cache_directory,
            .global_cache_directory = zig_cache_directory,
            .zig_lib_directory = zig_lib_directory,
            .thread_pool = thread_pool,
            .root_name = "test_case",
            .target = target,
            // TODO: support tests for object file building, and library builds
            // and linking. This will require a rework to support multi-file
            // tests.
            .output_mode = case.output_mode,
            // TODO: support testing optimizations
            .optimize_mode = .Debug,
            .emit_bin = emit_bin,
            .emit_h = emit_h,
            .root_pkg = &root_pkg,
            .keep_source_files_loaded = true,
            .object_format = case.object_format,
            .is_native_os = case.target.isNativeOs(),
            .is_native_abi = case.target.isNativeAbi(),
        });
        defer comp.destroy();

        for (case.files.items) |file| {
            try tmp.dir.writeFile(file.path, file.src);
        }

        for (case.updates.items) |update, update_index| {
            var update_node = root_node.start("update", 3);
            update_node.activate();
            defer update_node.end();

            var sync_node = update_node.start("write", 0);
            sync_node.activate();
            try tmp.dir.writeFile(tmp_src_path, update.src);
            sync_node.end();

            var module_node = update_node.start("parse/analysis/codegen", 0);
            module_node.activate();
            try comp.makeBinFileWritable();
            try comp.update();
            module_node.end();

            if (update.case != .Error) {
                var all_errors = try comp.getAllErrorsAlloc();
                defer all_errors.deinit(allocator);
                if (all_errors.list.len != 0) {
                    std.debug.print("\nErrors occurred updating the compilation:\n================\n", .{});
                    for (all_errors.list) |err_msg| {
                        switch (err_msg) {
                            .src => |src| {
                                std.debug.print(":{d}:{d}: error: {s}\n================\n", .{
                                    src.line + 1, src.column + 1, src.msg,
                                });
                            },
                            .plain => |plain| {
                                std.debug.print("error: {s}\n================\n", .{plain.msg});
                            },
                        }
                    }
                    if (comp.bin_file.cast(link.File.C)) |c_file| {
                        std.debug.print("Generated C: \n===============\n{}\n\n===========\n\n", .{
                            c_file.main.items,
                        });
                    }
                    std.debug.print("Test failed.\n", .{});
                    std.process.exit(1);
                }
            }

            switch (update.case) {
                .Header => |expected_output| {
                    var file = try tmp.dir.openFile("test_case.h", .{ .read = true });
                    defer file.close();
                    const out = try file.reader().readAllAlloc(arena, 5 * 1024 * 1024);

                    std.testing.expectEqualStrings(expected_output, out);
                },
                .CompareObjectFile => |expected_output| {
                    var file = try tmp.dir.openFile(bin_name, .{ .read = true });
                    defer file.close();
                    const out = try file.reader().readAllAlloc(arena, 5 * 1024 * 1024);

                    std.testing.expectEqualStrings(expected_output, out);
                },
                .Transformation => |expected_output| {
                    update_node.setEstimatedTotalItems(5);
                    var emit_node = update_node.start("emit", 0);
                    emit_node.activate();
                    var new_zir_module = try zir.emit(allocator, comp.bin_file.options.module.?);
                    defer new_zir_module.deinit(allocator);
                    emit_node.end();

                    var write_node = update_node.start("write", 0);
                    write_node.activate();
                    var out_zir = std.ArrayList(u8).init(allocator);
                    defer out_zir.deinit();
                    try new_zir_module.writeToStream(allocator, out_zir.outStream());
                    write_node.end();

                    var test_node = update_node.start("assert", 0);
                    test_node.activate();
                    defer test_node.end();

                    std.testing.expectEqualStrings(expected_output, out_zir.items);
                },
                .Error => |e| {
                    var test_node = update_node.start("assert", 0);
                    test_node.activate();
                    defer test_node.end();
                    var handled_errors = try arena.alloc(bool, e.len);
                    for (handled_errors) |*handled| {
                        handled.* = false;
                    }
                    var all_errors = try comp.getAllErrorsAlloc();
                    defer all_errors.deinit(allocator);
                    for (all_errors.list) |a| {
                        for (e) |ex, i| {
                            const a_tag: @TagType(@TypeOf(a)) = a;
                            const ex_tag: @TagType(@TypeOf(ex)) = ex;
                            switch (a) {
                                .src => |src| {
                                    if (ex_tag != .src) continue;

                                    if (src.line == ex.src.line and
                                        src.column == ex.src.column and
                                        std.mem.eql(u8, ex.src.msg, src.msg))
                                    {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                                .plain => |plain| {
                                    if (ex_tag != .plain) continue;

                                    if (std.mem.eql(u8, ex.plain.msg, plain.msg)) {
                                        handled_errors[i] = true;
                                        break;
                                    }
                                },
                            }
                        } else {
                            std.debug.print(
                                "{s}\nUnexpected error:\n================\n{}\n================\nTest failed.\n",
                                .{ case.name, ErrorMsg.init(a) },
                            );
                            std.process.exit(1);
                        }
                    }

                    for (handled_errors) |handled, i| {
                        if (!handled) {
                            const er = e[i];
                            std.debug.print(
                                "{s}\nDid not receive error:\n================\n{}\n================\nTest failed.\n",
                                .{ case.name, er },
                            );
                            std.process.exit(1);
                        }
                    }
                },
                .Execution => |expected_stdout| {
                    update_node.setEstimatedTotalItems(4);

                    var argv = std.ArrayList([]const u8).init(allocator);
                    defer argv.deinit();

                    var exec_result = x: {
                        var exec_node = update_node.start("execute", 0);
                        exec_node.activate();
                        defer exec_node.end();

                        // We use relative to cwd here because we pass a new cwd to the
                        // child process.
                        const exe_path = try std.fmt.allocPrint(arena, "." ++ std.fs.path.sep_str ++ "{s}", .{bin_name});
                        if (case.object_format != null and case.object_format.? == .c) {
                            try argv.appendSlice(&[_][]const u8{
                                std.testing.zig_exe_path, "run", exe_path, "-lc",
                            });
                        } else switch (case.target.getExternalExecutor()) {
                            .native => try argv.append(exe_path),
                            .unavailable => {
                                try self.runInterpreterIfAvailable(allocator, &exec_node, case, tmp.dir, bin_name);
                                return; // Pass test.
                            },

                            .qemu => |qemu_bin_name| if (enable_qemu) {
                                // TODO Ability for test cases to specify whether to link libc.
                                const need_cross_glibc = false; // target.isGnuLibC() and self.is_linking_libc;
                                const glibc_dir_arg = if (need_cross_glibc)
                                    glibc_multi_install_dir orelse return // glibc dir not available; pass test
                                else
                                    null;
                                try argv.append(qemu_bin_name);
                                if (glibc_dir_arg) |dir| {
                                    const linux_triple = try target.linuxTriple(arena);
                                    const full_dir = try std.fs.path.join(arena, &[_][]const u8{
                                        dir,
                                        linux_triple,
                                    });

                                    try argv.append("-L");
                                    try argv.append(full_dir);
                                }
                                try argv.append(exe_path);
                            } else {
                                return; // QEMU not available; pass test.
                            },

                            .wine => |wine_bin_name| if (enable_wine) {
                                try argv.append(wine_bin_name);
                                try argv.append(exe_path);
                            } else {
                                return; // Wine not available; pass test.
                            },

                            .wasmtime => |wasmtime_bin_name| if (enable_wasmtime) {
                                try argv.append(wasmtime_bin_name);
                                try argv.append("--dir=.");
                                try argv.append(exe_path);
                            } else {
                                return; // wasmtime not available; pass test.
                            },
                        }

                        try comp.makeBinFileExecutable();

                        break :x std.ChildProcess.exec(.{
                            .allocator = allocator,
                            .argv = argv.items,
                            .cwd_dir = tmp.dir,
                            .cwd = tmp_dir_path,
                        }) catch |err| {
                            std.debug.print("\nThe following command failed with {s}:\n", .{
                                @errorName(err),
                            });
                            dumpArgs(argv.items);
                            return error.ZigTestFailed;
                        };
                    };
                    var test_node = update_node.start("test", 0);
                    test_node.activate();
                    defer test_node.end();
                    defer allocator.free(exec_result.stdout);
                    defer allocator.free(exec_result.stderr);
                    switch (exec_result.term) {
                        .Exited => |code| {
                            if (code != 0) {
                                std.debug.print("\n{s}\n{s}: execution exited with code {d}:\n", .{
                                    exec_result.stderr, case.name, code,
                                });
                                dumpArgs(argv.items);
                                return error.ZigTestFailed;
                            }
                        },
                        else => {
                            std.debug.print("\n{s}\n{s}: execution crashed:\n", .{
                                exec_result.stderr, case.name,
                            });
                            dumpArgs(argv.items);
                            return error.ZigTestFailed;
                        },
                    }
                    std.testing.expectEqualStrings(expected_stdout, exec_result.stdout);
                },
            }
        }
    }

    fn runInterpreterIfAvailable(
        self: *TestContext,
        gpa: *Allocator,
        node: *std.Progress.Node,
        case: Case,
        tmp_dir: std.fs.Dir,
        bin_name: []const u8,
    ) !void {
        const arch = case.target.cpu_arch orelse return;
        switch (arch) {
            .spu_2 => return self.runSpu2Interpreter(gpa, node, case, tmp_dir, bin_name),
            else => return,
        }
    }

    fn runSpu2Interpreter(
        self: *TestContext,
        gpa: *Allocator,
        update_node: *std.Progress.Node,
        case: Case,
        tmp_dir: std.fs.Dir,
        bin_name: []const u8,
    ) !void {
        const spu = @import("codegen/spu-mk2.zig");
        if (case.target.os_tag) |os| {
            if (os != .freestanding) {
                std.debug.panic("Only freestanding makes sense for SPU-II tests!", .{});
            }
        } else {
            std.debug.panic("SPU_2 has no native OS, check the test!", .{});
        }

        var interpreter = spu.Interpreter(struct {
            RAM: [0x10000]u8 = undefined,

            pub fn read8(bus: @This(), addr: u16) u8 {
                return bus.RAM[addr];
            }
            pub fn read16(bus: @This(), addr: u16) u16 {
                return std.mem.readIntLittle(u16, bus.RAM[addr..][0..2]);
            }

            pub fn write8(bus: *@This(), addr: u16, val: u8) void {
                bus.RAM[addr] = val;
            }

            pub fn write16(bus: *@This(), addr: u16, val: u16) void {
                std.mem.writeIntLittle(u16, bus.RAM[addr..][0..2], val);
            }
        }){
            .bus = .{},
        };

        {
            var load_node = update_node.start("load", 0);
            load_node.activate();
            defer load_node.end();

            var file = try tmp_dir.openFile(bin_name, .{ .read = true });
            defer file.close();

            const header = try std.elf.readHeader(file);
            var iterator = header.program_header_iterator(file);

            var none_loaded = true;

            while (try iterator.next()) |phdr| {
                if (phdr.p_type != std.elf.PT_LOAD) {
                    std.debug.print("Encountered unexpected ELF program header: type {}\n", .{phdr.p_type});
                    std.process.exit(1);
                }
                if (phdr.p_paddr != phdr.p_vaddr) {
                    std.debug.print("Physical address does not match virtual address in ELF header!\n", .{});
                    std.process.exit(1);
                }
                if (phdr.p_filesz != phdr.p_memsz) {
                    std.debug.print("Physical size does not match virtual size in ELF header!\n", .{});
                    std.process.exit(1);
                }
                if ((try file.pread(interpreter.bus.RAM[phdr.p_paddr .. phdr.p_paddr + phdr.p_filesz], phdr.p_offset)) != phdr.p_filesz) {
                    std.debug.print("Read less than expected from ELF file!", .{});
                    std.process.exit(1);
                }
                std.log.scoped(.spu2_test).debug("Loaded 0x{x} bytes to 0x{x:0<4}\n", .{ phdr.p_filesz, phdr.p_paddr });
                none_loaded = false;
            }
            if (none_loaded) {
                std.debug.print("No data found in ELF file!\n", .{});
                std.process.exit(1);
            }
        }

        var exec_node = update_node.start("execute", 0);
        exec_node.activate();
        defer exec_node.end();

        var blocks: u16 = 1000;
        const block_size = 1000;
        while (!interpreter.undefined0) {
            const pre_ip = interpreter.ip;
            if (blocks > 0) {
                blocks -= 1;
                try interpreter.ExecuteBlock(block_size);
                if (pre_ip == interpreter.ip) {
                    std.debug.print("Infinite loop detected in SPU II test!\n", .{});
                    std.process.exit(1);
                }
            }
        }
    }
};

fn dumpArgs(argv: []const []const u8) void {
    for (argv) |arg| {
        std.debug.print("{s} ", .{arg});
    }
    std.debug.print("\n", .{});
}
