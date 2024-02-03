//! This is the implementation of the test harness.
//! For the actual test cases, see test/compare_output.zig.

b: *std.Build,
step: *std.Build.Step,
test_index: usize,
test_filter: ?[]const u8,
optimize_modes: []const OptimizeMode,

const Special = enum {
    None,
    Asm,
    RuntimeSafety,
};

const TestCase = struct {
    name: []const u8,
    sources: ArrayList(SourceFile),
    expected_output: []const u8,
    link_libc: bool,
    special: Special,
    cli_args: []const []const u8,

    const SourceFile = struct {
        filename: []const u8,
        source: []const u8,
    };

    pub fn addSourceFile(self: *TestCase, filename: []const u8, source: []const u8) void {
        self.sources.append(SourceFile{
            .filename = filename,
            .source = source,
        }) catch @panic("OOM");
    }

    pub fn setCommandLineArgs(self: *TestCase, args: []const []const u8) void {
        self.cli_args = args;
    }
};

pub fn createExtra(self: *CompareOutput, name: []const u8, source: []const u8, expected_output: []const u8, special: Special) TestCase {
    var tc = TestCase{
        .name = name,
        .sources = ArrayList(TestCase.SourceFile).init(self.b.allocator),
        .expected_output = expected_output,
        .link_libc = false,
        .special = special,
        .cli_args = &[_][]const u8{},
    };
    const root_src_name = if (special == Special.Asm) "source.s" else "source.zig";
    tc.addSourceFile(root_src_name, source);
    return tc;
}

pub fn create(self: *CompareOutput, name: []const u8, source: []const u8, expected_output: []const u8) TestCase {
    return createExtra(self, name, source, expected_output, Special.None);
}

pub fn addC(self: *CompareOutput, name: []const u8, source: []const u8, expected_output: []const u8) void {
    var tc = self.create(name, source, expected_output);
    tc.link_libc = true;
    self.addCase(tc);
}

pub fn add(self: *CompareOutput, name: []const u8, source: []const u8, expected_output: []const u8) void {
    const tc = self.create(name, source, expected_output);
    self.addCase(tc);
}

pub fn addAsm(self: *CompareOutput, name: []const u8, source: []const u8, expected_output: []const u8) void {
    const tc = self.createExtra(name, source, expected_output, Special.Asm);
    self.addCase(tc);
}

pub fn addRuntimeSafety(self: *CompareOutput, name: []const u8, source: []const u8) void {
    const tc = self.createExtra(name, source, undefined, Special.RuntimeSafety);
    self.addCase(tc);
}

pub fn addCase(self: *CompareOutput, case: TestCase) void {
    const b = self.b;

    const write_src = b.addWriteFiles();
    for (case.sources.items) |src_file| {
        _ = write_src.add(src_file.filename, src_file.source);
    }

    const case_optimize_modes: []const OptimizeMode = switch (case.special) {
        .None => self.optimize_modes,
        .Asm => &.{.Debug},
        .RuntimeSafety => &.{ .Debug, .ReleaseSafe },
    };

    for (case_optimize_modes) |optimize| {
        const annotated_case_name = b.fmt("run {s} {s} ({s})", .{
            switch (case.special) {
                .None => "compare-output",
                .Asm => "assemble-and-link",
                .RuntimeSafety => "safety",
            },
            case.name,
            @tagName(optimize),
        });

        if (self.test_filter) |filter| {
            if (mem.indexOf(u8, annotated_case_name, filter) == null) continue;
        }

        const case_mod = b.createModule(.{
            .target = b.host,
            .optimize = optimize,
            .root_source_file = switch (case.special) {
                .None, .RuntimeSafety => write_src.files.items[0].getPath(),
                .Asm => null,
            },
            .link_libc = case.link_libc,
        });
        if (case.special == .Asm) {
            case_mod.addAssemblyFile(write_src.files.items[0].getPath());
        }

        const exe = b.addExecutable2(.{
            .name = "test",
            .root_module = case_mod,
        });
        const run = b.addRunArtifact(exe);
        run.setName(annotated_case_name);
        run.addArgs(case.cli_args);
        switch (case.special) {
            .None, .Asm => run.expectStdOutEqual(case.expected_output),
            .RuntimeSafety => run.expectExitCode(126),
        }

        self.step.dependOn(&run.step);
    }
}

const CompareOutput = @This();
const std = @import("std");
const ArrayList = std.ArrayList;
const fmt = std.fmt;
const mem = std.mem;
const fs = std.fs;
const OptimizeMode = std.builtin.OptimizeMode;
