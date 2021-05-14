const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.codegen);

const Target = std.Target;

const spec = @import("spirv/spec.zig");
const Module = @import("../Module.zig");
const Decl = Module.Decl;
const Type = @import("../type.zig").Type;
const LazySrcLoc = Module.LazySrcLoc;

pub const TypeMap = std.HashMap(Type, u32, Type.hash, Type.eql, std.hash_map.default_max_load_percentage);

pub fn writeInstruction(code: *std.ArrayList(u32), instr: spec.Opcode, args: []const u32) !void {
    const word_count = @intCast(u32, args.len + 1);
    try code.append((word_count << 16) | @enumToInt(instr));
    try code.appendSlice(args);
}

/// This structure represents a SPIR-V binary module being compiled, and keeps track of relevant information
/// such as code for the different logical sections, and the next result-id.
pub const SPIRVModule = struct {
    next_result_id: u32,
    types_and_globals: std.ArrayList(u32),
    fn_decls: std.ArrayList(u32),

    pub fn init(allocator: *Allocator) SPIRVModule {
        return .{
            .next_result_id = 0,
            .types_and_globals = std.ArrayList(u32).init(allocator),
            .fn_decls = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *SPIRVModule) void {
        self.types_and_globals.deinit();
        self.fn_decls.deinit();
    }

    pub fn allocResultId(self: *SPIRVModule) u32 {
        defer self.next_result_id += 1;
        return self.next_result_id;
    }

    pub fn resultIdBound(self: *SPIRVModule) u32 {
        return self.next_result_id;
    }
};

/// This structure is used to compile a declaration, and contains all relevant meta-information to deal with that.
pub const DeclGen = struct {
    module: *Module,
    spv: *SPIRVModule,

    types: TypeMap,

    decl: *Decl,
    error_msg: ?*Module.ErrorMsg,

    fn fail(self: *DeclGen, src: LazySrcLoc, comptime format: []const u8, args: anytype) error{ AnalysisFail, OutOfMemory } {
        @setCold(true);
        const src_loc = src.toSrcLocWithDecl(self.decl);
        self.error_msg = try Module.ErrorMsg.create(self.module.gpa, src_loc, format, args);
        return error.AnalysisFail;
    }

    /// SPIR-V requires enabling specific integer sizes through capabilities, and so if they are not enabled, we need
    /// to emulate them in other instructions/types. This function returns, given an integer bit width (signed or unsigned, sign
    /// included), the width of the underlying type which represents it, given the enabled features for the current target.
    /// If the result is `null`, the largest type the target platform supports natively is not able to perform computations using
    /// that size. In this case, multiple elements of the largest type should be used.
    /// The backing type will be chosen as the smallest supported integer larger or equal to it in number of bits.
    /// The result is valid to be used with OpTypeInt.
    /// TODO: The extension SPV_INTEL_arbitrary_precision_integers allows any integer size (at least up to 32 bits).
    /// TODO: This probably needs an ABI-version as well (especially in combination with SPV_INTEL_arbitrary_precision_integers).
    fn backingIntBits(self: *DeclGen, bits: u32) ?u32 {
        // TODO: Figure out what to do with u0/i0.
        std.debug.assert(bits != 0);

        const target = self.module.getTarget();

        // 8, 16 and 64-bit integers require the Int8, Int16 and Inr64 capabilities respectively.
        const ints = [_]struct{ bits: u32, feature: ?Target.spirv.Feature } {
            .{ .bits = 8, .feature = .Int8 },
            .{ .bits = 16, .feature = .Int16 },
            .{ .bits = 32, .feature = null },
            .{ .bits = 64, .feature = .Int64 },
        };

        for (ints) |int| {
            const has_feature = if (int.feature) |feature|
                Target.spirv.featureSetHas(target.cpu.features, feature)
            else
                true;

            if (bits <= int.bits and has_feature) {
                return int.bits;
            }
        }

        return null;
    }

    pub fn getOrGenType(self: *DeclGen, t: Type) !u32 {
        // We can't use getOrPut here so we can recursively generate types.
        if (self.types.get(t)) |already_generated| {
            return already_generated;
        }

        const result = self.spv.allocResultId();

        switch (t.zigTypeTag()) {
            .Void => try writeInstruction(&self.spv.types_and_globals, .OpTypeVoid, &[_]u32{ result }),
            .Bool => try writeInstruction(&self.spv.types_and_globals, .OpTypeBool, &[_]u32{ result }),
            .Int => {
                const int_info = t.intInfo(self.module.getTarget());
                const backing_bits = self.backingIntBits(int_info.bits) orelse
                    return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement fallback for integer of {} bits", .{ int_info.bits });

                try writeInstruction(&self.spv.types_and_globals, .OpTypeInt, &[_]u32{
                    result,
                    backing_bits,
                    switch (int_info.signedness) {
                        .unsigned => 0,
                        .signed => 1,
                    },
                });
            },
            // TODO: Capabilities.
            .Float => try writeInstruction(&self.spv.types_and_globals, .OpTypeFloat, &[_]u32{ result, t.floatBits(self.module.getTarget()) }),
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => |tag| return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: implement type with tag {}", .{ tag }),
        }

        try self.types.put(t, result);
        return result;
    }

    pub fn gen(self: *DeclGen) !void {
        const typed_value = self.decl.typed_value.most_recent.typed_value;

        switch (typed_value.ty.zigTypeTag()) {
            .Fn => {
                log.debug("Generating code for function '{s}'", .{ std.mem.spanZ(self.decl.name) });

                _ = try self.getOrGenType(typed_value.ty.fnReturnType());
            },
            else => |tag| return self.fail(.{ .node_offset = 0 }, "TODO: SPIR-V backend: generate decl with tag {}", .{ tag }),
        }
    }
};
