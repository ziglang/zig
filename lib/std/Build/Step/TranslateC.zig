const std = @import("std");
const Step = std.Build.Step;
const fs = std.fs;
const mem = std.mem;
const CrossTarget = std.zig.CrossTarget;

const TranslateC = @This();

pub const base_id = .translate_c;

step: Step,
source: std.Build.LazyPath,
include_dirs: std.ArrayList([]const u8),
c_macros: std.ArrayList([]const u8),
out_basename: []const u8,
target: CrossTarget,
optimize: std.builtin.OptimizeMode,
output_file: std.Build.GeneratedFile,

pub const Options = struct {
    source_file: std.Build.LazyPath,
    target: CrossTarget,
    optimize: std.builtin.OptimizeMode,
};

pub fn create(owner: *std.Build, options: Options) *TranslateC {
    const self = owner.allocator.create(TranslateC) catch @panic("OOM");
    const source = options.source_file.dupe(owner);
    self.* = TranslateC{
        .step = Step.init(.{
            .id = .translate_c,
            .name = "translate-c",
            .owner = owner,
            .makeFn = make,
        }),
        .source = source,
        .include_dirs = std.ArrayList([]const u8).init(owner.allocator),
        .c_macros = std.ArrayList([]const u8).init(owner.allocator),
        .out_basename = undefined,
        .target = options.target,
        .optimize = options.optimize,
        .output_file = std.Build.GeneratedFile{ .step = &self.step },
    };
    source.addStepDependencies(&self.step);
    return self;
}

pub const AddExecutableOptions = struct {
    name: ?[]const u8 = null,
    version: ?std.SemanticVersion = null,
    target: ?CrossTarget = null,
    optimize: ?std.builtin.Mode = null,
    linkage: ?Step.Compile.Linkage = null,
};

pub fn getOutput(self: *TranslateC) std.Build.LazyPath {
    return .{ .generated = &self.output_file };
}

/// Creates a step to build an executable from the translated source.
pub fn addExecutable(self: *TranslateC, options: AddExecutableOptions) *Step.Compile {
    return self.step.owner.addExecutable(.{
        .root_source_file = self.getOutput(),
        .name = options.name orelse "translated_c",
        .version = options.version,
        .target = options.target orelse self.target,
        .optimize = options.optimize orelse self.optimize,
        .linkage = options.linkage,
    });
}

/// Creates a module from the translated source and adds it to the package's
/// module set making it available to other packages which depend on this one.
/// `createModule` can be used instead to create a private module.
pub fn addModule(self: *TranslateC, name: []const u8) *std.Build.Module {
    return self.step.owner.addModule(name, .{
        .source_file = self.getOutput(),
    });
}

/// Creates a private module from the translated source to be used by the
/// current package, but not exposed to other packages depending on this one.
/// `addModule` can be used instead to create a public module.
pub fn createModule(self: *TranslateC) *std.Build.Module {
    const b = self.step.owner;
    const module = b.allocator.create(std.Build.Module) catch @panic("OOM");

    module.* = .{
        .builder = b,
        .source_file = self.getOutput(),
        .dependencies = std.StringArrayHashMap(*std.Build.Module).init(b.allocator),
    };
    return module;
}

pub fn addIncludeDir(self: *TranslateC, include_dir: []const u8) void {
    self.include_dirs.append(self.step.owner.dupePath(include_dir)) catch @panic("OOM");
}

pub fn addCheckFile(self: *TranslateC, expected_matches: []const []const u8) *Step.CheckFile {
    return Step.CheckFile.create(
        self.step.owner,
        self.getOutput(),
        .{ .expected_matches = expected_matches },
    );
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(self: *TranslateC, name: []const u8, value: ?[]const u8) void {
    const macro = std.Build.constructCMacro(self.step.owner.allocator, name, value);
    self.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(self: *TranslateC, name_and_value: []const u8) void {
    self.c_macros.append(self.step.owner.dupe(name_and_value)) catch @panic("OOM");
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    const b = step.owner;
    const self = @fieldParentPtr(TranslateC, "step", step);

    var argv_list = std.ArrayList([]const u8).init(b.allocator);
    try argv_list.append(b.zig_exe);
    try argv_list.append("translate-c");
    try argv_list.append("-lc");

    try argv_list.append("--listen=-");

    if (!self.target.isNative()) {
        try argv_list.append("-target");
        try argv_list.append(try self.target.zigTriple(b.allocator));
    }

    switch (self.optimize) {
        .Debug => {}, // Skip since it's the default.
        else => try argv_list.append(b.fmt("-O{s}", .{@tagName(self.optimize)})),
    }

    for (self.include_dirs.items) |include_dir| {
        try argv_list.append("-I");
        try argv_list.append(include_dir);
    }

    for (self.c_macros.items) |c_macro| {
        try argv_list.append("-D");
        try argv_list.append(c_macro);
    }

    try argv_list.append(self.source.getPath(b));

    const output_path = try step.evalZigProcess(argv_list.items, prog_node);

    self.out_basename = fs.path.basename(output_path.?);
    const output_dir = fs.path.dirname(output_path.?).?;

    self.output_file.path = try fs.path.join(
        b.allocator,
        &[_][]const u8{ output_dir, self.out_basename },
    );
}
