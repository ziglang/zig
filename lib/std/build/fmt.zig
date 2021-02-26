// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const BufMap = std.BufMap;
const mem = std.mem;

pub const FmtStep = struct {
    step: Step,
    builder: *Builder,
    argv: [][]const u8,

    pub fn create(builder: *Builder, paths: []const []const u8) *FmtStep {
        const self = builder.allocator.create(FmtStep) catch unreachable;
        const name = "zig fmt";
        self.* = FmtStep{
            .step = Step.init(.Fmt, name, builder.allocator, make),
            .builder = builder,
            .argv = builder.allocator.alloc([]u8, paths.len + 2) catch unreachable,
        };

        self.argv[0] = builder.zig_exe;
        self.argv[1] = "fmt";
        for (paths) |path, i| {
            self.argv[2 + i] = builder.pathFromRoot(path);
        }
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(FmtStep, "step", step);

        return self.builder.spawnChild(self.argv);
    }
};
