const std = @import("std");
const debug = std.debug;
const mem = std.mem;
const json = std.json;

const serial = @import("json_serialize.zig");

// JSON RPC 2.0

pub const Request = struct {
    /// Must be "2.0"
    jsonrpc: []const u8,
    method: []const u8,
    /// Must be an Array or an Object
    params: json.Value,
    /// Must be a String, Number, or Null
    /// Float or Null not recommended by the standard
    id: serial.MaybeDefined(json.Value),

    pub fn validate(self: *const Request) bool {
        if(!mem.eql(u8, self.jsonrpc, "2.0")){
            return false;
        }
        switch(self.params){
            .Object, .Array => {},
            else => return false
        }
        switch(self.id){
            .Defined => |jsonVal| {
                switch(jsonVal){
                    .String, .Integer, .Float, .Null => {},
                    else => return false
                }
            },
            .NotDefined => {}
        }

        return true;
    }
};

pub const Response = struct {
    outcome: Outcome,
    id: json.Value,

    pub const Outcome = union(enum){
        Error: Error,
        Result: json.Value,

        pub const Error = struct {
            code: i64,
            message: []const u8,
            data: ?json.Value,
        };
    };
};

pub fn Dispatcher(comptime ContextType: type) type {
    return struct {
        const Self = @This();

        map: Map,
        context: *ContextType,

        pub const DispatchError = error{
            MethodNotFound,
        };
        pub const MethodError = error{
            InvalidParams,
            InternalError,
        };
        pub const Error = DispatchError || MethodError;
        
        pub const Method = fn(*ContextType, Request) MethodError!void;
        pub const Map = std.StringHashMap(Method);

        pub fn init(context: *ContextType, alloc: *mem.Allocator) Self {
            return Self {
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
            debug.warn("{}\n", message.method);
            if(self.map.getValue(message.method)) |method| {
                try method(self.context, message);
            } else {
                return error.MethodNotFound;
            }
        }
    };
}
