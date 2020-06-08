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

/// This is an enum value to use for I/O mode at runtime, since it takes up zero bytes at runtime,
/// and makes expressions comptime-known when `is_async` is `false`.
pub const ModeOverride = if (is_async) Mode else enum { blocking };
pub const default_mode: ModeOverride = if (is_async) Mode.evented else .blocking;

fn getStdOutHandle() os.fd_t {
    if (builtin.os.tag == .windows) {
        return os.windows.peb().ProcessParameters.hStdOutput;
    }

    if (@hasDecl(root, "os") and @hasDecl(root.os, "io") and @hasDecl(root.os.io, "getStdOutHandle")) {
        return root.os.io.getStdOutHandle();
    }

    return os.STDOUT_FILENO;
}

/// TODO: async stdout on windows without a dedicated thread.
/// https://github.com/ziglang/zig/pull/4816#issuecomment-604521023
pub fn getStdOut() File {
    return File{
        .handle = getStdOutHandle(),
        .capable_io_mode = .blocking,
        .intended_io_mode = default_mode,
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

/// This returns a `File` that is configured to block with every write, in order
/// to facilitate better debugging. This can be changed by modifying the `intended_io_mode` field.
pub fn getStdErr() File {
    return File{
        .handle = getStdErrHandle(),
        .capable_io_mode = .blocking,
        .intended_io_mode = .blocking,
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

/// TODO: async stdin on windows without a dedicated thread.
/// https://github.com/ziglang/zig/pull/4816#issuecomment-604521023
pub fn getStdIn() File {
    return File{
        .handle = getStdInHandle(),
        .capable_io_mode = .blocking,
        .intended_io_mode = default_mode,
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

pub const MultiOutStream = @import("io/multi_out_stream.zig").MultiOutStream;
pub const multiOutStream = @import("io/multi_out_stream.zig").multiOutStream;

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
    _ = @import("io/bit_in_stream.zig");
    _ = @import("io/bit_out_stream.zig");
    _ = @import("io/buffered_atomic_file.zig");
    _ = @import("io/buffered_in_stream.zig");
    _ = @import("io/buffered_out_stream.zig");
    _ = @import("io/c_out_stream.zig");
    _ = @import("io/counting_out_stream.zig");
    _ = @import("io/fixed_buffer_stream.zig");
    _ = @import("io/in_stream.zig");
    _ = @import("io/out_stream.zig");
    _ = @import("io/peek_stream.zig");
    _ = @import("io/seekable_stream.zig");
    _ = @import("io/serialization.zig");
    _ = @import("io/stream_source.zig");
    _ = @import("io/test.zig");
}

pub const writeFile = @compileError("deprecated: use std.fs.Dir.writeFile with math.maxInt(usize)");
pub const readFileAlloc = @compileError("deprecated: use std.fs.Dir.readFileAlloc");
