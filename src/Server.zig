in: std.fs.File,
out: std.fs.File,
receive_fifo: std.fifo.LinearFifo(u8, .Dynamic),

pub const Options = struct {
    gpa: Allocator,
    in: std.fs.File,
    out: std.fs.File,
};

pub fn init(options: Options) !Server {
    var s: Server = .{
        .in = options.in,
        .out = options.out,
        .receive_fifo = std.fifo.LinearFifo(u8, .Dynamic).init(options.gpa),
    };
    try s.serveStringMessage(.zig_version, build_options.version);
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
            if (header.bytes_len != 0)
                return error.InvalidClientMessage;
            const result = header.*;
            fifo.discard(@sizeOf(Header));
            return result;
        }

        const write_buffer = try fifo.writableWithSize(256);
        const amt = try s.in.read(write_buffer);
        fifo.update(amt);
    }
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
    header: std.zig.Server.Message.EmitBinPath,
) !void {
    try s.serveMessage(.{
        .tag = .emit_bin_path,
        .bytes_len = @intCast(u32, fs_path.len + @sizeOf(std.zig.Server.Message.EmitBinPath)),
    }, &.{
        std.mem.asBytes(&header),
        fs_path,
    });
}

pub fn serveErrorBundle(s: *Server, error_bundle: std.zig.ErrorBundle) !void {
    const eb_hdr: std.zig.Server.Message.ErrorBundle = .{
        .extra_len = @intCast(u32, error_bundle.extra.len),
        .string_bytes_len = @intCast(u32, error_bundle.string_bytes.len),
    };
    const bytes_len = @sizeOf(std.zig.Server.Message.ErrorBundle) +
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

const OutMessage = std.zig.Server.Message;
const InMessage = std.zig.Client.Message;

const Server = @This();
const std = @import("std");
const build_options = @import("build_options");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
