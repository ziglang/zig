const std = @import("std");

pub const GET = struct {
    key: []const u8,

    pub fn init(key: []const u8) GET {
        return .{ .key = key };
    }

    pub const Redis = struct {
        pub const Command = struct {
            pub fn serialize(self: GET, comptime rootSerializer: type) void {
                return rootSerializer.serializeCommand(.{ "GET", self.key });
            }
        };
    };
};

pub fn isCommand(comptime T: type) bool {
    const tid = @typeInfo(T);
    return (tid == .Struct or tid == .Enum or tid == .Union) and
        @hasDecl(T, "Redis") and @hasDecl(T.Redis, "Command");
}

pub const ArgSerializer = struct {
    pub fn serializeCommand(command: anytype) void {
        const CmdT = @TypeOf(command);

        if (comptime isCommand(CmdT)) {
            // COMMENTING THE NEXT LINE REMOVES THE ERROR
            return CmdT.Redis.Command.serialize(command, ArgSerializer);
        }
    }
};

test "fixed" {
    ArgSerializer.serializeCommand(GET.init("banana"));
}
