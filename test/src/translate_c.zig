// This is the implementation of the test harness.
// For the actual test cases, see test/translate_c.zig.
const std = @import("std");
const build = std.build;
const ArrayList = std.ArrayList;
const fmt = std.fmt;
const mem = std.mem;
const fs = std.fs;
const warn = std.debug.warn;
const CrossTarget = std.zig.CrossTarget;

pub const TranslateCContext = struct {
    b: *build.Builder,
    step: *build.Step,
    test_index: usize,
    test_filter: ?[]const u8,

    const TestCase = struct {
        name: []const u8,
        sources: ArrayList(SourceFile),
        expected_lines: ArrayList([]const u8),
        allow_warnings: bool,
        target: CrossTarget = CrossTarget{},

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

        pub fn addExpectedLine(self: *TestCase, text: []const u8) void {
            self.expected_lines.append(text) catch unreachable;
        }
    };

    pub fn create(
        self: *TranslateCContext,
        allow_warnings: bool,
        filename: []const u8,
        name: []const u8,
        source: []const u8,
        expected_lines: []const []const u8,
    ) *TestCase {
        const tc = self.b.allocator.create(TestCase) catch unreachable;
        tc.* = TestCase{
            .name = name,
            .sources = ArrayList(TestCase.SourceFile).init(self.b.allocator),
            .expected_lines = ArrayList([]const u8).init(self.b.allocator),
            .allow_warnings = allow_warnings,
        };

        tc.addSourceFile(filename, source);
        var arg_i: usize = 0;
        while (arg_i < expected_lines.len) : (arg_i += 1) {
            tc.addExpectedLine(expected_lines[arg_i]);
        }
        return tc;
    }

    pub fn add(
        self: *TranslateCContext,
        name: []const u8,
        source: []const u8,
        expected_lines: []const []const u8,
    ) void {
        const tc = self.create(false, "source.h", name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addWithTarget(
        self: *TranslateCContext,
        name: []const u8,
        target: CrossTarget,
        source: []const u8,
        expected_lines: []const []const u8,
    ) void {
        const tc = self.create(false, "source.h", name, source, expected_lines);
        tc.target = target;
        self.addCase(tc);
    }

    pub fn addAllowWarnings(
        self: *TranslateCContext,
        name: []const u8,
        source: []const u8,
        expected_lines: []const []const u8,
    ) void {
        const tc = self.create(true, "source.h", name, source, expected_lines);
        self.addCase(tc);
    }

    pub fn addCase(self: *TranslateCContext, case: *const TestCase) void {
        const b = self.b;

        const translate_c_cmd = "translate-c";
        const annotated_case_name = fmt.allocPrint(self.b.allocator, "{s} {s}", .{ translate_c_cmd, case.name }) catch unreachable;
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
        translate_c.step.name = annotated_case_name;
        translate_c.setTarget(case.target);

        const check_file = translate_c.addCheckFile(case.expected_lines.items);

        self.step.dependOn(&check_file.step);
    }
};
