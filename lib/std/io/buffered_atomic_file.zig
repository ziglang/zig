// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const mem = std.mem;
const fs = std.fs;
const File = std.fs.File;

pub const BufferedAtomicFile = struct {
    atomic_file: fs.AtomicFile,
    file_stream: File.OutStream,
    buffered_stream: BufferedOutStream,
    allocator: *mem.Allocator,

    pub const buffer_size = 4096;
    pub const BufferedOutStream = std.io.BufferedOutStream(buffer_size, File.OutStream);
    pub const OutStream = std.io.OutStream(*BufferedOutStream, BufferedOutStream.Error, BufferedOutStream.write);

    /// TODO when https://github.com/ziglang/zig/issues/2761 is solved
    /// this API will not need an allocator
    pub fn create(
        allocator: *mem.Allocator,
        dir: fs.Dir,
        dest_path: []const u8,
        atomic_file_options: fs.Dir.AtomicFileOptions,
    ) !*BufferedAtomicFile {
        var self = try allocator.create(BufferedAtomicFile);
        self.* = BufferedAtomicFile{
            .atomic_file = undefined,
            .file_stream = undefined,
            .buffered_stream = undefined,
            .allocator = allocator,
        };
        errdefer allocator.destroy(self);

        self.atomic_file = try dir.atomicFile(dest_path, atomic_file_options);
        errdefer self.atomic_file.deinit();

        self.file_stream = self.atomic_file.file.outStream();
        self.buffered_stream = .{ .unbuffered_writer = self.file_stream };
        return self;
    }

    /// always call destroy, even after successful finish()
    pub fn destroy(self: *BufferedAtomicFile) void {
        self.atomic_file.deinit();
        self.allocator.destroy(self);
    }

    pub fn finish(self: *BufferedAtomicFile) !void {
        try self.buffered_stream.flush();
        try self.atomic_file.finish();
    }

    pub fn stream(self: *BufferedAtomicFile) OutStream {
        return .{ .context = &self.buffered_stream };
    }
};
