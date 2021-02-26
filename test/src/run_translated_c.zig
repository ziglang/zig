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
    target: std.zig.CrossTarget,

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

        const annotated_case_name = fmt.allocPrint(self.b.allocator, "run-translated-c {s}", .{case.name}) catch unreachable;
        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) return;
        }

        const write_src = b.addWriteFiles();
        for (case.sources.items) |src_file| {
            write_src.add(src_file.filename, src_file.source);
        }
        const translate_c = b.addTranslateC(.{
            .write_file = .{
                .step = write_src,
                .basename = case.sources.items[0].filename,
            },
        });
        translate_c.step.name = b.fmt("{s} translate-c", .{annotated_case_name});
        const exe = translate_c.addExecutable();
        exe.setTarget(self.target);
        exe.step.name = b.fmt("{s} build-exe", .{annotated_case_name});
        exe.linkLibC();
        const run = exe.run();
        run.step.name = b.fmt("{s} run", .{annotated_case_name});
        if (!case.allow_warnings) {
            run.expectStdErrEqual("");
        }
        run.expectStdOutEqual(case.expected_stdout);

        self.step.dependOn(&run.step);
    }
};
