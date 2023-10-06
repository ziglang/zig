const std = @import("std");
const Compilation = @import("Compilation.zig");
const Type = @import("Type.zig");
const BuiltinFunction = @import("builtins/BuiltinFunction.zig");
const TypeDescription = @import("builtins/TypeDescription.zig");
const target_util = @import("target.zig");
const StringId = @import("StringInterner.zig").StringId;
const LangOpts = @import("LangOpts.zig");
const Parser = @import("Parser.zig");

const Builtins = @This();

const Expanded = struct {
    ty: Type,
    builtin: BuiltinFunction,
};

const NameToTypeMap = std.StringHashMapUnmanaged(Type);

_name_to_type_map: NameToTypeMap = .{},

pub fn deinit(b: *Builtins, gpa: std.mem.Allocator) void {
    b._name_to_type_map.deinit(gpa);
}

fn specForSize(comp: *const Compilation, size_bits: u32) Type.Builder.Specifier {
    var ty = Type{ .specifier = .short };
    if (ty.sizeof(comp).? * 8 == size_bits) return .short;

    ty.specifier = .int;
    if (ty.sizeof(comp).? * 8 == size_bits) return .int;

    ty.specifier = .long;
    if (ty.sizeof(comp).? * 8 == size_bits) return .long;

    ty.specifier = .long_long;
    if (ty.sizeof(comp).? * 8 == size_bits) return .long_long;

    unreachable;
}

fn createType(desc: TypeDescription, it: *TypeDescription.TypeIterator, comp: *const Compilation, allocator: std.mem.Allocator) !Type {
    var builder: Type.Builder = .{ .error_on_invalid = true };
    var require_native_int32 = false;
    var require_native_int64 = false;
    for (desc.prefix) |prefix| {
        switch (prefix) {
            .L => builder.combine(undefined, .long, 0) catch unreachable,
            .LL => {
                builder.combine(undefined, .long, 0) catch unreachable;
                builder.combine(undefined, .long, 0) catch unreachable;
            },
            .LLL => {
                switch (builder.specifier) {
                    .none => builder.specifier = .int128,
                    .signed => builder.specifier = .sint128,
                    .unsigned => builder.specifier = .uint128,
                    else => unreachable,
                }
            },
            .Z => require_native_int32 = true,
            .W => require_native_int64 = true,
            .N => {
                std.debug.assert(desc.spec == .i);
                if (!target_util.isLP64(comp.target)) {
                    builder.combine(undefined, .long, 0) catch unreachable;
                }
            },
            .O => {
                builder.combine(undefined, .long, 0) catch unreachable;
                if (comp.target.os.tag != .opencl) {
                    builder.combine(undefined, .long, 0) catch unreachable;
                }
            },
            .S => builder.combine(undefined, .signed, 0) catch unreachable,
            .U => builder.combine(undefined, .unsigned, 0) catch unreachable,
            .I => {
                // Todo: compile-time constant integer
            },
        }
    }
    switch (desc.spec) {
        .v => builder.combine(undefined, .void, 0) catch unreachable,
        .b => builder.combine(undefined, .bool, 0) catch unreachable,
        .c => builder.combine(undefined, .char, 0) catch unreachable,
        .s => builder.combine(undefined, .short, 0) catch unreachable,
        .i => {
            if (require_native_int32) {
                builder.specifier = specForSize(comp, 32);
            } else if (require_native_int64) {
                builder.specifier = specForSize(comp, 64);
            } else {
                switch (builder.specifier) {
                    .int128, .sint128, .uint128 => {},
                    else => builder.combine(undefined, .int, 0) catch unreachable,
                }
            }
        },
        .h => builder.combine(undefined, .fp16, 0) catch unreachable,
        .x => {
            // Todo: _Float16
            return .{ .specifier = .invalid };
        },
        .y => {
            // Todo: __bf16
            return .{ .specifier = .invalid };
        },
        .f => builder.combine(undefined, .float, 0) catch unreachable,
        .d => {
            if (builder.specifier == .long_long) {
                builder.specifier = .float128;
            } else {
                builder.combine(undefined, .double, 0) catch unreachable;
            }
        },
        .z => {
            std.debug.assert(builder.specifier == .none);
            builder.specifier = Type.Builder.fromType(comp.types.size);
        },
        .w => {
            std.debug.assert(builder.specifier == .none);
            builder.specifier = Type.Builder.fromType(comp.types.wchar);
        },
        .F => {
            std.debug.assert(builder.specifier == .none);
            builder.specifier = Type.Builder.fromType(comp.types.ns_constant_string.ty);
        },
        .a => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.specifier = Type.Builder.fromType(comp.types.va_list);
        },
        .A => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            var va_list = comp.types.va_list;
            if (va_list.isArray()) va_list.decayArray();
            builder.specifier = Type.Builder.fromType(va_list);
        },
        .V => |element_count| {
            std.debug.assert(desc.suffix.len == 0);
            const child_desc = it.next().?;
            const child_ty = try createType(child_desc, undefined, comp, allocator);
            const arr_ty = try allocator.create(Type.Array);
            arr_ty.* = .{
                .len = element_count,
                .elem = child_ty,
            };
            const vector_ty = .{ .specifier = .vector, .data = .{ .array = arr_ty } };
            builder.specifier = Type.Builder.fromType(vector_ty);
        },
        .q => {
            // Todo: scalable vector
            return .{ .specifier = .invalid };
        },
        .E => {
            // Todo: ext_vector (OpenCL vector)
            return .{ .specifier = .invalid };
        },
        .X => |child| {
            builder.combine(undefined, .complex, 0) catch unreachable;
            switch (child) {
                .float => builder.combine(undefined, .float, 0) catch unreachable,
                .double => builder.combine(undefined, .double, 0) catch unreachable,
                .longdouble => {
                    builder.combine(undefined, .long, 0) catch unreachable;
                    builder.combine(undefined, .double, 0) catch unreachable;
                },
            }
        },
        .Y => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.specifier = Type.Builder.fromType(comp.types.ptrdiff);
        },
        .P => {
            std.debug.assert(builder.specifier == .none);
            if (comp.types.file.specifier == .invalid) {
                return comp.types.file;
            }
            builder.specifier = Type.Builder.fromType(comp.types.file);
        },
        .J => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            if (comp.types.jmp_buf.specifier == .invalid) {
                return comp.types.jmp_buf;
            }
            builder.specifier = Type.Builder.fromType(comp.types.jmp_buf);
        },
        .SJ => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            if (comp.types.sigjmp_buf.specifier == .invalid) {
                return comp.types.sigjmp_buf;
            }
            builder.specifier = Type.Builder.fromType(comp.types.sigjmp_buf);
        },
        .K => {
            std.debug.assert(builder.specifier == .none);
            if (comp.types.ucontext_t.specifier == .invalid) {
                return comp.types.ucontext_t;
            }
            builder.specifier = Type.Builder.fromType(comp.types.ucontext_t);
        },
        .p => {
            std.debug.assert(builder.specifier == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.specifier = Type.Builder.fromType(comp.types.pid_t);
        },
        .@"!" => return .{ .specifier = .invalid },
    }
    for (desc.suffix) |suffix| {
        switch (suffix) {
            .@"*" => |address_space| {
                _ = address_space; // TODO: handle address space
                const elem_ty = try allocator.create(Type);
                elem_ty.* = builder.finish(undefined) catch unreachable;
                const ty = Type{
                    .specifier = .pointer,
                    .data = .{ .sub_type = elem_ty },
                };
                builder.qual = .{};
                builder.specifier = Type.Builder.fromType(ty);
            },
            .C => builder.qual.@"const" = 0,
            .D => builder.qual.@"volatile" = 0,
            .R => builder.qual.restrict = 0,
        }
    }
    return builder.finish(undefined) catch unreachable;
}

fn createBuiltin(comp: *const Compilation, builtin: BuiltinFunction, type_arena: std.mem.Allocator) !Type {
    var it = TypeDescription.TypeIterator.init(builtin.param_str);

    const ret_ty_desc = it.next().?;
    if (ret_ty_desc.spec == .@"!") {
        // Todo: handle target-dependent definition
    }
    const ret_ty = try createType(ret_ty_desc, &it, comp, type_arena);
    var param_count: usize = 0;
    var params: [BuiltinFunction.MaxParamCount]Type.Func.Param = undefined;
    while (it.next()) |desc| : (param_count += 1) {
        params[param_count] = .{ .name_tok = 0, .ty = try createType(desc, &it, comp, type_arena), .name = .empty };
    }

    const duped_params = try type_arena.dupe(Type.Func.Param, params[0..param_count]);
    const func = try type_arena.create(Type.Func);

    func.* = .{
        .return_type = ret_ty,
        .params = duped_params,
    };
    return .{
        .specifier = if (builtin.isVarArgs()) .var_args_func else .func,
        .data = .{ .func = func },
    };
}

/// Asserts that the builtin has already been created
pub fn lookup(b: *const Builtins, name: []const u8) Expanded {
    @setEvalBranchQuota(10_000);
    const builtin = BuiltinFunction.fromTag(std.meta.stringToEnum(BuiltinFunction.Tag, name).?);
    const ty = b._name_to_type_map.get(name).?;
    return .{
        .builtin = builtin,
        .ty = ty,
    };
}

pub fn getOrCreate(b: *Builtins, comp: *Compilation, name: []const u8, type_arena: std.mem.Allocator) !?Expanded {
    const ty = b._name_to_type_map.get(name) orelse {
        @setEvalBranchQuota(10_000);
        const tag = std.meta.stringToEnum(BuiltinFunction.Tag, name) orelse return null;
        const builtin = BuiltinFunction.fromTag(tag);
        if (!comp.hasBuiltinFunction(builtin)) return null;

        try b._name_to_type_map.ensureUnusedCapacity(comp.gpa, 1);
        const ty = try createBuiltin(comp, builtin, type_arena);
        b._name_to_type_map.putAssumeCapacity(name, ty);

        return .{
            .builtin = builtin,
            .ty = ty,
        };
    };
    const builtin = BuiltinFunction.fromTag(std.meta.stringToEnum(BuiltinFunction.Tag, name).?);
    return .{
        .builtin = builtin,
        .ty = ty,
    };
}

test "All builtins" {
    var comp = Compilation.init(std.testing.allocator);
    defer comp.deinit();
    _ = try comp.generateBuiltinMacros();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const type_arena = arena.allocator();

    for (0..@typeInfo(BuiltinFunction.Tag).Enum.fields.len) |i| {
        const tag: BuiltinFunction.Tag = @enumFromInt(i);
        const name = @tagName(tag);
        if (try comp.builtins.getOrCreate(&comp, name, type_arena)) |func_ty| {
            const get_again = (try comp.builtins.getOrCreate(&comp, name, std.testing.failing_allocator)).?;
            const found_by_lookup = comp.builtins.lookup(name);
            try std.testing.expectEqual(func_ty.builtin.tag, get_again.builtin.tag);
            try std.testing.expectEqual(func_ty.builtin.tag, found_by_lookup.builtin.tag);
        }
    }
}

test "Allocation failures" {
    const Test = struct {
        fn testOne(allocator: std.mem.Allocator) !void {
            var comp = Compilation.init(allocator);
            defer comp.deinit();
            _ = try comp.generateBuiltinMacros();
            var arena = std.heap.ArenaAllocator.init(comp.gpa);
            defer arena.deinit();

            const type_arena = arena.allocator();

            const num_builtins = 40;
            for (0..num_builtins) |i| {
                const tag: BuiltinFunction.Tag = @enumFromInt(i);
                const name = @tagName(tag);
                _ = try comp.builtins.getOrCreate(&comp, name, type_arena);
            }
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.testOne, .{});
}
