// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const build = @import("../build.zig");
const Step = build.Step;
const Builder = build.Builder;
const fs = std.fs;
const warn = std.debug.warn;
const ArrayList = std.ArrayList;

pub const WriteFileStep = struct {
    step: Step,
    builder: *Builder,
    output_dir: []const u8,
    files: ArrayList(File),

    pub const File = struct {
        basename: []const u8,
        bytes: []const u8,
    };

    pub fn init(builder: *Builder) WriteFileStep {
        return WriteFileStep{
            .builder = builder,
            .step = Step.init(.WriteFile, "writefile", builder.allocator, make),
            .files = ArrayList(File).init(builder.allocator),
            .output_dir = undefined,
        };
    }

    pub fn add(self: *WriteFileStep, basename: []const u8, bytes: []const u8) void {
        self.files.append(.{ .basename = basename, .bytes = bytes }) catch unreachable;
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    /// To run an executable built with zig build, use `run`, or create an install step and invoke it.
    pub fn getOutputPath(self: *WriteFileStep, basename: []const u8) []const u8 {
        return fs.path.join(
            self.builder.allocator,
            &[_][]const u8{ self.output_dir, basename },
        ) catch unreachable;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(WriteFileStep, "step", step);

        // The cache is used here not really as a way to speed things up - because writing
        // the data to a file would probably be very fast - but as a way to find a canonical
        // location to put build artifacts.

        // If, for example, a hard-coded path was used as the location to put WriteFileStep
        // files, then two WriteFileSteps executing in parallel might clobber each other.

        // TODO port the cache system from stage1 to zig std lib. Until then we use blake2b
        // directly and construct the path, and no "cache hit" detection happens; the files
        // are always written.
        var hash = std.crypto.hash.blake2.Blake2b384.init(.{});

        // Random bytes to make WriteFileStep unique. Refresh this with
        // new random bytes when WriteFileStep implementation is modified
        // in a non-backwards-compatible way.
        hash.update("eagVR1dYXoE7ARDP");
        for (self.files.items) |file| {
            hash.update(file.basename);
            hash.update(file.bytes);
            hash.update("|");
        }
        var digest: [48]u8 = undefined;
        hash.final(&digest);
        var hash_basename: [64]u8 = undefined;
        fs.base64_encoder.encode(&hash_basename, &digest);
        self.output_dir = try fs.path.join(self.builder.allocator, &[_][]const u8{
            self.builder.cache_root,
            "o",
            &hash_basename,
        });
        // TODO replace with something like fs.makePathAndOpenDir
        fs.cwd().makePath(self.output_dir) catch |err| {
            warn("unable to make path {}: {}\n", .{ self.output_dir, @errorName(err) });
            return err;
        };
        var dir = try fs.cwd().openDir(self.output_dir, .{});
        defer dir.close();
        for (self.files.items) |file| {
            dir.writeFile(file.basename, file.bytes) catch |err| {
                warn("unable to write {} into {}: {}\n", .{
                    file.basename,
                    self.output_dir,
                    @errorName(err),
                });
                return err;
            };
        }
    }
};
