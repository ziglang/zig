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

pub fn writeOpcode(code: *std.ArrayList(u32), opcode: spec.Opcode, arg_count: u32) !void {
    const word_count = arg_count + 1;
    try code.append((word_count << 16) | @enumToInt(opcode));
}

pub fn writeInstruction(code: *std.ArrayList(u32), opcode: spec.Opcode, args: []const u32) !void {
    try writeOpcode(code, opcode, @intCast(u32, args.len));
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
            .next_result_id = 1, // 0 is an invalid SPIR-V result ID.
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

    const Error = error{
        AnalysisFail,
        OutOfMemory
    };

    fn fail(self: *DeclGen, src: LazySrcLoc, comptime format: []const u8, args: anytype) Error {
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

    fn getOrGenType(self: *DeclGen, ty: Type) Error!u32 {
        // We can't use getOrPut here so we can recursively generate types.
        if (self.types.get(ty)) |already_generated| {
            return already_generated;
        }

        const target = self.module.getTarget();
        const code = &self.spv.types_and_globals;
        const result_id = self.spv.allocResultId();

        switch (ty.zigTypeTag()) {
            .Void => try writeInstruction(code, .OpTypeVoid, &[_]u32{ result_id }),
            .Bool => try writeInstruction(code, .OpTypeBool, &[_]u32{ result_id }),
            .Int => {
                const int_info = ty.intInfo(self.module.getTarget());
                const backing_bits = self.backingIntBits(int_info.bits) orelse
                    return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement fallback for {}", .{ ty });

                try writeInstruction(code, .OpTypeInt, &[_]u32{
                    result_id,
                    backing_bits,
                    switch (int_info.signedness) {
                        .unsigned => 0,
                        .signed => 1,
                    },
                });
            },
            .Float => {
                // We can (and want) not really emulate floating points with other floating point types like with the integer types,
                // so if the float is not supported, just return an error.
                const bits = ty.floatBits(target);
                const supported = switch (bits) {
                    16 => Target.spirv.featureSetHas(target.cpu.features, .Float16),
                    32 => true,
                    64 => Target.spirv.featureSetHas(target.cpu.features, .Float64),
                    else => false,
                };

                if (!supported) {
                    return self.fail(.{.node_offset = 0}, "Floating point width of {} bits is not supported for the current SPIR-V feature set", .{ bits });
                }

                try writeInstruction(code, .OpTypeFloat, &[_]u32{ result_id, bits });
            },
            .Fn => {
                // We only support zig-calling-convention functions, no varargs.
                if (ty.fnCallingConvention() != .Unspecified)
                    return self.fail(.{.node_offset = 0}, "Unsupported calling convention for SPIR-V", .{});
                if (ty.fnIsVarArgs())
                    return self.fail(.{.node_offset = 0}, "VarArgs unsupported for SPIR-V", .{});

                // In order to avoid a temporary here, first generate all the required types and then simply look them up
                // when generating the function type.
                const params = ty.fnParamLen();
                var i: usize = 0;
                while (i < params) : (i += 1) {
                    _ = try self.getOrGenType(ty.fnParamType(i));
                }

                const return_type_id = try self.getOrGenType(ty.fnReturnType());

                // result id + result type id + parameter type ids.
                try writeOpcode(code, .OpTypeFunction, 2 + @intCast(u32, ty.fnParamLen()) );
                try code.appendSlice(&.{ result_id, return_type_id });

                i = 0;
                while (i < params) : (i += 1) {
                    const param_type_id = self.types.get(ty.fnParamType(i)).?;
                    try code.append(param_type_id);
                }
            },
            .Null,
            .Undefined,
            .EnumLiteral,
            .ComptimeFloat,
            .ComptimeInt,
            .Type,
            => unreachable, // Must be const or comptime.

            .BoundFn => unreachable, // this type will be deleted from the language.

            else => |tag| return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: implement type {}", .{ tag }),
        }

        try self.types.put(ty, result_id);
        return result_id;
    }

    pub fn gen(self: *DeclGen) !void {
        const result_id = self.decl.fn_link.spirv.id;
        const tv = self.decl.typed_value.most_recent.typed_value;

        if (tv.val.castTag(.function)) |func_payload| {
            std.debug.assert(tv.ty.zigTypeTag() == .Fn);
            const prototype_id = try self.getOrGenType(tv.ty);
            try writeInstruction(&self.spv.fn_decls, .OpFunction, &[_]u32{
                self.types.get(tv.ty.fnReturnType()).?, // This type should be generated along with the prototype.
                result_id,
                @bitCast(u32, spec.FunctionControl{}), // TODO: We can set inline here if the type requires it.
                prototype_id,
            });

            // TODO: Parameters
            // TODO: Body

            try writeInstruction(&self.spv.fn_decls, .OpFunctionEnd, &[_]u32{});
        } else {
            return self.fail(.{.node_offset = 0}, "TODO: SPIR-V backend: generate decl type {}", .{ tv.ty.zigTypeTag() });
        }
    }
};
