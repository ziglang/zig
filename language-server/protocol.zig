const std = @import("std");
const io = std.io;
const mem = std.mem;
const debug = std.debug;

const types = @import("types.zig");
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

    // read header
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

pub fn writeMessage(stream: var, jsonStr: []const u8) !void {
    try stream.print("Content-Length: {}\r\n\r\n{}", .{ jsonStr.len, jsonStr });
}

pub fn Dispatcher(comptime ContextType: type) type {
    return struct {
        const Self = @This();

        map: Map,
        context: *ContextType,
        alloc: *mem.Allocator,

        pub const DispatchError = error{MethodNotFound};
        pub const MethodError = error{
            InvalidParams,
            InvalidRequest,
            InternalError,
        };
        pub const Error = DispatchError || MethodError;

        pub const Method = fn (*ContextType, types.Request, *mem.Allocator) anyerror!void;
        pub const Map = std.StringHashMap(Method);

        pub fn init(context: *ContextType, alloc: *mem.Allocator) Self {
            return Self{
                .map = Map.init(alloc),
                .context = context,
                .alloc = alloc,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn registerRequest(self: *Self, method: []const u8, comptime ArgType: type, comptime callback: fn (*ContextType, ArgType, types.RequestId) anyerror!void) !void {
            const methodStruct = struct {
                pub fn f(ctx: *ContextType, req: types.Request, alloc: *mem.Allocator) anyerror!void {
                    if (req.id != .Defined) {
                        return MethodError.InvalidRequest;
                    }
                    var deserialized = serial.deserialize(ArgType, req.params, alloc) catch |err| switch (err) {
                        error.OutOfMemory => return MethodError.InternalError,
                        else => return MethodError.InvalidParams,
                    };
                    defer deserialized.deinit();
                    try callback(ctx, deserialized.result, req.id.Defined);
                }
            };
            _ = try self.map.put(method, methodStruct.f);
        }

        pub fn registerNotification(self: *Self, method: []const u8, comptime ArgType: type, comptime callback: fn (*ContextType, ArgType) anyerror!void) !void {
            const methodStruct = struct {
                pub fn f(ctx: *ContextType, req: types.Request, alloc: *mem.Allocator) anyerror!void {
                    if (req.id != .NotDefined) {
                        return MethodError.InvalidRequest;
                    }
                    var deserialized = serial.deserialize(ArgType, req.params, alloc) catch |err| switch (err) {
                        error.OutOfMemory => return MethodError.InternalError,
                        else => return MethodError.InvalidParams,
                    };
                    defer deserialized.deinit();
                    try callback(ctx, deserialized.result);
                }
            };
            _ = try self.map.put(method, methodStruct.f);
        }

        pub fn dispatch(self: *Self, message: types.Request) Error!void {
            debug.warn("{}\n", .{message.method});
            if (self.map.getValue(message.method)) |method| {
                method(self.context, message, self.alloc) catch |err| switch (err) {
                    error.InvalidParams => return error.InvalidParams,
                    error.InvalidRequest => return error.InvalidRequest,
                    else => return error.InternalError,
                };
            } else {
                return error.MethodNotFound;
            }
        }
    };
}
