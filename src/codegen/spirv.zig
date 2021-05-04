const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);

const spec = @import("spirv/spec.zig");
const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;

pub const TypeMap = std.HashMap(Type, u32, Type.hash, Type.eql, std.hash_map.default_max_load_percentage);

pub fn writeInstruction(code: *std.ArrayList(u32), instr: spec.Opcode, args: []const u32) !void {
    const word_count = @intCast(u32, args.len + 1);
    try code.append((word_count << 16) | @enumToInt(instr));
    try code.appendSlice(args);
}

pub const SPIRVModule = struct {
    next_result_id: u32 = 0,

    target: std.Target,

    types: TypeMap,

    types_and_globals: std.ArrayList(u32),
    fn_decls: std.ArrayList(u32),

    pub fn init(target: std.Target, allocator: *Allocator) SPIRVModule {
        return .{
            .target = target,
            .types = TypeMap.init(allocator),
            .types_and_globals = std.ArrayList(u32).init(allocator),
            .fn_decls = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *SPIRVModule) void {
        self.fn_decls.deinit();
        self.types_and_globals.deinit();
        self.types.deinit();
        self.* = undefined;
    }

    pub fn allocResultId(self: *SPIRVModule) u32 {
        defer self.next_result_id += 1;
        return self.next_result_id;
    }

    pub fn resultIdBound(self: *SPIRVModule) u32 {
        return self.next_result_id;
    }

    pub fn getOrGenType(self: *SPIRVModule, t: Type) !u32 {
        // We can't use getOrPut here so we can recursively generate types.
        if (self.types.get(t)) |already_generated| {
            return already_generated;
        }

        const result = self.allocResultId();

        switch (t.zigTypeTag()) {
            .Void => try writeInstruction(&self.types_and_globals, .OpTypeVoid, &[_]u32{ result }),
            .Bool => try writeInstruction(&self.types_and_globals, .OpTypeBool, &[_]u32{ result }),
            .Int => {
                const int_info = t.intInfo(self.target);
                try writeInstruction(&self.types_and_globals, .OpTypeInt, &[_]u32{
                    result,
                    int_info.bits,
                    switch (int_info.signedness) {
                        .unsigned => 0,
                        .signed => 1,
                    },
                });
            },
            // TODO: Verify that floatBits() will be correct.
            .Float => try writeInstruction(&self.types_and_globals, .OpTypeFloat, &[_]u32{ result, t.floatBits(self.target) }),
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => return error.TODO,
        }

        try self.types.put(t, result);
        return result;
    }

    pub fn gen(self: *SPIRVModule, decl: *Decl) !void {
        const typed_value = decl.typed_value.most_recent.typed_value;

        switch (typed_value.ty.zigTypeTag()) {
            .Fn => {
                log.debug("Generating code for function '{s}'", .{ std.mem.spanZ(decl.name) });

                _ = try self.getOrGenType(typed_value.ty.fnReturnType());
            },
            else => return error.TODO,
        }
    }
};
