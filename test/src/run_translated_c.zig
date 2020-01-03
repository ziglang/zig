// This is the implementation of the test harness for running translated
// C code. For the actual test cases, see test/run_translated_c.zig.
const std = @import("std");
const build = std.build;
const ArrayList = std.ArrayList;
const fmt = std.fmt;
const mem = std.mem;
const fs = std.fs;
const warn = std.debug.warn;

pub const RunTranslatedCContext = struct {
    b: *build.Builder,
    step: *build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const TestCase = struct {
        name: []const u8,
        sources: ArrayList(SourceFile),
        expected_stdout: []const u8,
        allow_warnings: bool,

        const SourceFile = struct {
            filename: []const u8,
            source: []const u8,
        };

        pub fn addSourceFile(self: *TestCase, filename: []const u8, source: []const u8) void {
            self.sources.append(SourceFile{
                .filename = filename,
                .source = source,
            }) catch unreachable;
        }
    };

    const DoEverythingStep = struct {
        step: build.Step,
        context: *RunTranslatedCContext,
        name: []const u8,
        case: *const TestCase,
        test_index: usize,

        pub fn create(
            context: *RunTranslatedCContext,
            name: []const u8,
            case: *const TestCase,
        ) *DoEverythingStep {
            const allocator = context.b.allocator;
            const ptr = allocator.create(DoEverythingStep) catch unreachable;
            ptr.* = DoEverythingStep{
                .context = context,
                .name = name,
                .case = case,
                .test_index = context.test_index,
                .step = build.Step.init("RunTranslatedC", allocator, make),
            };
            context.test_index += 1;
            return ptr;
        }

        fn make(step: *build.Step) !void {
            const self = @fieldParentPtr(DoEverythingStep, "step", step);
            const b = self.context.b;

            warn("Test {}/{} {}...", .{ self.test_index + 1, self.context.test_index, self.name });
            // translate from c to zig
            const translated_c_code = blk: {
                var zig_args = ArrayList([]const u8).init(b.allocator);
                defer zig_args.deinit();

                const rel_c_filename = try fs.path.join(b.allocator, &[_][]const u8{
                    b.cache_root,
                    self.case.sources.toSliceConst()[0].filename,
                });

                try zig_args.append(b.zig_exe);
                try zig_args.append("translate-c");
                try zig_args.append("-lc");
                try zig_args.append(b.pathFromRoot(rel_c_filename));

                break :blk try b.exec(zig_args.toSliceConst());
            };

            // write stdout to a file

            const translated_c_path = try fs.path.join(b.allocator,
                &[_][]const u8{ b.cache_root, "translated_c.zig" });
            try fs.cwd().writeFile(translated_c_path, translated_c_code);

            // zig run the result
            const run_stdout = blk: {
                var zig_args = ArrayList([]const u8).init(b.allocator);
                defer zig_args.deinit();

                try zig_args.append(b.zig_exe);
                try zig_args.append("-lc");
                try zig_args.append("run");
                try zig_args.append(translated_c_path);

                break :blk try b.exec(zig_args.toSliceConst());
            };
            // compare stdout
            if (!mem.eql(u8, self.case.expected_stdout, run_stdout)) {
                warn(
                    \\
                    \\========= Expected this output: =========
                    \\{}
                    \\========= But found: ====================
                    \\{}
                    \\
                , .{ self.case.expected_stdout, run_stdout });
                return error.TestFailed;
            }

            warn("OK\n", .{});
        }
    };

    pub fn create(
        self: *RunTranslatedCContext,
        allow_warnings: bool,
        filename: []const u8,
        name: []const u8,
        source: []const u8,
        expected_stdout: []const u8,
    ) *TestCase {
        const tc = self.b.allocator.create(TestCase) catch unreachable;
        tc.* = TestCase{
            .name = name,
            .sources = ArrayList(TestCase.SourceFile).init(self.b.allocator),
            .expected_stdout = expected_stdout,
            .allow_warnings = allow_warnings,
        };

        tc.addSourceFile(filename, source);
        return tc;
    }

    pub fn add(
        self: *RunTranslatedCContext,
        name: []const u8,
        source: []const u8,
        expected_stdout: []const u8,
    ) void {
        const tc = self.create(false, "source.c", name, source, expected_stdout);
        self.addCase(tc);
    }

    pub fn addAllowWarnings(
        self: *RunTranslatedCContext,
        name: []const u8,
        source: []const u8,
        expected_stdout: []const u8,
    ) void {
        const tc = self.create(true, "source.c", name, source, expected_stdout);
        self.addCase(tc);
    }

    pub fn addCase(self: *RunTranslatedCContext, case: *const TestCase) void {
        const b = self.b;

        const annotated_case_name = fmt.allocPrint(self.b.allocator, "run-translated-c {}", .{ case.name }) catch unreachable;
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
        }

        const do_everything_step = DoEverythingStep.create(self, annotated_case_name, case);
        self.step.dependOn(&do_everything_step.step);

        for (case.sources.toSliceConst()) |src_file| {
            const expanded_src_path = fs.path.join(
                b.allocator,
                &[_][]const u8{ b.cache_root, src_file.filename },
            ) catch unreachable;
            const write_src = b.addWriteFile(expanded_src_path, src_file.source);
            do_everything_step.step.dependOn(&write_src.step);
        }
    }
};

