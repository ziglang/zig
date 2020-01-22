const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const json = std.json;

const serial = @import("json_serialize.zig");
const types = @import("types.zig");

// JSON RPC 2.0
// TODO batching support?

/// Float or Null not recommended by the standard
pub const Id = union(enum) {
    String: types.String,
    Integer: types.Integer,
    Float: types.Float,
};

pub const Request = struct {
    jsonrpc: types.String = "2.0",
    method: types.String,

    /// Must be an Array or an Object
    params: json.Value,
    id: serial.MaybeDefined(?Id) = .NotDefined,

    pub fn validate(self: *const Request) bool {
        if (!mem.eql(u8, self.jsonrpc, "2.0")) {
            return false;
        }
        switch (self.params) {
            .Object, .Array => {},
            else => return false,
        }

        return true;
    }
};

pub const Response = struct {
    jsonrpc: types.String = "2.0",
    @"error": serial.MaybeDefined(Error) = .NotDefined,
    result: serial.MaybeDefined(json.Value) = .NotDefined,
    id: ?Id,

    pub const Error = struct {
        code: types.Integer,
        message: types.String,
        data: serial.MaybeDefined(json.Value),
    };

    pub fn validate(self: *const Response) bool {
        if (!mem.eql(u8, self.jsonrpc, "2.0")) {
            return false;
        }

        const errorDefined = self.@"error" == .Defined;
        const resultDefined = self.result == .Defined;

        // exactly one of them must be defined
        if (errorDefined == resultDefined) {
            return false;
        }

        return true;
    }
};

pub fn Dispatcher(comptime ContextType: type) type {
    return struct {
        const Self = @This();

        map: Map,
        context: *ContextType,

        pub const DispatchError = error{MethodNotFound};
        pub const MethodError = error{
            InvalidParams,
            InternalError,
        };
        pub const Error = DispatchError || MethodError;

        pub const Method = fn (*ContextType, Request) anyerror!void;
        pub const Map = std.StringHashMap(Method);

        pub fn init(context: *ContextType, alloc: *mem.Allocator) Self {
            return Self{
                .map = Map.init(alloc),
                .context = context,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn register(self: *Self, method: []const u8, callback: Method) !void {
            _ = try self.map.put(method, callback);
        }

        pub fn dispatch(self: *Self, message: Request) Error!void {
            debug.warn("{}\n", .{message.method});
            if (self.map.getValue(message.method)) |method| {
                method(self.context, message) catch |err| {
                    if(err == error.InvalidParams){
                        return error.InvalidParams;
                    } else {
                        return error.InternalError;
                    }
                };
            } else {
                return error.MethodNotFound;
            }
        }
    };
}
