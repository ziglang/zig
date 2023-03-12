in: std.fs.File,
out: std.fs.File,
receive_fifo: std.fifo.LinearFifo(u8, .Dynamic),

pub const Message = struct {
    pub const Header = extern struct {
        tag: Tag,
        /// Size of the body only; does not include this Header.
        bytes_len: u32,
    };

    pub const Tag = enum(u32) {
        /// Body is a UTF-8 string.
        zig_version,
        /// Body is an ErrorBundle.
        error_bundle,
        /// Body is a UTF-8 string.
        progress,
        /// Body is a EmitBinPath.
        emit_bin_path,
        /// Body is a TestMetadata
        test_metadata,
        /// Body is a TestResults
        test_results,

        _,
    };

    /// Trailing:
    /// * extra: [extra_len]u32,
    /// * string_bytes: [string_bytes_len]u8,
    /// See `std.zig.ErrorBundle`.
    pub const ErrorBundle = extern struct {
        extra_len: u32,
        string_bytes_len: u32,
    };

    /// Trailing:
    /// * name: [tests_len]u32
    ///   - null-terminated string_bytes index
    /// * async_frame_len: [tests_len]u32,
    ///   - 0 means not async
    /// * expected_panic_msg: [tests_len]u32,
    ///   - null-terminated string_bytes index
    ///   - 0 means does not expect pani
    /// * string_bytes: [string_bytes_len]u8,
    pub const TestMetadata = extern struct {
        string_bytes_len: u32,
        tests_len: u32,
    };

    pub const TestResults = extern struct {
        index: u32,
        flags: Flags,

        pub const Flags = packed struct(u8) {
            fail: bool,
            skip: bool,
            leak: bool,

            reserved: u5 = 0,
        };
    };

    /// Trailing:
    /// * the file system path the emitted binary can be found
    pub const EmitBinPath = extern struct {
        flags: Flags,

        pub const Flags = packed struct(u8) {
            cache_hit: bool,
            reserved: u7 = 0,
        };
    };
};

pub const Options = struct {
    gpa: Allocator,
    in: std.fs.File,
    out: std.fs.File,
    zig_version: []const u8,
};

pub fn init(options: Options) !Server {
    var s: Server = .{
        .in = options.in,
        .out = options.out,
        .receive_fifo = std.fifo.LinearFifo(u8, .Dynamic).init(options.gpa),
    };
    try s.serveStringMessage(.zig_version, options.zig_version);
    return s;
}

pub fn deinit(s: *Server) void {
    s.receive_fifo.deinit();
    s.* = undefined;
}

pub fn receiveMessage(s: *Server) !InMessage.Header {
    const Header = InMessage.Header;
    const fifo = &s.receive_fifo;

    while (true) {
        const buf = fifo.readableSlice(0);
        assert(fifo.readableLength() == buf.len);
        if (buf.len >= @sizeOf(Header)) {
            const header = @ptrCast(*align(1) const Header, buf[0..@sizeOf(Header)]);

            if (buf.len - @sizeOf(Header) >= header.bytes_len) {
                const result = header.*;
                fifo.discard(@sizeOf(Header));
                return result;
            } else {
                const needed = header.bytes_len - (buf.len - @sizeOf(Header));
                const write_buffer = try fifo.writableWithSize(needed);
                const amt = try s.in.read(write_buffer);
                fifo.update(amt);
                continue;
            }
        }

        const write_buffer = try fifo.writableWithSize(256);
        const amt = try s.in.read(write_buffer);
        fifo.update(amt);
    }
}

pub fn receiveBody_u32(s: *Server) !u32 {
    const fifo = &s.receive_fifo;
    const buf = fifo.readableSlice(0);
    const result = @ptrCast(*align(1) const u32, buf[0..4]).*;
    fifo.discard(4);
    return result;
}

pub fn serveStringMessage(s: *Server, tag: OutMessage.Tag, msg: []const u8) !void {
    return s.serveMessage(.{
        .tag = tag,
        .bytes_len = @intCast(u32, msg.len),
    }, &.{msg});
}

pub fn serveMessage(
    s: *const Server,
    header: OutMessage.Header,
    bufs: []const []const u8,
) !void {
    var iovecs: [10]std.os.iovec_const = undefined;
    iovecs[0] = .{
        .iov_base = @ptrCast([*]const u8, &header),
        .iov_len = @sizeOf(OutMessage.Header),
    };
    for (bufs, iovecs[1 .. bufs.len + 1]) |buf, *iovec| {
        iovec.* = .{
            .iov_base = buf.ptr,
            .iov_len = buf.len,
        };
    }
    try s.out.writevAll(iovecs[0 .. bufs.len + 1]);
}

pub fn serveEmitBinPath(
    s: *Server,
    fs_path: []const u8,
    header: OutMessage.EmitBinPath,
) !void {
    try s.serveMessage(.{
        .tag = .emit_bin_path,
        .bytes_len = @intCast(u32, fs_path.len + @sizeOf(OutMessage.EmitBinPath)),
    }, &.{
        std.mem.asBytes(&header),
        fs_path,
    });
}

pub fn serveTestResults(
    s: *Server,
    msg: OutMessage.TestResults,
) !void {
    try s.serveMessage(.{
        .tag = .test_results,
        .bytes_len = @intCast(u32, @sizeOf(OutMessage.TestResults)),
    }, &.{
        std.mem.asBytes(&msg),
    });
}

pub fn serveErrorBundle(s: *Server, error_bundle: std.zig.ErrorBundle) !void {
    const eb_hdr: OutMessage.ErrorBundle = .{
        .extra_len = @intCast(u32, error_bundle.extra.len),
        .string_bytes_len = @intCast(u32, error_bundle.string_bytes.len),
    };
    const bytes_len = @sizeOf(OutMessage.ErrorBundle) +
        4 * error_bundle.extra.len + error_bundle.string_bytes.len;
    try s.serveMessage(.{
        .tag = .error_bundle,
        .bytes_len = @intCast(u32, bytes_len),
    }, &.{
        std.mem.asBytes(&eb_hdr),
        // TODO: implement @ptrCast between slices changing the length
        std.mem.sliceAsBytes(error_bundle.extra),
        error_bundle.string_bytes,
    });
}

pub const TestMetadata = struct {
    names: []const u32,
    async_frame_sizes: []const u32,
    expected_panic_msgs: []const u32,
    string_bytes: []const u8,
};

pub fn serveTestMetadata(s: *Server, test_metadata: TestMetadata) !void {
    const header: OutMessage.TestMetadata = .{
        .tests_len = @intCast(u32, test_metadata.names.len),
        .string_bytes_len = @intCast(u32, test_metadata.string_bytes.len),
    };
    const bytes_len = @sizeOf(OutMessage.TestMetadata) +
        3 * 4 * test_metadata.names.len + test_metadata.string_bytes.len;
    return s.serveMessage(.{
        .tag = .test_metadata,
        .bytes_len = @intCast(u32, bytes_len),
    }, &.{
        std.mem.asBytes(&header),
        // TODO: implement @ptrCast between slices changing the length
        std.mem.sliceAsBytes(test_metadata.names),
        std.mem.sliceAsBytes(test_metadata.async_frame_sizes),
        std.mem.sliceAsBytes(test_metadata.expected_panic_msgs),
        test_metadata.string_bytes,
    });
}

const OutMessage = std.zig.Server.Message;
const InMessage = std.zig.Client.Message;

const Server = @This();
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
