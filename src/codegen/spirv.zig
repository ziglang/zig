const std = @import("std");
const spec = @import("spirv/spec.zig");
const Module = @import("../Module.zig");
const Decl = Module.Decl;

pub const SPIRVModule = struct {
    // TODO: Also use a free list.
    next_id: u32 = 0,

    pub fn allocId(self: *SPIRVModule) u32 {
        defer self.next_id += 1;
        return self.next_id;
    }

    pub fn idBound(self: *SPIRVModule) u32 {
        return self.next_id;
    }

    pub fn genDecl(self: SPIRVModule, id: u32, code: *std.ArrayList(u32), decl: *Decl) !void {

    }
};
