const Server = @This();

const builtin = @import("builtin");

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const native_endian = builtin.target.cpu.arch.endian();
const need_bswap = native_endian != .little;
const Cache = std.Build.Cache;
const OutMessage = std.zig.Server.Message;
const InMessage = std.zig.Client.Message;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

in: *Reader,
out: *Writer,

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
        /// Body is a EmitDigest.
        emit_digest,
        /// Body is a TestMetadata
        test_metadata,
        /// Body is a TestResults
        test_results,
        /// Body is a series of strings, delimited by null bytes.
        /// Each string is a prefixed file path.
        /// The first byte indicates the file prefix path (see prefixes fields
        /// of Cache). This byte is sent over the wire incremented so that null
        /// bytes are not confused with string terminators.
        /// The remaining bytes is the file path relative to that prefix.
        /// The prefixes are hard-coded in Compilation.create (cwd, zig lib dir, local cache dir)
        file_system_inputs,
        /// Body is a u64le that indicates the file path within the cache used
        /// to store coverage information. The integer is a hash of the PCs
        /// stored within that file.
        coverage_id,
        /// Body is a u64le that indicates the function pointer virtual memory
        /// address of the fuzz unit test. This is used to provide a starting
        /// point to view coverage.
        fuzz_start_addr,

        _,
    };

    pub const PathPrefix = enum(u8) {
        cwd,
        zig_lib,
        local_cache,
        global_cache,
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
    /// * expected_panic_msg: [tests_len]u32,
    ///   - null-terminated string_bytes index
    ///   - 0 means does not expect panic
    /// * string_bytes: [string_bytes_len]u8,
    pub const TestMetadata = extern struct {
        string_bytes_len: u32,
        tests_len: u32,
    };

    pub const TestResults = extern struct {
        index: u32,
        flags: Flags,

        pub const Flags = packed struct(u32) {
            fail: bool,
            skip: bool,
            leak: bool,
            fuzz: bool,
            log_err_count: u28 = 0,
        };
    };

    /// Trailing:
    /// * the hex digest of the cache directory within the /o/ subdirectory.
    pub const EmitDigest = extern struct {
        flags: Flags,

        pub const Flags = packed struct(u8) {
            cache_hit: bool,
            reserved: u7 = 0,
        };
    };
};

pub const Options = struct {
    in: *Reader,
    out: *Writer,
    zig_version: []const u8,
};

pub fn init(options: Options) !Server {
    var s: Server = .{
        .in = options.in,
        .out = options.out,
    };
    try s.serveStringMessage(.zig_version, options.zig_version);
    return s;
}

pub fn receiveMessage(s: *Server) !InMessage.Header {
    return s.in.takeStruct(InMessage.Header, .little);
}

pub fn receiveBody_u32(s: *Server) !u32 {
    return s.in.takeInt(u32, .little);
}

pub fn serveStringMessage(s: *Server, tag: OutMessage.Tag, msg: []const u8) !void {
    try s.serveMessageHeader(.{
        .tag = tag,
        .bytes_len = @intCast(msg.len),
    });
    try s.out.writeAll(msg);
    try s.out.flush();
}

/// Don't forget to flush!
pub fn serveMessageHeader(s: *const Server, header: OutMessage.Header) !void {
    try s.out.writeStruct(header, .little);
}

pub fn serveU64Message(s: *const Server, tag: OutMessage.Tag, int: u64) !void {
    try serveMessageHeader(s, .{
        .tag = tag,
        .bytes_len = @sizeOf(u64),
    });
    try s.out.writeInt(u64, int, .little);
    try s.out.flush();
}

pub fn serveEmitDigest(
    s: *Server,
    digest: *const [Cache.bin_digest_len]u8,
    header: OutMessage.EmitDigest,
) !void {
    try s.serveMessageHeader(.{
        .tag = .emit_digest,
        .bytes_len = @intCast(digest.len + @sizeOf(OutMessage.EmitDigest)),
    });
    try s.out.writeStruct(header, .little);
    try s.out.writeAll(digest);
    try s.out.flush();
}

pub fn serveTestResults(s: *Server, msg: OutMessage.TestResults) !void {
    try s.serveMessageHeader(.{
        .tag = .test_results,
        .bytes_len = @intCast(@sizeOf(OutMessage.TestResults)),
    });
    try s.out.writeStruct(msg, .little);
    try s.out.flush();
}

pub fn serveErrorBundle(s: *Server, error_bundle: std.zig.ErrorBundle) !void {
    const eb_hdr: OutMessage.ErrorBundle = .{
        .extra_len = @intCast(error_bundle.extra.len),
        .string_bytes_len = @intCast(error_bundle.string_bytes.len),
    };
    const bytes_len = @sizeOf(OutMessage.ErrorBundle) +
        4 * error_bundle.extra.len + error_bundle.string_bytes.len;
    try s.serveMessageHeader(.{
        .tag = .error_bundle,
        .bytes_len = @intCast(bytes_len),
    });
    try s.out.writeStruct(eb_hdr, .little);
    try s.out.writeSliceEndian(u32, error_bundle.extra, .little);
    try s.out.writeAll(error_bundle.string_bytes);
    try s.out.flush();
}

pub const TestMetadata = struct {
    names: []const u32,
    expected_panic_msgs: []const u32,
    string_bytes: []const u8,
};

pub fn serveTestMetadata(s: *Server, test_metadata: TestMetadata) !void {
    const header: OutMessage.TestMetadata = .{
        .tests_len = @as(u32, @intCast(test_metadata.names.len)),
        .string_bytes_len = @as(u32, @intCast(test_metadata.string_bytes.len)),
    };
    const trailing = 2;
    const bytes_len = @sizeOf(OutMessage.TestMetadata) +
        trailing * @sizeOf(u32) * test_metadata.names.len + test_metadata.string_bytes.len;

    try s.serveMessageHeader(.{
        .tag = .test_metadata,
        .bytes_len = @intCast(bytes_len),
    });
    try s.out.writeStruct(header, .little);
    try s.out.writeSliceEndian(u32, test_metadata.names, .little);
    try s.out.writeSliceEndian(u32, test_metadata.expected_panic_msgs, .little);
    try s.out.writeAll(test_metadata.string_bytes);
    try s.out.flush();
}
