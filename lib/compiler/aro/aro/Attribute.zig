const std = @import("std");
const mem = std.mem;
const ZigType = std.builtin.Type;
const CallingConvention = @import("../backend.zig").CallingConvention;
const Compilation = @import("Compilation.zig");
const Diagnostics = @import("Diagnostics.zig");
const Parser = @import("Parser.zig");
const Tree = @import("Tree.zig");
const TokenIndex = Tree.TokenIndex;
const QualType = @import("TypeStore.zig").QualType;
const Value = @import("Value.zig");

const Attribute = @This();

tag: Tag,
syntax: Syntax,
args: Arguments,

pub const Syntax = enum {
    c23,
    declspec,
    gnu,
    keyword,
};

pub const Kind = enum {
    c23,
    declspec,
    gnu,

    pub fn toSyntax(kind: Kind) Syntax {
        return switch (kind) {
            .c23 => .c23,
            .declspec => .declspec,
            .gnu => .gnu,
        };
    }
};

pub const Iterator = struct {
    source: ?struct {
        qt: QualType,
        comp: *const Compilation,
    },
    slice: []const Attribute,
    index: usize,

    pub fn initSlice(slice: []const Attribute) Iterator {
        return .{ .source = null, .slice = slice, .index = 0 };
    }

    pub fn initType(qt: QualType, comp: *const Compilation) Iterator {
        return .{ .source = .{ .qt = qt, .comp = comp }, .slice = &.{}, .index = 0 };
    }

    /// returns the next attribute as well as its index within the slice or current type
    /// The index can be used to determine when a nested type has been recursed into
    pub fn next(self: *Iterator) ?struct { Attribute, usize } {
        if (self.index < self.slice.len) {
            defer self.index += 1;
            return .{ self.slice[self.index], self.index };
        }
        if (self.source) |*source| {
            if (source.qt.isInvalid()) {
                self.source = null;
                return null;
            }
            loop: switch (source.qt.type(source.comp)) {
                .typeof => |typeof| continue :loop typeof.base.type(source.comp),
                .attributed => |attributed| {
                    self.slice = attributed.attributes;
                    self.index = 1;
                    source.qt = attributed.base;
                    return .{ self.slice[0], 0 };
                },
                .typedef => |typedef| continue :loop typedef.base.type(source.comp),
                else => self.source = null,
            }
        }
        return null;
    }
};

/// number of required arguments
pub fn requiredArgCount(attr: Tag) u32 {
    switch (attr) {
        inline else => |tag| {
            comptime var needed = 0;
            comptime {
                const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
                for (fields) |arg_field| {
                    if (!mem.eql(u8, arg_field.name, "__name_tok") and @typeInfo(arg_field.type) != .optional) needed += 1;
                }
            }
            return needed;
        },
    }
}

/// maximum number of args that can be passed
pub fn maxArgCount(attr: Tag) u32 {
    switch (attr) {
        inline else => |tag| {
            comptime var max = 0;
            comptime {
                const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
                for (fields) |arg_field| {
                    if (!mem.eql(u8, arg_field.name, "__name_tok")) max += 1;
                }
            }
            return max;
        },
    }
}

fn UnwrapOptional(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .optional => |optional| optional.child,
        else => T,
    };
}

pub const Formatting = struct {
    /// The quote char (single or double) to use when printing identifiers/strings corresponding
    /// to the enum in the first field of the `attr`. Identifier enums use single quotes, string enums
    /// use double quotes
    fn quoteChar(attr: Tag) []const u8 {
        switch (attr) {
            .calling_convention => unreachable,
            inline else => |tag| {
                const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;

                if (fields.len == 0) unreachable;
                const Unwrapped = UnwrapOptional(fields[0].type);
                if (@typeInfo(Unwrapped) != .@"enum") unreachable;

                return if (Unwrapped.opts.enum_kind == .identifier) "'" else "\"";
            },
        }
    }

    /// returns a comma-separated string of quoted enum values, representing the valid
    /// choices for the string or identifier enum of the first field of the `attr`.
    pub fn choices(attr: Tag) []const u8 {
        switch (attr) {
            .calling_convention => unreachable,
            inline else => |tag| {
                const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;

                if (fields.len == 0) unreachable;
                const Unwrapped = UnwrapOptional(fields[0].type);
                if (@typeInfo(Unwrapped) != .@"enum") unreachable;

                const enum_fields = @typeInfo(Unwrapped).@"enum".fields;
                const quote = comptime quoteChar(@enumFromInt(@intFromEnum(tag)));
                comptime var values: []const u8 = quote ++ enum_fields[0].name ++ quote;
                inline for (enum_fields[1..]) |enum_field| {
                    values = values ++ ", ";
                    values = values ++ quote ++ enum_field.name ++ quote;
                }
                return values;
            },
        }
    }
};

/// Checks if the first argument (if it exists) is an identifier enum
pub fn wantsIdentEnum(attr: Tag) bool {
    switch (attr) {
        .calling_convention => return false,
        inline else => |tag| {
            const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;

            if (fields.len == 0) return false;
            const Unwrapped = UnwrapOptional(fields[0].type);
            if (@typeInfo(Unwrapped) != .@"enum") return false;

            return Unwrapped.opts.enum_kind == .identifier;
        },
    }
}

pub fn diagnoseIdent(attr: Tag, arguments: *Arguments, ident: TokenIndex, p: *Parser) !bool {
    switch (attr) {
        inline else => |tag| {
            const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
            if (fields.len == 0) unreachable;
            const Unwrapped = UnwrapOptional(fields[0].type);
            if (@typeInfo(Unwrapped) != .@"enum") unreachable;
            if (std.meta.stringToEnum(Unwrapped, normalize(p.tokSlice(ident)))) |enum_val| {
                @field(@field(arguments, @tagName(tag)), fields[0].name) = enum_val;
                return false;
            }

            try p.err(ident, .unknown_attr_enum, .{ @tagName(attr), Formatting.choices(attr) });
            return true;
        },
    }
}

pub fn wantsAlignment(attr: Tag, idx: usize) bool {
    switch (attr) {
        inline else => |tag| {
            const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
            if (fields.len == 0) return false;

            return switch (idx) {
                inline 0...fields.len - 1 => |i| UnwrapOptional(fields[i].type) == Alignment,
                else => false,
            };
        },
    }
}

pub fn diagnoseAlignment(attr: Tag, arguments: *Arguments, arg_idx: u32, res: Parser.Result, arg_start: TokenIndex, p: *Parser) !bool {
    switch (attr) {
        inline else => |tag| {
            const arg_fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
            if (arg_fields.len == 0) unreachable;

            switch (arg_idx) {
                inline 0...arg_fields.len - 1 => |arg_i| {
                    if (UnwrapOptional(arg_fields[arg_i].type) != Alignment) unreachable;

                    if (!res.val.is(.int, p.comp)) {
                        try p.err(arg_start, .alignas_unavailable, .{});
                        return true;
                    }
                    if (res.val.compare(.lt, Value.zero, p.comp)) {
                        try p.err(arg_start, .negative_alignment, .{res});
                        return true;
                    }
                    const requested = res.val.toInt(u29, p.comp) orelse {
                        try p.err(arg_start, .maximum_alignment, .{res});
                        return true;
                    };
                    if (!std.mem.isValidAlign(requested)) {
                        try p.err(arg_start, .non_pow2_align, .{});
                        return true;
                    }

                    @field(@field(arguments, @tagName(tag)), arg_fields[arg_i].name) = .{ .requested = requested };
                    return false;
                },
                else => unreachable,
            }
        },
    }
}

fn diagnoseField(
    comptime decl: ZigType.Declaration,
    comptime field: ZigType.StructField,
    comptime Wanted: type,
    arguments: *Arguments,
    res: Parser.Result,
    arg_start: TokenIndex,
    node: Tree.Node,
    p: *Parser,
) !bool {
    const string = "a string";
    const identifier = "an identifier";
    const int = "an integer constant";
    const alignment = "an integer constant";
    const nullptr_t = "nullptr";
    const float = "a floating point number";
    const complex_float = "a complex floating point number";
    const expression = "an expression";

    const expected: []const u8 = switch (Wanted) {
        Value => string,
        Identifier => identifier,
        u32 => int,
        Alignment => alignment,
        CallingConvention => identifier,
        else => switch (@typeInfo(Wanted)) {
            .@"enum" => if (Wanted.opts.enum_kind == .string) string else identifier,
            else => unreachable,
        },
    };

    if (res.val.opt_ref == .none) {
        if (Wanted == Identifier and node == .decl_ref_expr) {
            @field(@field(arguments, decl.name), field.name) = .{ .tok = node.decl_ref_expr.name_tok };
            return false;
        }

        try p.err(arg_start, .attribute_arg_invalid, .{ expected, expression });
        return true;
    }
    const key = p.comp.interner.get(res.val.ref());
    switch (key) {
        .int => {
            if (@typeInfo(Wanted) == .int) {
                @field(@field(arguments, decl.name), field.name) = res.val.toInt(Wanted, p.comp) orelse {
                    try p.err(arg_start, .attribute_int_out_of_range, .{res});
                    return true;
                };

                return false;
            }
        },
        .bytes => |bytes| {
            if (Wanted == Value) {
                validate: {
                    if (node != .string_literal_expr) break :validate;
                    switch (node.string_literal_expr.qt.childType(p.comp).get(p.comp, .int).?) {
                        .char, .uchar, .schar => {},
                        else => break :validate,
                    }
                    @field(@field(arguments, decl.name), field.name) = try p.removeNull(res.val);
                    return false;
                }

                try p.err(arg_start, .attribute_requires_string, .{decl.name});
                return true;
            } else if (@typeInfo(Wanted) == .@"enum" and @hasDecl(Wanted, "opts") and Wanted.opts.enum_kind == .string) {
                const str = bytes[0 .. bytes.len - 1];
                if (std.meta.stringToEnum(Wanted, str)) |enum_val| {
                    @field(@field(arguments, decl.name), field.name) = enum_val;
                    return false;
                }

                try p.err(arg_start, .unknown_attr_enum, .{ decl.name, Formatting.choices(@field(Tag, decl.name)) });
                return true;
            }
        },
        else => {},
    }

    try p.err(arg_start, .attribute_arg_invalid, .{ expected, switch (key) {
        .int => int,
        .bytes => string,
        .float => float,
        .complex => complex_float,
        .null => nullptr_t,
        else => unreachable,
    } });
    return true;
}

pub fn diagnose(attr: Tag, arguments: *Arguments, arg_idx: u32, res: Parser.Result, arg_start: TokenIndex, node: Tree.Node, p: *Parser) !bool {
    switch (attr) {
        .nonnull => return false,
        inline else => |tag| {
            const decl = @typeInfo(attributes).@"struct".decls[@intFromEnum(tag)];
            const max_arg_count = comptime maxArgCount(tag);
            if (arg_idx >= max_arg_count) {
                try p.err(arg_start, .attribute_too_many_args, .{ @tagName(attr), max_arg_count });
                return true;
            }

            const arg_fields = @typeInfo(@field(attributes, decl.name)).@"struct".fields;
            switch (arg_idx) {
                inline 0...arg_fields.len - 1 => |arg_i| {
                    return diagnoseField(decl, arg_fields[arg_i], UnwrapOptional(arg_fields[arg_i].type), arguments, res, arg_start, node, p);
                },
                else => unreachable,
            }
        },
    }
}

const EnumTypes = enum {
    string,
    identifier,
};
pub const Alignment = struct {
    node: Tree.Node.OptIndex = .null,
    requested: u32,
};
pub const Identifier = struct {
    tok: TokenIndex = 0,
};

const attributes = struct {
    pub const access = struct {
        access_mode: enum {
            read_only,
            read_write,
            write_only,
            none,

            const opts = struct {
                const enum_kind = .identifier;
            };
        },
        ref_index: u32,
        size_index: ?u32 = null,
    };
    pub const alias = struct {
        alias: Value,
    };
    pub const aligned = struct {
        alignment: ?Alignment = null,
        __name_tok: TokenIndex,
    };
    pub const alloc_align = struct {
        position: u32,
    };
    pub const alloc_size = struct {
        position_1: u32,
        position_2: ?u32 = null,
    };
    pub const allocate = struct {
        segname: Value,
    };
    pub const allocator = struct {};
    pub const always_inline = struct {};
    pub const appdomain = struct {};
    pub const artificial = struct {};
    pub const assume_aligned = struct {
        alignment: Alignment,
        offset: ?u32 = null,
    };
    pub const cleanup = struct {
        function: Identifier,
    };
    pub const code_seg = struct {
        segname: Value,
    };
    pub const cold = struct {};
    pub const common = struct {};
    pub const @"const" = struct {};
    pub const constructor = struct {
        priority: ?u32 = null,
    };
    pub const copy = struct {
        function: Identifier,
    };
    pub const deprecated = struct {
        msg: ?Value = null,
        __name_tok: TokenIndex,
    };
    pub const designated_init = struct {};
    pub const destructor = struct {
        priority: ?u32 = null,
    };
    pub const dllexport = struct {};
    pub const dllimport = struct {};
    pub const @"error" = struct {
        msg: Value,
        __name_tok: TokenIndex,
    };
    pub const externally_visible = struct {};
    pub const fallthrough = struct {};
    pub const flatten = struct {};
    pub const format = struct {
        archetype: enum {
            printf,
            scanf,
            strftime,
            strfmon,

            const opts = struct {
                const enum_kind = .identifier;
            };
        },
        string_index: u32,
        first_to_check: u32,
    };
    pub const format_arg = struct {
        string_index: u32,
    };
    pub const gnu_inline = struct {};
    pub const hot = struct {};
    pub const ifunc = struct {
        resolver: Value,
    };
    pub const interrupt = struct {};
    pub const interrupt_handler = struct {};
    pub const jitintrinsic = struct {};
    pub const leaf = struct {};
    pub const malloc = struct {};
    pub const may_alias = struct {};
    pub const mode = struct {
        mode: enum {
            // zig fmt: off
                byte,  word,  pointer,
                BI,    QI,    HI,
                PSI,   SI,    PDI,
                DI,    TI,    OI,
                XI,    QF,    HF,
                TQF,   SF,    DF,
                XF,    SD,    DD,
                TD,    TF,    QQ,
                HQ,    SQ,    DQ,
                TQ,    UQQ,   UHQ,
                USQ,   UDQ,   UTQ,
                HA,    SA,    DA,
                TA,    UHA,   USA,
                UDA,   UTA,   CC,
                BLK,   VOID,  QC,
                HC,    SC,    DC,
                XC,    TC,    CQI,
                CHI,   CSI,   CDI,
                CTI,   COI,   CPSI,
                BND32, BND64,
                // zig fmt: on

            const opts = struct {
                const enum_kind = .identifier;
            };
        },
    };
    pub const naked = struct {};
    pub const no_address_safety_analysis = struct {};
    pub const no_icf = struct {};
    pub const no_instrument_function = struct {};
    pub const no_profile_instrument_function = struct {};
    pub const no_reorder = struct {};
    pub const no_sanitize = struct {
        /// Todo: represent args as union?
        alignment: Value,
        object_size: ?Value = null,
    };
    pub const no_sanitize_address = struct {};
    pub const no_sanitize_coverage = struct {};
    pub const no_sanitize_thread = struct {};
    pub const no_sanitize_undefined = struct {};
    pub const no_split_stack = struct {};
    pub const no_stack_limit = struct {};
    pub const no_stack_protector = struct {};
    pub const @"noalias" = struct {};
    pub const noclone = struct {};
    pub const nocommon = struct {};
    pub const nodiscard = struct {};
    pub const noinit = struct {};
    pub const @"noinline" = struct {};
    pub const noipa = struct {};
    // TODO: arbitrary number of arguments
    pub const nonnull = struct {};
    pub const nonstring = struct {};
    pub const noplt = struct {};
    pub const @"noreturn" = struct {};
    pub const nothrow = struct {};
    // TODO: union args ?
    //    const optimize = struct {
    //    //            optimize, // u32 | []const u8 -- optimize?
    //        };
    //    };
    pub const @"packed" = struct {};
    pub const patchable_function_entry = struct {};
    pub const persistent = struct {};
    pub const process = struct {};
    pub const pure = struct {};
    pub const reproducible = struct {};
    pub const restrict = struct {};
    pub const retain = struct {};
    pub const returns_nonnull = struct {};
    pub const returns_twice = struct {};
    pub const safebuffers = struct {};
    pub const scalar_storage_order = struct {
        order: enum {
            @"little-endian",
            @"big-endian",

            const opts = struct {
                const enum_kind = .string;
            };
        },
    };
    pub const section = struct {
        name: Value,
    };
    pub const selectany = struct {};
    pub const sentinel = struct {
        position: ?u32 = null,
    };
    pub const simd = struct {
        mask: ?enum {
            notinbranch,
            inbranch,

            const opts = struct {
                const enum_kind = .string;
            };
        } = null,
    };
    pub const spectre = struct {
        arg: enum {
            nomitigation,

            const opts = struct {
                const enum_kind = .identifier;
            };
        },
    };
    pub const stack_protect = struct {};
    pub const symver = struct {
        version: Value, // TODO: validate format "name2@nodename"

    };
    pub const target = struct {
        options: Value, // TODO: multiple arguments

    };
    pub const target_clones = struct {
        options: Value, // TODO: multiple arguments

    };
    pub const thread = struct {};
    pub const tls_model = struct {
        model: enum {
            @"global-dynamic",
            @"local-dynamic",
            @"initial-exec",
            @"local-exec",

            const opts = struct {
                const enum_kind = .string;
            };
        },
    };
    pub const transparent_union = struct {};
    pub const unavailable = struct {
        msg: ?Value = null,
        __name_tok: TokenIndex,
    };
    pub const uninitialized = struct {};
    pub const unsequenced = struct {};
    pub const unused = struct {};
    pub const used = struct {};
    pub const uuid = struct {
        uuid: Value,
    };
    pub const vector_size = struct {
        bytes: u32, // TODO: validate "The bytes argument must be a positive power-of-two multiple of the base type size"

    };
    pub const visibility = struct {
        visibility_type: enum {
            default,
            hidden,
            internal,
            protected,

            const opts = struct {
                const enum_kind = .string;
            };
        },
    };
    pub const warn_if_not_aligned = struct {
        alignment: Alignment,
    };
    pub const warn_unused_result = struct {};
    pub const warning = struct {
        msg: Value,
        __name_tok: TokenIndex,
    };
    pub const weak = struct {};
    pub const weakref = struct {
        target: ?Value = null,
    };
    pub const zero_call_used_regs = struct {
        choice: enum {
            skip,
            used,
            @"used-gpr",
            @"used-arg",
            @"used-gpr-arg",
            all,
            @"all-gpr",
            @"all-arg",
            @"all-gpr-arg",

            const opts = struct {
                const enum_kind = .string;
            };
        },
    };
    pub const asm_label = struct {
        name: Value,
    };
    pub const calling_convention = struct {
        cc: CallingConvention,
    };
    pub const nullability = struct {
        kind: enum {
            nonnull,
            nullable,
            nullable_result,
            unspecified,

            const opts = struct {
                const enum_kind = .identifier;
            };
        },
    };
    pub const unaligned = struct {};
    pub const pcs = struct {
        kind: enum {
            aapcs,
            @"aapcs-vfp",

            const opts = struct {
                const enum_kind = .string;
            };
        },
    };
    pub const riscv_vector_cc = struct {};
    pub const aarch64_sve_pcs = struct {};
    pub const aarch64_vector_pcs = struct {};
    pub const fastcall = struct {};
    pub const stdcall = struct {};
    pub const vectorcall = struct {};
    pub const cdecl = struct {};
    pub const thiscall = struct {};
    pub const sysv_abi = struct {};
    pub const ms_abi = struct {};
    // TODO cannot be combined with weak or selectany
    pub const internal_linkage = struct {};
    pub const availability = struct {};
};

pub const Tag = std.meta.DeclEnum(attributes);

pub const Arguments = blk: {
    const decls = @typeInfo(attributes).@"struct".decls;
    var union_fields: [decls.len]ZigType.UnionField = undefined;
    for (decls, &union_fields) |decl, *field| {
        field.* = .{
            .name = decl.name,
            .type = @field(attributes, decl.name),
            .alignment = @alignOf(@field(attributes, decl.name)),
        };
    }

    break :blk @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = null,
            .fields = &union_fields,
            .decls = &.{},
        },
    });
};

pub fn ArgumentsForTag(comptime tag: Tag) type {
    const decl = @typeInfo(attributes).@"struct".decls[@intFromEnum(tag)];
    return @field(attributes, decl.name);
}

pub fn initArguments(tag: Tag, name_tok: TokenIndex) Arguments {
    switch (tag) {
        inline else => |arg_tag| {
            const union_element = @field(attributes, @tagName(arg_tag));
            const init = std.mem.zeroInit(union_element, .{});
            var args = @unionInit(Arguments, @tagName(arg_tag), init);
            if (@hasField(@field(attributes, @tagName(arg_tag)), "__name_tok")) {
                @field(args, @tagName(arg_tag)).__name_tok = name_tok;
            }
            return args;
        },
    }
}

pub fn fromString(kind: Kind, namespace: ?[]const u8, name: []const u8) ?Tag {
    const Properties = struct {
        tag: Tag,
        gnu: bool = false,
        declspec: bool = false,
        c23: bool = false,
    };
    const attribute_names = @import("Attribute/names.zig").with(Properties);

    const normalized = normalize(name);
    const actual_kind: Kind = if (namespace) |ns| blk: {
        const normalized_ns = normalize(ns);
        if (mem.eql(u8, normalized_ns, "gnu")) {
            break :blk .gnu;
        }
        return null;
    } else kind;

    const tag_and_opts = attribute_names.fromName(normalized) orelse return null;
    switch (actual_kind) {
        inline else => |available_kind| {
            if (@field(tag_and_opts, @tagName(available_kind)))
                return tag_and_opts.tag;
        },
    }
    return null;
}

pub fn normalize(name: []const u8) []const u8 {
    if (name.len >= 4 and mem.startsWith(u8, name, "__") and mem.endsWith(u8, name, "__")) {
        return name[2 .. name.len - 2];
    }
    return name;
}

fn ignoredAttrErr(p: *Parser, tok: TokenIndex, attr: Attribute.Tag, context: []const u8) !void {
    try p.err(tok, .ignored_attribute, .{ @tagName(attr), context });
}

pub fn applyParameterAttributes(p: *Parser, qt: QualType, attr_buf_start: usize, diagnostic: ?Parser.Diagnostic) !QualType {
    return applyVariableOrParameterAttributes(p, qt, attr_buf_start, diagnostic, .parameter);
}

pub fn applyVariableAttributes(p: *Parser, qt: QualType, attr_buf_start: usize, diagnostic: ?Parser.Diagnostic) !QualType {
    return applyVariableOrParameterAttributes(p, qt, attr_buf_start, diagnostic, .variable);
}

fn applyVariableOrParameterAttributes(p: *Parser, qt: QualType, attr_buf_start: usize, diagnostic: ?Parser.Diagnostic, context: enum { parameter, variable }) !QualType {
    const gpa = p.comp.gpa;
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_qt = qt;
    var common = false;
    var nocommon = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .alias, .may_alias, .deprecated, .unavailable, .unused, .warn_if_not_aligned, .weak, .used,
        .noinit, .retain, .persistent, .section, .mode, .asm_label, .nullability, .unaligned, .selectany, .internal_linkage,
         => try p.attr_application_buf.append(gpa, attr),
        // zig fmt: on
        .common => if (nocommon) {
            try p.err(tok, .ignore_common, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            common = true;
        },
        .nocommon => if (common) {
            try p.err(tok, .ignore_nocommon, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            nocommon = true;
        },
        .vector_size => try attr.applyVectorSize(p, tok, &base_qt),
        .aligned => try attr.applyAligned(p, base_qt, diagnostic),
        .nonnull => {
            switch (context) {
                .parameter => try p.err(tok, .attribute_todo, .{ "nonnull", "parameters" }),
                .variable => try p.err(tok, .nonnull_not_applicable, .{}),
            }
        },
        .nonstring => {
            if (base_qt.get(p.comp, .array)) |array_ty| {
                if (array_ty.elem.get(p.comp, .int)) |int_ty| switch (int_ty) {
                    .char, .uchar, .schar => {
                        try p.attr_application_buf.append(gpa, attr);
                        continue;
                    },
                    else => {},
                };
            }
            try p.err(tok, .non_string_ignored, .{qt});
        },
        .uninitialized => if (p.func.qt == null) {
            try p.err(tok, .local_variable_attribute, .{"uninitialized"});
        } else {
            try p.attr_application_buf.append(gpa, attr);
        },
        .cleanup => if (p.func.qt == null) {
            try p.err(tok, .local_variable_attribute, .{"cleanup"});
        } else {
            try p.attr_application_buf.append(gpa, attr);
        },
        .calling_convention => try applyCallingConvention(attr, p, tok, base_qt),
        .alloc_size,
        .copy,
        .tls_model,
        .visibility,
        => |t| try p.err(tok, .attribute_todo, .{ @tagName(t), "variables" }),
        // There is already an error in Parser for _Noreturn keyword
        .noreturn => if (attr.syntax != .keyword) try ignoredAttrErr(p, tok, attr.tag, "variables"),
        else => try ignoredAttrErr(p, tok, attr.tag, "variables"),
    };
    return applySelected(base_qt, p);
}

pub fn applyFieldAttributes(p: *Parser, field_qt: *QualType, attr_buf_start: usize) ![]const Attribute {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const seen = p.attr_buf.items(.seen)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, 0..) |attr, i| switch (attr.tag) {
        .@"packed" => {
            try p.attr_application_buf.append(p.comp.gpa, attr);
            seen[i] = true;
        },
        .aligned => {
            try attr.applyAligned(p, field_qt.*, null);
            seen[i] = true;
        },
        else => {},
    };
    return p.attr_application_buf.items;
}

pub fn applyTypeAttributes(p: *Parser, qt: QualType, attr_buf_start: usize, diagnostic: ?Parser.Diagnostic) !QualType {
    const gpa = p.comp.gpa;
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    const seens = p.attr_buf.items(.seen)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_qt = qt;
    for (attrs, toks, seens) |attr, tok, seen| {
        if (seen) continue;

        switch (attr.tag) {
            // zig fmt: off
            .@"packed", .may_alias, .deprecated, .unavailable, .unused, .warn_if_not_aligned, .mode,
            .nullability, .unaligned, .warn_unused_result,
            => try p.attr_application_buf.append(gpa, attr),
            // zig fmt: on
            .transparent_union => try attr.applyTransparentUnion(p, tok, base_qt),
            .vector_size => try attr.applyVectorSize(p, tok, &base_qt),
            .aligned => try attr.applyAligned(p, base_qt, diagnostic),
            .designated_init => if (base_qt.is(p.comp, .@"struct")) {
                try p.attr_application_buf.append(gpa, attr);
            } else {
                try p.err(tok, .designated_init_invalid, .{});
            },
            .calling_convention => try applyCallingConvention(attr, p, tok, base_qt),
            .alloc_size,
            .copy,
            .scalar_storage_order,
            .nonstring,
            => |t| try p.err(tok, .attribute_todo, .{ @tagName(t), "types" }),
            else => try ignoredAttrErr(p, tok, attr.tag, "types"),
        }
    }
    return applySelected(base_qt, p);
}

pub fn applyFunctionAttributes(p: *Parser, qt: QualType, attr_buf_start: usize) !QualType {
    const gpa = p.comp.gpa;
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_qt = qt;
    var hot = false;
    var cold = false;
    var @"noinline" = false;
    var always_inline = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .noreturn, .unused, .used, .warning, .deprecated, .unavailable, .weak, .pure, .leaf,
        .@"const", .warn_unused_result, .section, .returns_nonnull, .returns_twice, .@"error",
        .externally_visible, .retain, .flatten, .gnu_inline, .alias, .asm_label, .nodiscard,
        .reproducible, .unsequenced, .nothrow, .nullability, .unaligned, .internal_linkage,
         => try p.attr_application_buf.append(gpa, attr),
        // zig fmt: on
        .hot => if (cold) {
            try p.err(tok, .ignore_hot, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            hot = true;
        },
        .cold => if (hot) {
            try p.err(tok, .ignore_cold, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            cold = true;
        },
        .always_inline => if (@"noinline") {
            try p.err(tok, .ignore_always_inline, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            always_inline = true;
        },
        .@"noinline" => if (always_inline) {
            try p.err(tok, .ignore_noinline, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            @"noinline" = true;
        },
        .aligned => try attr.applyAligned(p, base_qt, null),
        .format => try attr.applyFormat(p, base_qt),
        .calling_convention => try applyCallingConvention(attr, p, tok, base_qt),
        .fastcall => if (p.comp.target.cpu.arch == .x86) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .fastcall } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"fastcall"});
        },
        .stdcall => if (p.comp.target.cpu.arch == .x86) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .stdcall } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"stdcall"});
        },
        .thiscall => if (p.comp.target.cpu.arch == .x86) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .thiscall } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"thiscall"});
        },
        .vectorcall => if (p.comp.target.cpu.arch == .x86 or p.comp.target.cpu.arch.isAARCH64()) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .vectorcall } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"vectorcall"});
        },
        .cdecl => {},
        .pcs => if (p.comp.target.cpu.arch.isArm()) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = switch (attr.args.pcs.kind) {
                    .aapcs => .arm_aapcs,
                    .@"aapcs-vfp" => .arm_aapcs_vfp,
                } } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"pcs"});
        },
        .riscv_vector_cc => if (p.comp.target.cpu.arch.isRISCV()) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .riscv_vector } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"pcs"});
        },
        .aarch64_sve_pcs => if (p.comp.target.cpu.arch.isAARCH64()) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .aarch64_sve_pcs } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"pcs"});
        },
        .aarch64_vector_pcs => if (p.comp.target.cpu.arch.isAARCH64()) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .aarch64_vector_pcs } },
                .syntax = attr.syntax,
            });
        } else {
            try p.err(tok, .callconv_not_supported, .{"pcs"});
        },
        .sysv_abi => if (p.comp.target.cpu.arch == .x86_64 and p.comp.target.os.tag == .windows) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .x86_64_sysv } },
                .syntax = attr.syntax,
            });
        },
        .ms_abi => if (p.comp.target.cpu.arch == .x86_64 and p.comp.target.os.tag != .windows) {
            try p.attr_application_buf.append(gpa, .{
                .tag = .calling_convention,
                .args = .{ .calling_convention = .{ .cc = .x86_64_win } },
                .syntax = attr.syntax,
            });
        },
        .malloc => {
            if (base_qt.get(p.comp, .func).?.return_type.isPointer(p.comp)) {
                try p.attr_application_buf.append(gpa, attr);
            } else {
                try ignoredAttrErr(p, tok, attr.tag, "functions that do not return pointers");
            }
        },
        .alloc_align => {
            const func_ty = base_qt.get(p.comp, .func).?;
            if (func_ty.return_type.isPointer(p.comp)) {
                if (attr.args.alloc_align.position == 0 or attr.args.alloc_align.position > func_ty.params.len) {
                    try p.err(tok, .attribute_param_out_of_bounds, .{ "alloc_align", 1 });
                } else {
                    const arg_qt = func_ty.params[attr.args.alloc_align.position - 1].qt;
                    if (arg_qt.isInvalid()) continue;
                    const arg_sk = arg_qt.scalarKind(p.comp);
                    if (!arg_sk.isInt() or !arg_sk.isReal()) {
                        try p.err(tok, .alloc_align_required_int_param, .{});
                    } else {
                        try p.attr_application_buf.append(gpa, attr);
                    }
                }
            } else {
                try p.err(tok, .alloc_align_requires_ptr_return, .{});
            }
        },
        .access,
        .alloc_size,
        .artificial,
        .assume_aligned,
        .constructor,
        .copy,
        .destructor,
        .format_arg,
        .ifunc,
        .interrupt,
        .interrupt_handler,
        .no_address_safety_analysis,
        .no_icf,
        .no_instrument_function,
        .no_profile_instrument_function,
        .no_reorder,
        .no_sanitize,
        .no_sanitize_address,
        .no_sanitize_coverage,
        .no_sanitize_thread,
        .no_sanitize_undefined,
        .no_split_stack,
        .no_stack_limit,
        .no_stack_protector,
        .noclone,
        .noipa,
        .nonnull,
        .noplt,
        // .optimize,
        .patchable_function_entry,
        .sentinel,
        .simd,
        .stack_protect,
        .symver,
        .target,
        .target_clones,
        .visibility,
        .weakref,
        .zero_call_used_regs,
        => |t| try p.err(tok, .attribute_todo, .{ @tagName(t), "functions" }),
        else => try ignoredAttrErr(p, tok, attr.tag, "functions"),
    };
    return applySelected(qt, p);
}

pub fn applyLabelAttributes(p: *Parser, attr_buf_start: usize) !QualType {
    const gpa = p.comp.gpa;
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var hot = false;
    var cold = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .unused => try p.attr_application_buf.append(gpa, attr),
        .hot => if (cold) {
            try p.err(tok, .ignore_hot, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            hot = true;
        },
        .cold => if (hot) {
            try p.err(tok, .ignore_cold, .{});
        } else {
            try p.attr_application_buf.append(gpa, attr);
            cold = true;
        },
        else => try ignoredAttrErr(p, tok, attr.tag, "labels"),
    };
    return applySelected(.void, p);
}

pub fn applyStatementAttributes(p: *Parser, expr_start: TokenIndex, attr_buf_start: usize) !QualType {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .fallthrough => {
            for (p.tok_ids[p.tok_i..]) |tok_id| {
                switch (tok_id) {
                    .keyword_case, .keyword_default, .eof => {
                        try p.attr_application_buf.append(p.comp.gpa, attr);
                        break;
                    },
                    .r_brace, .semicolon => {},
                    else => {
                        try p.err(expr_start, .invalid_fallthrough, .{});
                        break;
                    },
                }
            }
        },
        else => try p.err(tok, .cannot_apply_attribute_to_statement, .{@tagName(attr.tag)}),
    };
    return applySelected(.void, p);
}

pub fn applyEnumeratorAttributes(p: *Parser, qt: QualType, attr_buf_start: usize) !QualType {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .deprecated, .unavailable => try p.attr_application_buf.append(p.comp.gpa, attr),
        else => try ignoredAttrErr(p, tok, attr.tag, "enums"),
    };
    return applySelected(qt, p);
}

fn applyAligned(attr: Attribute, p: *Parser, qt: QualType, diagnostic: ?Parser.Diagnostic) !void {
    if (attr.args.aligned.alignment) |alignment| alignas: {
        if (attr.syntax != .keyword) break :alignas;

        const align_tok = attr.args.aligned.__name_tok;
        if (diagnostic) |d| try p.err(align_tok, d, .{});

        if (qt.isInvalid()) return;
        const default_align = qt.base(p.comp).qt.alignof(p.comp);
        if (qt.is(p.comp, .func)) {
            try p.err(align_tok, .alignas_on_func, .{});
        } else if (alignment.requested < default_align) {
            try p.err(align_tok, .minimum_alignment, .{default_align});
        }
    }
    try p.attr_application_buf.append(p.comp.gpa, attr);
}

fn applyTransparentUnion(attr: Attribute, p: *Parser, tok: TokenIndex, qt: QualType) !void {
    const union_ty = qt.get(p.comp, .@"union") orelse {
        return p.err(tok, .transparent_union_wrong_type, .{});
    };
    // TODO validate union defined at end
    if (union_ty.layout == null) return;
    if (union_ty.fields.len == 0) {
        return p.err(tok, .transparent_union_one_field, .{});
    }
    const first_field_size = union_ty.fields[0].qt.bitSizeof(p.comp);
    for (union_ty.fields[1..]) |field| {
        const field_size = field.qt.bitSizeof(p.comp);
        if (field_size == first_field_size) continue;

        try p.err(field.name_tok, .transparent_union_size, .{ field.name.lookup(p.comp), field_size });
        return p.err(union_ty.fields[0].name_tok, .transparent_union_size_note, .{first_field_size});
    }

    try p.attr_application_buf.append(p.comp.gpa, attr);
}

fn applyVectorSize(attr: Attribute, p: *Parser, tok: TokenIndex, qt: *QualType) !void {
    if (qt.isInvalid()) return;
    const scalar_kind = qt.scalarKind(p.comp);
    if (scalar_kind != .int and scalar_kind != .float) {
        if (qt.get(p.comp, .@"enum")) |enum_ty| {
            if (p.comp.langopts.emulate == .clang and enum_ty.incomplete) {
                return; // Clang silently ignores vector_size on incomplete enums.
            }
        }
        try p.err(tok, .invalid_vec_elem_ty, .{qt.*});
        return error.ParsingFailed;
    }
    if (qt.get(p.comp, .bit_int)) |bit_int| {
        if (bit_int.bits < 8) {
            try p.err(tok, .bit_int_vec_too_small, .{});
            return error.ParsingFailed;
        } else if (!std.math.isPowerOfTwo(bit_int.bits)) {
            try p.err(tok, .bit_int_vec_not_pow2, .{});
            return error.ParsingFailed;
        }
    }

    const vec_bytes = attr.args.vector_size.bytes;
    const elem_size = qt.sizeof(p.comp);
    if (vec_bytes % elem_size != 0) {
        return p.err(tok, .vec_size_not_multiple, .{});
    }

    qt.* = try p.comp.type_store.put(p.comp.gpa, .{ .vector = .{
        .elem = qt.*,
        .len = @intCast(vec_bytes / elem_size),
    } });
}

fn applyFormat(attr: Attribute, p: *Parser, qt: QualType) !void {
    // TODO validate
    _ = qt;
    try p.attr_application_buf.append(p.comp.gpa, attr);
}

fn applyCallingConvention(attr: Attribute, p: *Parser, tok: TokenIndex, qt: QualType) !void {
    if (!qt.is(p.comp, .func)) {
        return p.err(tok, .callconv_non_func, .{ p.tok_ids[tok].symbol(), qt });
    }
    switch (attr.args.calling_convention.cc) {
        .c => {},
        .stdcall, .thiscall, .fastcall, .regcall => switch (p.comp.target.cpu.arch) {
            .x86 => try p.attr_application_buf.append(p.comp.gpa, attr),
            else => try p.err(tok, .callconv_not_supported, .{p.tok_ids[tok].symbol()}),
        },
        .vectorcall => switch (p.comp.target.cpu.arch) {
            .x86, .aarch64, .aarch64_be => try p.attr_application_buf.append(p.comp.gpa, attr),
            else => try p.err(tok, .callconv_not_supported, .{p.tok_ids[tok].symbol()}),
        },
        .riscv_vector,
        .aarch64_sve_pcs,
        .aarch64_vector_pcs,
        .arm_aapcs,
        .arm_aapcs_vfp,
        .x86_64_sysv,
        .x86_64_win,
        => unreachable, // These can't come from keyword syntax
    }
}

fn applySelected(qt: QualType, p: *Parser) !QualType {
    if (p.attr_application_buf.items.len == 0) return qt;
    if (qt.isInvalid()) return qt;
    return (try p.comp.type_store.put(p.comp.gpa, .{ .attributed = .{
        .base = qt,
        .attributes = p.attr_application_buf.items,
    } })).withQualifiers(qt);
}
