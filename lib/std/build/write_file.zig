// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
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
    files: std.TailQueue(File),

    pub const File = struct {
        source: build.GeneratedFile,
        basename: []const u8,
        bytes: []const u8,
    };

    pub fn init(builder: *Builder) WriteFileStep {
        return WriteFileStep{
            .builder = builder,
            .step = Step.init(.WriteFile, "writefile", builder.allocator, make),
            .files = .{},
            .output_dir = undefined,
        };
    }

    pub fn add(self: *WriteFileStep, basename: []const u8, bytes: []const u8) void {
        const node = self.builder.allocator.create(std.TailQueue(File).Node) catch unreachable;
        node.* = .{
            .data = .{
                .source = build.GeneratedFile{
                    .step = &self.step,
                    .getPathFn = getFilePath,
                },
                .basename = self.builder.dupePath(basename),
                .bytes = self.builder.dupe(bytes),
            },
        };

        self.files.append(node);
    }

    /// Unless setOutputDir was called, this function must be called only in
    /// the make step, from a step that has declared a dependency on this one.
    /// To run an executable built with zig build, use `run`, or create an install step and invoke it.
    //pub const getOutputPath = @compileError("WriteFileStep.getOutputPath is deprecated! Use getFileSource to retrieve a ");
    /// Gets a file source for the given basename. If the file does not exist, returns `null`.
    pub fn getFileSource(step: *WriteFileStep, basename: []const u8) ?build.FileSource {
        var it = step.files.first;
        while (it) |node| : (it = node.next) {
            if (std.mem.eql(u8, node.data.basename, basename))
                return build.FileSource{ .generated = &node.data.source };
        }
        return null;
    }

    /// Returns the
    fn getFilePath(source: *const build.GeneratedFile) []const u8 {
        const file = @fieldParentPtr(File, "source", source);
        const step = @fieldParentPtr(WriteFileStep, "step", source.step);

        return fs.path.join(
            step.builder.allocator,
            &[_][]const u8{ step.output_dir, file.basename },
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
        {
            var it = self.files.first;
            while (it) |node| : (it = node.next) {
                hash.update(node.data.basename);
                hash.update(node.data.bytes);
                hash.update("|");
            }
        }
        var digest: [48]u8 = undefined;
        hash.final(&digest);
        var hash_basename: [64]u8 = undefined;
        _ = fs.base64_encoder.encode(&hash_basename, &digest);
        self.output_dir = try fs.path.join(self.builder.allocator, &[_][]const u8{
            self.builder.cache_root,
            "o",
            &hash_basename,
        });
        // TODO replace with something like fs.makePathAndOpenDir
        fs.cwd().makePath(self.output_dir) catch |err| {
            warn("unable to make path {s}: {s}\n", .{ self.output_dir, @errorName(err) });
            return err;
        };
        var dir = try fs.cwd().openDir(self.output_dir, .{});
        defer dir.close();
        {
            var it = self.files.first;
            while (it) |node| : (it = node.next) {
                dir.writeFile(node.data.basename, node.data.bytes) catch |err| {
                    warn("unable to write {s} into {s}: {s}\n", .{
                        node.data.basename,
                        self.output_dir,
                        @errorName(err),
                    });
                    return err;
                };
            }
        }
    }
};
