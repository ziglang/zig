const std = @import("std");
const json = std.json;
const io = std.io;
const mem = std.mem;
const debug = std.debug;

const json_rpc = @import("json_rpc.zig");
const serial = @import("json_serialize.zig");

pub const LspError = error{
    InvalidHeader,
    HeaderFieldTooLong,
    MessageTooLong,
    PrematureEndOfStream,
};

pub fn readMessageAlloc(stream: var, alloc: *mem.Allocator) ![]u8 {
    var jsonLen: ?usize = null;
    var buffer: [4 * 1024]u8 = undefined;

    while (true) {
        const line = io.readLineSliceFrom(stream, buffer[0..]) catch |err| switch (err) {
            error.OutOfMemory => return LspError.HeaderFieldTooLong,
            else => return err,
        };

        if (line.len == 0) {
            break; // end of header
        }

        const pos = mem.indexOf(u8, line, ": ") orelse return LspError.InvalidHeader;
        if (mem.eql(u8, line[0..pos], "Content-Length")) {
            jsonLen = try std.fmt.parseInt(usize, line[pos + 2 ..], 10);
        }
    }

    if (jsonLen == null) {
        return LspError.InvalidHeader;
    }

    var jsonStr = try alloc.alloc(u8, jsonLen.?);
    errdefer alloc.free(jsonStr);

    const bytesRead = try stream.read(jsonStr);
    if (bytesRead != jsonLen.?) {
        return LspError.PrematureEndOfStream;
    }

    return jsonStr;
}

pub fn MessageWriter(comptime Error: type) type {
    return struct {
        const Self = @This();

        buffer: std.ArrayList(u8),
        stream: *Stream,
        alloc: *mem.Allocator,

        pub const Stream = io.OutStream(Error);

        pub fn init(stream: *Stream, alloc: *mem.Allocator) Self {
            return Self{
                .stream = stream,
                .alloc = alloc,
                .buffer = std.ArrayList(u8).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }

        fn writeString(self: *Self, jsonStr: []const u8) !void {
            try self.stream.print("Content-Length: {}\r\n\r\n{}", .{ jsonStr.len, jsonStr });
        }

        pub fn writeResponse(self: *Self, response: json_rpc.Response) !void {
            debug.assert(response.validate());

            var mem_buffer: [1024 * 128]u8 = undefined;
            var sliceStream = io.SliceOutStream.init(mem_buffer[0..]);
            var jsonStream = json.WriteStream(@TypeOf(sliceStream.stream), 1024).init(&sliceStream.stream);

            try serial.serialize(response, &jsonStream);
            try self.writeString(sliceStream.getWritten());
        }

        pub fn writeRequest(self: *Self, request: json_rpc.Request) !void {
            debug.assert(request.validate());

            var mem_buffer: [1024 * 128]u8 = undefined;
            var sliceStream = io.SliceOutStream.init(mem_buffer[0..]);
            var jsonStream = json.WriteStream(@TypeOf(sliceStream.stream), 1024).init(&sliceStream.stream);

            try serial.serialize(request, &jsonStream);
            try self.writeString(sliceStream.getWritten());
        }
    };
}
