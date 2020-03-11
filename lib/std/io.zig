const std = @import("std.zig");
const builtin = @import("builtin");
const root = @import("root");
const c = std.c;

const math = std.math;
const assert = std.debug.assert;
const os = std.os;
const fs = std.fs;
const mem = std.mem;
const meta = std.meta;
const trait = meta.trait;
const File = std.fs.File;

pub const Mode = enum {
    /// I/O operates normally, waiting for the operating system syscalls to complete.
    blocking,

    /// I/O functions are generated async and rely on a global event loop. Event-based I/O.
    evented,
};

/// The application's chosen I/O mode. This defaults to `Mode.blocking` but can be overridden
/// by `root.event_loop`.
pub const mode: Mode = if (@hasDecl(root, "io_mode"))
    root.io_mode
else if (@hasDecl(root, "event_loop"))
    Mode.evented
else
    Mode.blocking;
pub const is_async = mode != .blocking;

fn getStdOutHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdOutput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdOutHandle")) {
        return root.os.io.getStdOutHandle();
    }

    return os.STDOUT_FILENO;
}

pub fn getStdOut() File {
    return File{
        .handle = getStdOutHandle(),
        .io_mode = .blocking,
    };
}

fn getStdErrHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdError;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdErrHandle")) {
        return root.os.io.getStdErrHandle();
    }

    return os.STDERR_FILENO;
}

pub fn getStdErr() File {
    return File{
        .handle = getStdErrHandle(),
        .io_mode = .blocking,
        .async_block_allowed = File.async_block_allowed_yes,
    };
}

fn getStdInHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdInput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdInHandle")) {
        return root.os.io.getStdInHandle();
    }

    return os.STDIN_FILENO;
}

pub fn getStdIn() File {
    return File{
        .handle = getStdInHandle(),
        .io_mode = .blocking,
    };
}

pub const InStream = @import("io/in_stream.zig").InStream;
pub const OutStream = @import("io/out_stream.zig").OutStream;
pub const SeekableStream = @import("io/seekable_stream.zig").SeekableStream;

pub const BufferedOutStream = @import("io/buffered_out_stream.zig").BufferedOutStream;
pub const bufferedOutStream = @import("io/buffered_out_stream.zig").bufferedOutStream;

pub const BufferedInStream = @import("io/buffered_in_stream.zig").BufferedInStream;
pub const bufferedInStream = @import("io/buffered_in_stream.zig").bufferedInStream;

pub const PeekStream = @import("io/peek_stream.zig").PeekStream;
pub const peekStream = @import("io/peek_stream.zig").peekStream;

pub const FixedBufferStream = @import("io/fixed_buffer_stream.zig").FixedBufferStream;
pub const fixedBufferStream = @import("io/fixed_buffer_stream.zig").fixedBufferStream;

pub const COutStream = @import("io/c_out_stream.zig").COutStream;
pub const cOutStream = @import("io/c_out_stream.zig").cOutStream;

pub const CountingOutStream = @import("io/counting_out_stream.zig").CountingOutStream;
pub const countingOutStream = @import("io/counting_out_stream.zig").countingOutStream;

pub const BitInStream = @import("io/bit_in_stream.zig").BitInStream;
pub const bitInStream = @import("io/bit_in_stream.zig").bitInStream;

pub const BitOutStream = @import("io/bit_out_stream.zig").BitOutStream;
pub const bitOutStream = @import("io/bit_out_stream.zig").bitOutStream;

pub const Packing = @import("io/serialization.zig").Packing;

pub const Serializer = @import("io/serialization.zig").Serializer;
pub const serializer = @import("io/serialization.zig").serializer;

pub const Deserializer = @import("io/serialization.zig").Deserializer;
pub const deserializer = @import("io/serialization.zig").deserializer;

pub const BufferedAtomicFile = @import("io/buffered_atomic_file.zig").BufferedAtomicFile;

pub const StreamSource = @import("io/stream_source.zig").StreamSource;

/// Deprecated; use `std.fs.Dir.writeFile`.
pub fn writeFile(path: []const u8, data: []const u8) !void {
    return fs.cwd().writeFile(path, data);
}

/// Deprecated; use `std.fs.Dir.readFileAlloc`.
pub fn readFileAlloc(allocator: *mem.Allocator, path: []const u8) ![]u8 {
    return fs.cwd().readFileAlloc(allocator, path, math.maxInt(usize));
}

/// An OutStream that doesn't write to anything.
pub const null_out_stream = @as(NullOutStream, .{ .context = {} });

const NullOutStream = OutStream(void, error{}, dummyWrite);
fn dummyWrite(context: void, data: []const u8) error{}!usize {
    return data.len;
}

test "null_out_stream" {
    null_out_stream.writeAll("yay" ** 10) catch |err| switch (err) {};
}

test "" {
    _ = @import("io/test.zig");
}
