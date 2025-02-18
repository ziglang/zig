b: *std.Build,
options: Options,
root_step: *std.Build.Step,

pub const Options = struct {
    enable_llvm: bool,
    test_filters: []const []const u8,
    test_target_filters: []const []const u8,
};

const TestCase = struct {
    name: []const u8,
    source: []const u8,
    check: union(enum) {
        matches: []const []const u8,
        exact: []const u8,
    },
    params: Params,

    pub const Params = struct {
        code_model: std.builtin.CodeModel = .default,
        dll_export_fns: ?bool = null,
        dwarf_format: ?std.dwarf.Format = null,
        error_tracing: ?bool = null,
        no_builtin: ?bool = null,
        omit_frame_pointer: ?bool = null,
        // For most cases, we want to test the LLVM IR that we output; we don't want to be in the
        // business of testing LLVM's optimization passes. `Debug` gets us the closest to that as it
        // disables the vast majority of passes in LLVM.
        optimize: std.builtin.OptimizeMode = .Debug,
        pic: ?bool = null,
        pie: ?bool = null,
        red_zone: ?bool = null,
        sanitize_thread: ?bool = null,
        single_threaded: ?bool = null,
        stack_check: ?bool = null,
        stack_protector: ?bool = null,
        strip: ?bool = null,
        target: std.Target.Query = .{},
        unwind_tables: ?std.builtin.UnwindTables = null,
        valgrind: ?bool = null,
    };
};

pub fn addMatches(
    self: *LlvmIr,
    name: []const u8,
    source: []const u8,
    matches: []const []const u8,
    params: TestCase.Params,
) void {
    self.addCase(.{
        .name = name,
        .source = source,
        .check = .{ .matches = matches },
        .params = params,
    });
}

pub fn addExact(
    self: *LlvmIr,
    name: []const u8,
    source: []const u8,
    expected: []const []const u8,
    params: TestCase.Params,
) void {
    self.addCase(.{
        .name = name,
        .source = source,
        .check = .{ .exact = expected },
        .params = params,
    });
}

pub fn addCase(self: *LlvmIr, case: TestCase) void {
    const target = self.b.resolveTargetQuery(case.params.target);
    if (self.options.test_target_filters.len > 0) {
        const triple_txt = target.result.zigTriple(self.b.allocator) catch @panic("OOM");
        for (self.options.test_target_filters) |filter| {
            if (std.mem.indexOf(u8, triple_txt, filter) != null) break;
        } else return;
    }

    const name = std.fmt.allocPrint(self.b.allocator, "check llvm-ir {s}", .{case.name}) catch @panic("OOM");
    if (self.options.test_filters.len > 0) {
        for (self.options.test_filters) |filter| {
            if (std.mem.indexOf(u8, name, filter) != null) break;
        } else return;
    }

    const obj = self.b.addObject(.{
        .name = "test",
        .root_source_file = self.b.addWriteFiles().add("test.zig", case.source),
        .use_llvm = true,

        .code_model = case.params.code_model,
        .error_tracing = case.params.error_tracing,
        .omit_frame_pointer = case.params.omit_frame_pointer,
        .optimize = case.params.optimize,
        .pic = case.params.pic,
        .sanitize_thread = case.params.sanitize_thread,
        .single_threaded = case.params.single_threaded,
        .strip = case.params.strip,
        .target = target,
        .unwind_tables = case.params.unwind_tables,
    });

    obj.dll_export_fns = case.params.dll_export_fns;
    obj.pie = case.params.pie;
    obj.no_builtin = case.params.no_builtin;

    obj.root_module.dwarf_format = case.params.dwarf_format;
    obj.root_module.red_zone = case.params.red_zone;
    obj.root_module.stack_check = case.params.stack_check;
    obj.root_module.stack_protector = case.params.stack_protector;
    obj.root_module.valgrind = case.params.valgrind;

    // This is not very sophisticated at the moment. Eventually, we should move towards something
    // like LLVM's `FileCheck` utility (https://llvm.org/docs/CommandGuide/FileCheck.html), though
    // likely a more simplified version as we probably don't want a full-blown regex engine in the
    // standard library...
    const check = self.b.addCheckFile(obj.getEmittedLlvmIr(), switch (case.check) {
        .matches => |m| .{ .expected_matches = m },
        .exact => |e| .{ .expected_exact = e },
    });
    check.setName(name);

    self.root_step.dependOn(&check.step);
}

const LlvmIr = @This();
const std = @import("std");
