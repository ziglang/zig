const std = @import("std");
const Allocator = std.mem.Allocator;

const spec = @import("spirv/spec.zig");
const Module = @import("../Module.zig");
const Decl = Module.Decl;

pub fn writeInstruction(code: *std.ArrayList(u32), instr: spec.Opcode, args: []const u32) !void {
    const word_count = @intCast(u32, args.len + 1);
    try code.append((word_count << 16) | @enumToInt(instr));
    try code.appendSlice(args);
}

pub const SPIRVModule = struct {
    next_id: u32 = 0,
    free_id_list: std.ArrayList(u32),

    pub fn init(allocator: *Allocator) SPIRVModule {
        return .{
            .free_id_list = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *SPIRVModule) void {
        self.free_id_list.deinit();
    }

    pub fn allocId(self: *SPIRVModule) u32 {
        if (self.free_id_list.popOrNull()) |id| return id;

        defer self.next_id += 1;
        return self.next_id;
    }

    pub fn freeId(self: *SPIRVModule, id: u32) void {
        if (id + 1 == self.next_id) {
            self.next_id -= 1;
        } else {
            // If no more memory to append the id to the free list, just ignore it.
            self.free_id_list.append(id) catch {};
        }
    }

    pub fn idBound(self: *SPIRVModule) u32 {
        return self.next_id;
    }

    pub fn genDecl(self: SPIRVModule, id: u32, code: *std.ArrayList(u32), decl: *Decl) !void {}
};
