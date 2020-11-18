// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;
const WriteFileStep = build.WriteFileStep;
const LibExeObjStep = build.LibExeObjStep;
const CheckFileStep = build.CheckFileStep;
const fs = std.fs;
const mem = std.mem;
const CrossTarget = std.zig.CrossTarget;

pub const TranslateCStep = struct {
    step: Step,
    builder: *Builder,
    source: build.FileSource,
    include_dirs: std.ArrayList([]const u8),
    output_dir: ?[]const u8,
    out_basename: []const u8,
    target: CrossTarget = CrossTarget{},

    pub fn create(builder: *Builder, source: build.FileSource) *TranslateCStep {
        const self = builder.allocator.create(TranslateCStep) catch unreachable;
        self.* = TranslateCStep{
            .step = Step.init(.TranslateC, "translate-c", builder.allocator, make),
            .builder = builder,
            .source = source,
            .include_dirs = std.ArrayList([]const u8).init(builder.allocator),
            .output_dir = null,
            .out_basename = undefined,
        };
        source.addStepDependencies(&self.step);
        return self;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    /// To run an executable built with zig build, use `run`, or create an install step and invoke it.
    pub fn getOutputPath(self: *TranslateCStep) []const u8 {
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir.?, self.out_basename },
        ) catch unreachable;
    }

    pub fn setTarget(self: *TranslateCStep, target: CrossTarget) void {
        self.target = target;
    }

    /// Creates a step to build an executable from the translated source.
    pub fn addExecutable(self: *TranslateCStep) *LibExeObjStep {
        return self.builder.addExecutableSource("translated_c", @as(build.FileSource, .{ .translate_c = self }));
    }

    pub fn addIncludeDir(self: *TranslateCStep, include_dir: []const u8) void {
        self.include_dirs.append(include_dir) catch unreachable;
    }

    pub fn addCheckFile(self: *TranslateCStep, expected_matches: []const []const u8) *CheckFileStep {
        return CheckFileStep.create(self.builder, .{ .translate_c = self }, expected_matches);
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(TranslateCStep, "step", step);

        var argv_list = std.ArrayList([]const u8).init(self.builder.allocator);
        try argv_list.append(self.builder.zig_exe);
        try argv_list.append("translate-c");
        try argv_list.append("-lc");

        try argv_list.append("--enable-cache");

        if (!self.target.isNative()) {
            try argv_list.append("-target");
            try argv_list.append(try self.target.zigTriple(self.builder.allocator));
        }

        for (self.include_dirs.items) |include_dir| {
            try argv_list.append("-I");
            try argv_list.append(include_dir);
        }

        try argv_list.append(self.source.getPath(self.builder));

        const output_path_nl = try self.builder.execFromStep(argv_list.items, &self.step);
        const output_path = mem.trimRight(u8, output_path_nl, "\r\n");

        self.out_basename = fs.path.basename(output_path);
        if (self.output_dir) |output_dir| {
            const full_dest = try fs.path.join(self.builder.allocator, &[_][]const u8{ output_dir, self.out_basename });
            try self.builder.updateFile(output_path, full_dest);
        } else {
            self.output_dir = fs.path.dirname(output_path).?;
        }
    }
};
