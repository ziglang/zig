// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const io = std.io;

/// Provides `io.Reader`, `io.Writer`, and `io.SeekableStream` for in-memory buffers as
/// well as files.
/// For memory sources, if the supplied byte buffer is const, then `io.Writer` is not available.
/// The error set of the stream functions is the error set of the corresponding file functions.
pub const StreamSource = union(enum) {
    buffer: io.FixedBufferStream([]u8),
    const_buffer: io.FixedBufferStream([]const u8),
    file: std.fs.File,

    pub const ReadError = std.fs.File.ReadError;
    pub const WriteError = std.fs.File.WriteError;
    pub const SeekError = std.fs.File.SeekError;
    pub const GetSeekPosError = std.fs.File.GetSeekPosError;

    pub const Reader = io.Reader(*StreamSource, ReadError, read);
    pub const Writer = io.Writer(*StreamSource, WriteError, write);
    pub const SeekableStream = io.SeekableStream(
        *StreamSource,
        SeekError,
        GetSeekPosError,
        seekTo,
        seekBy,
        getPos,
        getEndPos,
    );

    pub fn read(self: *StreamSource, dest: []u8) ReadError!usize {
        switch (self.*) {
            .buffer => |*x| return x.read(dest),
            .const_buffer => |*x| return x.read(dest),
            .file => |x| return x.read(dest),
        }
    }

    pub fn write(self: *StreamSource, bytes: []const u8) WriteError!usize {
        switch (self.*) {
            .buffer => |*x| return x.write(bytes),
            .const_buffer => return error.AccessDenied,
            .file => |x| return x.write(bytes),
        }
    }

    pub fn seekTo(self: *StreamSource, pos: u64) SeekError!void {
        switch (self.*) {
            .buffer => |*x| return x.seekTo(pos),
            .const_buffer => |*x| return x.seekTo(pos),
            .file => |x| return x.seekTo(pos),
        }
    }

    pub fn seekBy(self: *StreamSource, amt: i64) SeekError!void {
        switch (self.*) {
            .buffer => |*x| return x.seekBy(amt),
            .const_buffer => |*x| return x.seekBy(amt),
            .file => |x| return x.seekBy(amt),
        }
    }

    pub fn getEndPos(self: *StreamSource) GetSeekPosError!u64 {
        switch (self.*) {
            .buffer => |*x| return x.getEndPos(),
            .const_buffer => |*x| return x.getEndPos(),
            .file => |x| return x.getEndPos(),
        }
    }

    pub fn getPos(self: *StreamSource) GetSeekPosError!u64 {
        switch (self.*) {
            .buffer => |*x| return x.getPos(),
            .const_buffer => |*x| return x.getPos(),
            .file => |x| return x.getPos(),
        }
    }

    pub fn reader(self: *StreamSource) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *StreamSource) Writer {
        return .{ .context = self };
    }

    pub fn seekableStream(self: *StreamSource) SeekableStream {
        return .{ .context = self };
    }
};
