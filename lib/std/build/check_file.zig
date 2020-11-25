// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const build = std.build;
const Step = build.Step;
const Builder = build.Builder;
const fs = std.fs;
const mem = std.mem;
const warn = std.debug.warn;

pub const CheckFileStep = struct {
    step: Step,
    builder: *Builder,
    expected_matches: []const []const u8,
    source: build.FileSource,
    max_bytes: usize = 20 * 1024 * 1024,

    pub fn create(
        builder: *Builder,
        source: build.FileSource,
        expected_matches: []const []const u8,
    ) *CheckFileStep {
        const self = builder.allocator.create(CheckFileStep) catch unreachable;
        self.* = CheckFileStep{
            .builder = builder,
            .step = Step.init(.CheckFile, "CheckFile", builder.allocator, make),
            .source = source,
            .expected_matches = expected_matches,
        };
        self.source.addStepDependencies(&self.step);
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(CheckFileStep, "step", step);

        const src_path = self.source.getPath(self.builder);
        const contents = try fs.cwd().readFileAlloc(self.builder.allocator, src_path, self.max_bytes);

        for (self.expected_matches) |expected_match| {
            if (mem.indexOf(u8, contents, expected_match) == null) {
                warn(
                    \\
                    \\========= Expected to find: ===================
                    \\{}
                    \\========= But file does not contain it: =======
                    \\{}
                    \\
                , .{ expected_match, contents });
                return error.TestFailed;
            }
        }
    }
};
