const std = @import("std");
const builtin = @import("builtin");

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_llvm and
        builtin.cpu.arch == .aarch64 and builtin.os.tag == .windows) return error.SkipZigTest;
    ArgSerializer.serializeCommand(GET.init("banana"));
}
