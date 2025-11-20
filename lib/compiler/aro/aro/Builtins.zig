const std = @import("std");

const Compilation = @import("Compilation.zig");
const LangOpts = @import("LangOpts.zig");
const Parser = @import("Parser.zig");
const Target = @import("Target.zig");
const TypeStore = @import("TypeStore.zig");
const QualType = TypeStore.QualType;
const Builder = TypeStore.Builder;
const TypeDescription = @import("Builtins/TypeDescription.zig");
const properties = @import("Builtins/properties.zig");

const BuiltinBase = struct {
    param_str: [*:0]const u8,
    language: properties.Language = .all_languages,
    attributes: properties.Attributes = .{},
    header: properties.Header = .none,
};

const BuiltinTarget = struct {
    param_str: [*:0]const u8,
    language: properties.Language = .all_languages,
    attributes: properties.Attributes = .{},
    header: properties.Header = .none,
    features: ?[*:0]const u8 = null,
};

const aarch64 = @import("Builtins/aarch64.zig").with(BuiltinTarget);
const amdgcn = @import("Builtins/amdgcn.zig").with(BuiltinTarget);
const arm = @import("Builtins/arm.zig").with(BuiltinTarget);
const bpf = @import("Builtins/bpf.zig").with(BuiltinTarget);
const common = @import("Builtins/common.zig").with(BuiltinBase);
const hexagon = @import("Builtins/hexagon.zig").with(BuiltinTarget);
const loongarch = @import("Builtins/loongarch.zig").with(BuiltinTarget);
const mips = @import("Builtins/mips.zig").with(BuiltinBase);
const nvptx = @import("Builtins/nvptx.zig").with(BuiltinTarget);
const powerpc = @import("Builtins/powerpc.zig").with(BuiltinTarget);
const riscv = @import("Builtins/riscv.zig").with(BuiltinTarget);
const s390x = @import("Builtins/s390x.zig").with(BuiltinTarget);
const ve = @import("Builtins/ve.zig").with(BuiltinBase);
const x86_64 = @import("Builtins/x86_64.zig").with(BuiltinTarget);
const x86 = @import("Builtins/x86.zig").with(BuiltinTarget);
const xcore = @import("Builtins/xcore.zig").with(BuiltinBase);

pub const Tag = union(enum) {
    aarch64: aarch64.Tag,
    amdgcn: amdgcn.Tag,
    arm: arm.Tag,
    bpf: bpf.Tag,
    common: common.Tag,
    hexagon: hexagon.Tag,
    loongarch: loongarch.Tag,
    mips: mips.Tag,
    nvptx: nvptx.Tag,
    powerpc: powerpc.Tag,
    riscv: riscv.Tag,
    s390x: s390x.Tag,
    ve: ve.Tag,
    x86_64: x86_64.Tag,
    x86: x86.Tag,
    xcore: xcore.Tag,
};

pub const Expanded = struct {
    tag: Tag,
    qt: QualType,
    language: properties.Language = .all_languages,
    attributes: properties.Attributes = .{},
    header: properties.Header = .none,
};

const Builtins = @This();

_name_to_type_map: std.StringHashMapUnmanaged(Expanded) = .{},

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
    var actual_suffix = desc.suffix;

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
                if (!comp.target.isLP64()) {
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
        .y => builder.combine(.bf16, 0) catch unreachable,
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
            var child_desc = it.next().?;
            actual_suffix = child_desc.suffix;
            child_desc.suffix = &.{};
            const elem_qt = try createType(child_desc, undefined, comp);
            const vector_qt = try comp.type_store.put(comp.gpa, .{ .vector = .{
                .elem = elem_qt,
                .len = element_count,
            } });
            builder.type = .{ .other = vector_qt };
        },
        .Q => {
            // Todo: target builtin type
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
    }
    for (actual_suffix) |suffix| {
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

fn createBuiltin(comp: *Compilation, param_str: [*:0]const u8) !QualType {
    var it = TypeDescription.TypeIterator.init(param_str);

    const ret_ty_desc = it.next().?;
    const ret_ty = try createType(ret_ty_desc, &it, comp);
    var param_count: usize = 0;
    var params: [32]TypeStore.Type.Func.Param = undefined;
    while (it.next()) |desc| : (param_count += 1) {
        params[param_count] = .{ .name_tok = 0, .qt = try createType(desc, &it, comp), .name = .empty, .node = .null };
    }

    return comp.type_store.put(comp.gpa, .{ .func = .{
        .return_type = ret_ty,
        .kind = if (properties.isVarArgs(param_str)) .variadic else .normal,
        .params = params[0..param_count],
    } });
}

/// Asserts that the builtin has already been created
pub fn lookup(b: *const Builtins, name: []const u8) Expanded {
    return b._name_to_type_map.get(name).?;
}

pub fn getOrCreate(b: *Builtins, comp: *Compilation, name: []const u8) !?Expanded {
    if (b._name_to_type_map.get(name)) |expanded| return expanded;

    const builtin = fromName(comp, name) orelse return null;
    if (builtin.features) |_| {
        // TODO check features
    }

    try b._name_to_type_map.ensureUnusedCapacity(comp.gpa, 1);
    const expanded: Expanded = .{
        .tag = builtin.tag,
        .qt = try createBuiltin(comp, builtin.param_str),
        .attributes = builtin.attributes,
        .header = builtin.header,
        .language = builtin.language,
    };
    b._name_to_type_map.putAssumeCapacity(name, expanded);
    return expanded;
}

pub const FromName = struct {
    tag: Tag,
    param_str: [*:0]const u8,
    language: properties.Language = .all_languages,
    attributes: properties.Attributes = .{},
    header: properties.Header = .none,
    features: ?[*:0]const u8 = null,
};

pub fn fromName(comp: *Compilation, name: []const u8) ?FromName {
    if (fromNameExtra(name, .common)) |found| return found;
    switch (comp.target.cpu.arch) {
        .aarch64, .aarch64_be => if (fromNameExtra(name, .aarch64)) |found| return found,
        .amdgcn => if (fromNameExtra(name, .amdgcn)) |found| return found,
        .arm, .armeb, .thumb, .thumbeb => if (fromNameExtra(name, .arm)) |found| return found,
        .bpfeb, .bpfel => if (fromNameExtra(name, .bpf)) |found| return found,
        .hexagon => if (fromNameExtra(name, .hexagon)) |found| return found,
        .loongarch32, .loongarch64 => if (fromNameExtra(name, .loongarch)) |found| return found,
        .mips64, .mips64el, .mips, .mipsel => if (fromNameExtra(name, .mips)) |found| return found,
        .nvptx, .nvptx64 => if (fromNameExtra(name, .nvptx)) |found| return found,
        .powerpc64, .powerpc64le, .powerpc, .powerpcle => if (fromNameExtra(name, .powerpc)) |found| return found,
        .riscv32, .riscv32be, .riscv64, .riscv64be => if (fromNameExtra(name, .riscv)) |found| return found,
        .s390x => if (fromNameExtra(name, .s390x)) |found| return found,
        .ve => if (fromNameExtra(name, .ve)) |found| return found,
        .xcore => if (fromNameExtra(name, .xcore)) |found| return found,
        .x86_64 => {
            if (fromNameExtra(name, .x86_64)) |found| return found;
            if (fromNameExtra(name, .x86)) |found| return found;
        },
        .x86 => if (fromNameExtra(name, .x86)) |found| return found,
        else => {},
    }
    return null;
}

fn fromNameExtra(name: []const u8, comptime arch: std.meta.Tag(Tag)) ?FromName {
    const list = @field(@This(), @tagName(arch));
    const tag = list.tagFromName(name) orelse return null;
    const builtin = list.data[@intFromEnum(tag)];

    return .{
        .tag = @unionInit(Tag, @tagName(arch), tag),
        .param_str = builtin.param_str,
        .header = builtin.header,
        .language = builtin.language,
        .attributes = builtin.attributes,
        .features = if (@hasField(@TypeOf(builtin), "features")) builtin.features else null,
    };
}

test "all builtins" {
    const list_names = comptime std.meta.fieldNames(Tag);
    inline for (list_names) |list_name| {
        const list = @field(Builtins, list_name);
        for (list.data, 0..) |builtin, index| {
            {
                var it = TypeDescription.TypeIterator.init(builtin.param_str);
                while (it.next()) |_| {}
            }
            if (@hasField(@TypeOf(builtin), "features")) {
                const corrected_name = comptime if (std.mem.eql(u8, list_name, "x86_64")) "x86" else list_name;
                const features = &@field(std.Target, corrected_name).all_features;

                const feature_string = builtin.features orelse continue;
                var it = std.mem.tokenizeAny(u8, std.mem.span(feature_string), "()|,");

                outer: while (it.next()) |feature| {
                    for (features) |valid_feature| {
                        if (std.mem.eql(u8, feature, valid_feature.name)) continue :outer;
                    }
                    std.debug.panic("unknown feature {s} on {t}\n", .{ feature, @as(list.Tag, @enumFromInt(index)) });
                }
            }
        }
    }
}
