const std = @import("std");

const Compilation = @import("Compilation.zig");
const LangOpts = @import("LangOpts.zig");
const Parser = @import("Parser.zig");
const target_util = @import("target.zig");
const TypeStore = @import("TypeStore.zig");
const QualType = TypeStore.QualType;
const Builder = TypeStore.Builder;
const TypeDescription = @import("Builtins/TypeDescription.zig");

const Properties = @import("Builtins/Properties.zig");
pub const Builtin = @import("Builtins/Builtin.zig").with(Properties);

const Expanded = struct {
    qt: QualType,
    builtin: Builtin,
};

const NameToTypeMap = std.StringHashMapUnmanaged(QualType);

const Builtins = @This();

_name_to_type_map: NameToTypeMap = .{},

pub fn deinit(b: *Builtins, gpa: std.mem.Allocator) void {
    b._name_to_type_map.deinit(gpa);
}

fn specForSize(comp: *const Compilation, size_bits: u32) TypeStore.Builder.Specifier {
    var qt: QualType = .short;
    if (qt.bitSizeof(comp) == size_bits) return .short;

    qt = .int;
    if (qt.bitSizeof(comp) == size_bits) return .int;

    qt = .long;
    if (qt.bitSizeof(comp) == size_bits) return .long;

    qt = .long_long;
    if (qt.bitSizeof(comp) == size_bits) return .long_long;

    unreachable;
}

fn createType(desc: TypeDescription, it: *TypeDescription.TypeIterator, comp: *Compilation) !QualType {
    var parser: Parser = undefined;
    parser.comp = comp;
    var builder: TypeStore.Builder = .{ .parser = &parser, .error_on_invalid = true };

    var require_native_int32 = false;
    var require_native_int64 = false;
    for (desc.prefix) |prefix| {
        switch (prefix) {
            .L => builder.combine(.long, 0) catch unreachable,
            .LL => builder.combine(.long_long, 0) catch unreachable,
            .LLL => {
                switch (builder.type) {
                    .none => builder.type = .int128,
                    .signed => builder.type = .sint128,
                    .unsigned => builder.type = .uint128,
                    else => unreachable,
                }
            },
            .Z => require_native_int32 = true,
            .W => require_native_int64 = true,
            .N => {
                std.debug.assert(desc.spec == .i);
                if (!target_util.isLP64(comp.target)) {
                    builder.combine(.long, 0) catch unreachable;
                }
            },
            .O => {
                builder.combine(.long, 0) catch unreachable;
                if (comp.target.os.tag != .opencl) {
                    builder.combine(.long, 0) catch unreachable;
                }
            },
            .S => builder.combine(.signed, 0) catch unreachable,
            .U => builder.combine(.unsigned, 0) catch unreachable,
            .I => {
                // Todo: compile-time constant integer
            },
        }
    }
    switch (desc.spec) {
        .v => builder.combine(.void, 0) catch unreachable,
        .b => builder.combine(.bool, 0) catch unreachable,
        .c => builder.combine(.char, 0) catch unreachable,
        .s => builder.combine(.short, 0) catch unreachable,
        .i => {
            if (require_native_int32) {
                builder.type = specForSize(comp, 32);
            } else if (require_native_int64) {
                builder.type = specForSize(comp, 64);
            } else {
                switch (builder.type) {
                    .int128, .sint128, .uint128 => {},
                    else => builder.combine(.int, 0) catch unreachable,
                }
            }
        },
        .h => builder.combine(.fp16, 0) catch unreachable,
        .x => builder.combine(.float16, 0) catch unreachable,
        .y => {
            // Todo: __bf16
            return .invalid;
        },
        .f => builder.combine(.float, 0) catch unreachable,
        .d => {
            if (builder.type == .long_long) {
                builder.type = .float128;
            } else {
                builder.combine(.double, 0) catch unreachable;
            }
        },
        .z => {
            std.debug.assert(builder.type == .none);
            builder.type = Builder.fromType(comp, comp.type_store.size);
        },
        .w => {
            std.debug.assert(builder.type == .none);
            builder.type = Builder.fromType(comp, comp.type_store.wchar);
        },
        .F => {
            std.debug.assert(builder.type == .none);
            builder.type = Builder.fromType(comp, comp.type_store.ns_constant_string);
        },
        .G => {
            // Todo: id
            return .invalid;
        },
        .H => {
            // Todo: SEL
            return .invalid;
        },
        .M => {
            // Todo: struct objc_super
            return .invalid;
        },
        .a => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.type = Builder.fromType(comp, comp.type_store.va_list);
        },
        .A => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            var va_list = comp.type_store.va_list;
            std.debug.assert(!va_list.is(comp, .array));
            builder.type = Builder.fromType(comp, va_list);
        },
        .V => |element_count| {
            std.debug.assert(desc.suffix.len == 0);
            const child_desc = it.next().?;
            const elem_qt = try createType(child_desc, undefined, comp);
            const vector_qt = try comp.type_store.put(comp.gpa, .{ .vector = .{
                .elem = elem_qt,
                .len = element_count,
            } });
            builder.type = .{ .other = vector_qt };
        },
        .q => {
            // Todo: scalable vector
            return .invalid;
        },
        .E => {
            // Todo: ext_vector (OpenCL vector)
            return .invalid;
        },
        .X => |child| {
            builder.combine(.complex, 0) catch unreachable;
            switch (child) {
                .float => builder.combine(.float, 0) catch unreachable,
                .double => builder.combine(.double, 0) catch unreachable,
                .longdouble => {
                    builder.combine(.long, 0) catch unreachable;
                    builder.combine(.double, 0) catch unreachable;
                },
            }
        },
        .Y => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.type = Builder.fromType(comp, comp.type_store.ptrdiff);
        },
        .P => {
            std.debug.assert(builder.type == .none);
            if (comp.type_store.file.isInvalid()) {
                return comp.type_store.file;
            }
            builder.type = Builder.fromType(comp, comp.type_store.file);
        },
        .J => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            if (comp.type_store.jmp_buf.isInvalid()) {
                return comp.type_store.jmp_buf;
            }
            builder.type = Builder.fromType(comp, comp.type_store.jmp_buf);
        },
        .SJ => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            if (comp.type_store.sigjmp_buf.isInvalid()) {
                return comp.type_store.sigjmp_buf;
            }
            builder.type = Builder.fromType(comp, comp.type_store.sigjmp_buf);
        },
        .K => {
            std.debug.assert(builder.type == .none);
            if (comp.type_store.ucontext_t.isInvalid()) {
                return comp.type_store.ucontext_t;
            }
            builder.type = Builder.fromType(comp, comp.type_store.ucontext_t);
        },
        .p => {
            std.debug.assert(builder.type == .none);
            std.debug.assert(desc.suffix.len == 0);
            builder.type = Builder.fromType(comp, comp.type_store.pid_t);
        },
        .@"!" => return .invalid,
    }
    for (desc.suffix) |suffix| {
        switch (suffix) {
            .@"*" => |address_space| {
                _ = address_space; // TODO: handle address space
                const pointer_qt = try comp.type_store.put(comp.gpa, .{ .pointer = .{
                    .child = builder.finish() catch unreachable,
                    .decayed = null,
                } });

                builder.@"const" = null;
                builder.@"volatile" = null;
                builder.restrict = null;
                builder.type = .{ .other = pointer_qt };
            },
            .C => builder.@"const" = 0,
            .D => builder.@"volatile" = 0,
            .R => builder.restrict = 0,
        }
    }
    return builder.finish() catch unreachable;
}

fn createBuiltin(comp: *Compilation, builtin: Builtin) !QualType {
    var it = TypeDescription.TypeIterator.init(builtin.properties.param_str);

    const ret_ty_desc = it.next().?;
    if (ret_ty_desc.spec == .@"!") {
        // Todo: handle target-dependent definition
    }
    const ret_ty = try createType(ret_ty_desc, &it, comp);
    var param_count: usize = 0;
    var params: [Builtin.max_param_count]TypeStore.Type.Func.Param = undefined;
    while (it.next()) |desc| : (param_count += 1) {
        params[param_count] = .{ .name_tok = 0, .qt = try createType(desc, &it, comp), .name = .empty, .node = .null };
    }

    return comp.type_store.put(comp.gpa, .{ .func = .{
        .return_type = ret_ty,
        .kind = if (builtin.properties.isVarArgs()) .variadic else .normal,
        .params = params[0..param_count],
    } });
}

/// Asserts that the builtin has already been created
pub fn lookup(b: *const Builtins, name: []const u8) Expanded {
    const builtin = Builtin.fromName(name).?;
    const qt = b._name_to_type_map.get(name).?;
    return .{ .builtin = builtin, .qt = qt };
}

pub fn getOrCreate(b: *Builtins, comp: *Compilation, name: []const u8) !?Expanded {
    const qt = b._name_to_type_map.get(name) orelse {
        const builtin = Builtin.fromName(name) orelse return null;
        if (!comp.hasBuiltinFunction(builtin)) return null;

        try b._name_to_type_map.ensureUnusedCapacity(comp.gpa, 1);
        const qt = try createBuiltin(comp, builtin);
        b._name_to_type_map.putAssumeCapacity(name, qt);

        return .{
            .builtin = builtin,
            .qt = qt,
        };
    };
    const builtin = Builtin.fromName(name).?;
    return .{ .builtin = builtin, .qt = qt };
}

pub const Iterator = struct {
    index: u16 = 1,
    name_buf: [Builtin.longest_name]u8 = undefined,

    pub const Entry = struct {
        /// Memory of this slice is overwritten on every call to `next`
        name: []const u8,
        builtin: Builtin,
    };

    pub fn next(self: *Iterator) ?Entry {
        if (self.index > Builtin.data.len) return null;
        const index = self.index;
        const data_index = index - 1;
        self.index += 1;
        return .{
            .name = Builtin.nameFromUniqueIndex(index, &self.name_buf),
            .builtin = Builtin.data[data_index],
        };
    }
};

test Iterator {
    const gpa = std.testing.allocator;
    var it = Iterator{};

    var seen: std.StringHashMapUnmanaged(Builtin) = .empty;
    defer seen.deinit(gpa);

    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    while (it.next()) |entry| {
        const index = Builtin.uniqueIndex(entry.name).?;
        var buf: [Builtin.longest_name]u8 = undefined;
        const name_from_index = Builtin.nameFromUniqueIndex(index, &buf);
        try std.testing.expectEqualStrings(entry.name, name_from_index);

        if (seen.contains(entry.name)) {
            std.debug.print("iterated over {s} twice\n", .{entry.name});
            std.debug.print("current data: {}\n", .{entry.builtin});
            std.debug.print("previous data: {}\n", .{seen.get(entry.name).?});
            return error.TestExpectedUniqueEntries;
        }
        try seen.put(gpa, try arena.dupe(u8, entry.name), entry.builtin);
    }
    try std.testing.expectEqual(@as(usize, Builtin.data.len), seen.count());
}

test "All builtins" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var comp = Compilation.init(std.testing.allocator, arena, undefined, std.fs.cwd());
    defer comp.deinit();

    try comp.type_store.initNamedTypes(&comp);
    comp.type_store.va_list = try comp.type_store.va_list.decay(&comp);

    var builtin_it = Iterator{};
    while (builtin_it.next()) |entry| {
        const name = try arena.dupe(u8, entry.name);
        if (try comp.builtins.getOrCreate(&comp, name)) |func_ty| {
            const get_again = (try comp.builtins.getOrCreate(&comp, name)).?;
            const found_by_lookup = comp.builtins.lookup(name);
            try std.testing.expectEqual(func_ty.builtin.tag, get_again.builtin.tag);
            try std.testing.expectEqual(func_ty.builtin.tag, found_by_lookup.builtin.tag);
        }
    }
}

test "Allocation failures" {
    const Test = struct {
        fn testOne(allocator: std.mem.Allocator) !void {
            var arena_state: std.heap.ArenaAllocator = .init(allocator);
            defer arena_state.deinit();
            const arena = arena_state.allocator();

            var comp = Compilation.init(allocator, arena, undefined, std.fs.cwd());
            defer comp.deinit();
            _ = try comp.generateBuiltinMacros(.include_system_defines);

            const num_builtins = 40;
            var builtin_it = Iterator{};
            for (0..num_builtins) |_| {
                const entry = builtin_it.next().?;
                _ = try comp.builtins.getOrCreate(&comp, entry.name);
            }
        }
    };

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.testOne, .{});
}
