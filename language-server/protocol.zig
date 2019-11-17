const std = @import("std");
const json = std.json;
const io = std.io;
const mem = std.mem;

const json_rpc = @import("json_rpc.zig");
const serial = @import("json_serialize.zig");

const LspError = error {
    InvalidHeader,
    HeaderFieldTooLong,
    MessageTooLong,
    PrematureEndOfStream,
    InvalidRequest
};

pub fn MessageReader(comptime Error: type) type {
    return struct {
        const Self = @This();

        buffer: std.ArrayList(u8),
        stream: *Stream,
        alloc: *mem.Allocator,

        pub const Stream = io.InStream(Error);

        pub fn init(stream: *Stream, alloc: *mem.Allocator) Self {
            return Self {
                .stream = stream,
                .alloc = alloc,
                .buffer = std.ArrayList(u8).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }

        pub fn readMessage(self: *Self) !json_rpc.Request {
            var jsonLen: ?u32 = null;

            try self.buffer.resize(4 * 1024);

            while(true) {
                const line = try io.readLineSliceFrom(self.stream, self.buffer.toSlice());
                if(line.len == 0){
                    break;
                }

                const pos = mem.indexOf(u8, line, ": ") orelse return LspError.InvalidHeader;
                if(mem.eql(u8, line[0..pos], "Content-Length")){
                    jsonLen = try std.fmt.parseInt(u32, line[pos + 2..], 10);
                }
            }

            if(jsonLen == null){
                return LspError.InvalidHeader;
            }

            try self.buffer.resize(jsonLen.?);
            
            const bytesRead = try self.stream.read(self.buffer.toSlice());
            if(bytesRead != jsonLen.?){
                return LspError.PrematureEndOfStream;
            }

            var parser = json.Parser.init(self.alloc, true);
            defer parser.deinit();

            var tree = try parser.parse(self.buffer.toSlice());
            errdefer tree.deinit();

            const request = try serial.deserialize(json_rpc.Request, tree.root, self.alloc);
            if(!request.validate()){
                return error.InvalidRequest;
            }
            return request;
        }
    };
}

pub fn MessageWriter(comptime Error: type) type {
    return struct {
        const Self = @This();

        buffer: std.ArrayList(u8),
        stream: *Stream,
        alloc: *mem.Allocator,

        pub const Stream = io.OutStream(Error);

        pub fn init(stream: *Stream, alloc: *mem.Allocator) Self {
            return Self {
                .stream = stream,
                .alloc = alloc,
                .buffer = std.ArrayList(u8).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }

        fn writeString(self: *Self, jsonStr: []const u8) !void {
            try self.stream.print("Content-Length: {}\r\n\r\n{}", jsonStr.len, jsonStr);
        }

        pub fn writeResponse(self: *Self, response: json_rpc.Response) !void {
            try self.writeString();
        }

        pub fn writeRequest(self: *Self, request: json_rpc.Request) !void {
            var mem_buffer: [1024 * 128]u8 = undefined;
            var stream = io.SliceOutStream.init(mem_buffer[0..]);
            try serial.serialize(request, &stream.stream);
            try self.writeString(stream.getWritten());
        }
    };
}
