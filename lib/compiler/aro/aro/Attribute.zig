const std = @import("std");
const mem = std.mem;
const ZigType = std.builtin.Type;
const CallingConvention = @import("../backend.zig").CallingConvention;
const Compilation = @import("Compilation.zig");
const Diagnostics = @import("Diagnostics.zig");
const Parser = @import("Parser.zig");
const Tree = @import("Tree.zig");
const NodeIndex = Tree.NodeIndex;
const TokenIndex = Tree.TokenIndex;
const Type = @import("Type.zig");
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
    source: union(enum) {
        ty: Type,
        slice: []const Attribute,
    },
    index: usize,

    pub fn initSlice(slice: ?[]const Attribute) Iterator {
        return .{ .source = .{ .slice = slice orelse &.{} }, .index = 0 };
    }

    pub fn initType(ty: Type) Iterator {
        return .{ .source = .{ .ty = ty }, .index = 0 };
    }

    /// returns the next attribute as well as its index within the slice or current type
    /// The index can be used to determine when a nested type has been recursed into
    pub fn next(self: *Iterator) ?struct { Attribute, usize } {
        switch (self.source) {
            .slice => |slice| {
                if (self.index < slice.len) {
                    defer self.index += 1;
                    return .{ slice[self.index], self.index };
                }
            },
            .ty => |ty| {
                switch (ty.specifier) {
                    .typeof_type => {
                        self.* = .{ .source = .{ .ty = ty.data.sub_type.* }, .index = 0 };
                        return self.next();
                    },
                    .typeof_expr => {
                        self.* = .{ .source = .{ .ty = ty.data.expr.ty }, .index = 0 };
                        return self.next();
                    },
                    .attributed => {
                        if (self.index < ty.data.attributed.attributes.len) {
                            defer self.index += 1;
                            return .{ ty.data.attributed.attributes[self.index], self.index };
                        }
                        self.* = .{ .source = .{ .ty = ty.data.attributed.base }, .index = 0 };
                        return self.next();
                    },
                    else => {},
                }
            },
        }
        return null;
    }
};

pub const ArgumentType = enum {
    string,
    identifier,
    int,
    alignment,
    float,
    complex_float,
    expression,
    nullptr_t,

    pub fn toString(self: ArgumentType) []const u8 {
        return switch (self) {
            .string => "a string",
            .identifier => "an identifier",
            .int, .alignment => "an integer constant",
            .nullptr_t => "nullptr",
            .float => "a floating point number",
            .complex_float => "a complex floating point number",
            .expression => "an expression",
        };
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

pub fn diagnoseIdent(attr: Tag, arguments: *Arguments, ident: []const u8) ?Diagnostics.Message {
    switch (attr) {
        inline else => |tag| {
            const fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
            if (fields.len == 0) unreachable;
            const Unwrapped = UnwrapOptional(fields[0].type);
            if (@typeInfo(Unwrapped) != .@"enum") unreachable;
            if (std.meta.stringToEnum(Unwrapped, normalize(ident))) |enum_val| {
                @field(@field(arguments, @tagName(tag)), fields[0].name) = enum_val;
                return null;
            }
            return Diagnostics.Message{
                .tag = .unknown_attr_enum,
                .extra = .{ .attr_enum = .{ .tag = attr } },
            };
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

pub fn diagnoseAlignment(attr: Tag, arguments: *Arguments, arg_idx: u32, res: Parser.Result, p: *Parser) !?Diagnostics.Message {
    switch (attr) {
        inline else => |tag| {
            const arg_fields = @typeInfo(@field(attributes, @tagName(tag))).@"struct".fields;
            if (arg_fields.len == 0) unreachable;

            switch (arg_idx) {
                inline 0...arg_fields.len - 1 => |arg_i| {
                    if (UnwrapOptional(arg_fields[arg_i].type) != Alignment) unreachable;

                    if (!res.val.is(.int, p.comp)) return Diagnostics.Message{ .tag = .alignas_unavailable };
                    if (res.val.compare(.lt, Value.zero, p.comp)) {
                        return Diagnostics.Message{ .tag = .negative_alignment, .extra = .{ .str = try res.str(p) } };
                    }
                    const requested = res.val.toInt(u29, p.comp) orelse {
                        return Diagnostics.Message{ .tag = .maximum_alignment, .extra = .{ .str = try res.str(p) } };
                    };
                    if (!std.mem.isValidAlign(requested)) return Diagnostics.Message{ .tag = .non_pow2_align };

                    @field(@field(arguments, @tagName(tag)), arg_fields[arg_i].name) = Alignment{ .requested = requested };
                    return null;
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
    node: Tree.Node,
    p: *Parser,
) !?Diagnostics.Message {
    if (res.val.opt_ref == .none) {
        if (Wanted == Identifier and node.tag == .decl_ref_expr) {
            @field(@field(arguments, decl.name), field.name) = Identifier{ .tok = node.data.decl_ref };
            return null;
        }
        return invalidArgMsg(Wanted, .expression);
    }
    const key = p.comp.interner.get(res.val.ref());
    switch (key) {
        .int => {
            if (@typeInfo(Wanted) == .int) {
                @field(@field(arguments, decl.name), field.name) = res.val.toInt(Wanted, p.comp) orelse return .{
                    .tag = .attribute_int_out_of_range,
                    .extra = .{ .str = try res.str(p) },
                };
                return null;
            }
        },
        .bytes => |bytes| {
            if (Wanted == Value) {
                if (node.tag != .string_literal_expr or (!node.ty.elemType().is(.char) and !node.ty.elemType().is(.uchar))) {
                    return .{
                        .tag = .attribute_requires_string,
                        .extra = .{ .str = decl.name },
                    };
                }
                @field(@field(arguments, decl.name), field.name) = try p.removeNull(res.val);
                return null;
            } else if (@typeInfo(Wanted) == .@"enum" and @hasDecl(Wanted, "opts") and Wanted.opts.enum_kind == .string) {
                const str = bytes[0 .. bytes.len - 1];
                if (std.meta.stringToEnum(Wanted, str)) |enum_val| {
                    @field(@field(arguments, decl.name), field.name) = enum_val;
                    return null;
                } else {
                    return .{
                        .tag = .unknown_attr_enum,
                        .extra = .{ .attr_enum = .{ .tag = std.meta.stringToEnum(Tag, decl.name).? } },
                    };
                }
            }
        },
        else => {},
    }
    return invalidArgMsg(Wanted, switch (key) {
        .int => .int,
        .bytes => .string,
        .float => .float,
        .complex => .complex_float,
        .null => .nullptr_t,
        .int_ty,
        .float_ty,
        .complex_ty,
        .ptr_ty,
        .noreturn_ty,
        .void_ty,
        .func_ty,
        .array_ty,
        .vector_ty,
        .record_ty,
        => unreachable,
    });
}

fn invalidArgMsg(comptime Expected: type, actual: ArgumentType) Diagnostics.Message {
    return .{
        .tag = .attribute_arg_invalid,
        .extra = .{ .attr_arg_type = .{ .expected = switch (Expected) {
            Value => .string,
            Identifier => .identifier,
            u32 => .int,
            Alignment => .alignment,
            CallingConvention => .identifier,
            else => switch (@typeInfo(Expected)) {
                .@"enum" => if (Expected.opts.enum_kind == .string) .string else .identifier,
                else => unreachable,
            },
        }, .actual = actual } },
    };
}

pub fn diagnose(attr: Tag, arguments: *Arguments, arg_idx: u32, res: Parser.Result, node: Tree.Node, p: *Parser) !?Diagnostics.Message {
    switch (attr) {
        inline else => |tag| {
            const decl = @typeInfo(attributes).@"struct".decls[@intFromEnum(tag)];
            const max_arg_count = comptime maxArgCount(tag);
            if (arg_idx >= max_arg_count) return Diagnostics.Message{
                .tag = .attribute_too_many_args,
                .extra = .{ .attr_arg_count = .{ .attribute = attr, .expected = max_arg_count } },
            };
            const arg_fields = @typeInfo(@field(attributes, decl.name)).@"struct".fields;
            switch (arg_idx) {
                inline 0...arg_fields.len - 1 => |arg_i| {
                    return diagnoseField(decl, arg_fields[arg_i], UnwrapOptional(arg_fields[arg_i].type), arguments, res, node, p);
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
    node: NodeIndex = .none,
    requested: u29,
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
    //    const nonnull = struct {
    //    //            arg_index: []const u32,
    //        };
    //    };
    pub const nonstring = struct {};
    pub const noplt = struct {};
    pub const @"noreturn" = struct {};
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
};

pub const Tag = std.meta.DeclEnum(attributes);

pub const Arguments = blk: {
    const decls = @typeInfo(attributes).@"struct".decls;
    var union_fields: [decls.len]ZigType.UnionField = undefined;
    for (decls, &union_fields) |decl, *field| {
        field.* = .{
            .name = decl.name,
            .type = @field(attributes, decl.name),
            .alignment = 0,
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
        inline else => |tag| {
            if (@field(tag_and_opts.properties, @tagName(tag)))
                return tag_and_opts.properties.tag;
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
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    try p.strings.writer().print("attribute '{s}' ignored on {s}", .{ @tagName(attr), context });
    const str = try p.comp.diagnostics.arena.allocator().dupe(u8, p.strings.items[strings_top..]);
    try p.errStr(.ignored_attribute, tok, str);
}

pub const applyParameterAttributes = applyVariableAttributes;
pub fn applyVariableAttributes(p: *Parser, ty: Type, attr_buf_start: usize, tag: ?Diagnostics.Tag) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_ty = ty;
    var common = false;
    var nocommon = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .alias, .may_alias, .deprecated, .unavailable, .unused, .warn_if_not_aligned, .weak, .used,
        .noinit, .retain, .persistent, .section, .mode, .asm_label,
         => try p.attr_application_buf.append(p.gpa, attr),
        // zig fmt: on
        .common => if (nocommon) {
            try p.errTok(.ignore_common, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            common = true;
        },
        .nocommon => if (common) {
            try p.errTok(.ignore_nocommon, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            nocommon = true;
        },
        .vector_size => try attr.applyVectorSize(p, tok, &base_ty),
        .aligned => try attr.applyAligned(p, base_ty, tag),
        .nonstring => if (!base_ty.isArray() or !(base_ty.is(.char) or base_ty.is(.uchar) or base_ty.is(.schar))) {
            try p.errStr(.non_string_ignored, tok, try p.typeStr(ty));
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
        },
        .uninitialized => if (p.func.ty == null) {
            try p.errStr(.local_variable_attribute, tok, "uninitialized");
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
        },
        .cleanup => if (p.func.ty == null) {
            try p.errStr(.local_variable_attribute, tok, "cleanup");
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
        },
        .alloc_size,
        .copy,
        .tls_model,
        .visibility,
        => |t| try p.errExtra(.attribute_todo, tok, .{ .attribute_todo = .{ .tag = t, .kind = .variables } }),
        else => try ignoredAttrErr(p, tok, attr.tag, "variables"),
    };
    return base_ty.withAttributes(p.arena, p.attr_application_buf.items);
}

pub fn applyFieldAttributes(p: *Parser, field_ty: *Type, attr_buf_start: usize) ![]const Attribute {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .@"packed", .may_alias, .deprecated, .unavailable, .unused, .warn_if_not_aligned, .mode, .warn_unused_result, .nodiscard,
        => try p.attr_application_buf.append(p.gpa, attr),
        // zig fmt: on
        .vector_size => try attr.applyVectorSize(p, tok, field_ty),
        .aligned => try attr.applyAligned(p, field_ty.*, null),
        else => try ignoredAttrErr(p, tok, attr.tag, "fields"),
    };
    if (p.attr_application_buf.items.len == 0) return &[0]Attribute{};
    return p.arena.dupe(Attribute, p.attr_application_buf.items);
}

pub fn applyTypeAttributes(p: *Parser, ty: Type, attr_buf_start: usize, tag: ?Diagnostics.Tag) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_ty = ty;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .@"packed", .may_alias, .deprecated, .unavailable, .unused, .warn_if_not_aligned, .mode,
         => try p.attr_application_buf.append(p.gpa, attr),
        // zig fmt: on
        .transparent_union => try attr.applyTransparentUnion(p, tok, base_ty),
        .vector_size => try attr.applyVectorSize(p, tok, &base_ty),
        .aligned => try attr.applyAligned(p, base_ty, tag),
        .designated_init => if (base_ty.is(.@"struct")) {
            try p.attr_application_buf.append(p.gpa, attr);
        } else {
            try p.errTok(.designated_init_invalid, tok);
        },
        .alloc_size,
        .copy,
        .scalar_storage_order,
        .nonstring,
        => |t| try p.errExtra(.attribute_todo, tok, .{ .attribute_todo = .{ .tag = t, .kind = .types } }),
        else => try ignoredAttrErr(p, tok, attr.tag, "types"),
    };
    return base_ty.withAttributes(p.arena, p.attr_application_buf.items);
}

pub fn applyFunctionAttributes(p: *Parser, ty: Type, attr_buf_start: usize) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var base_ty = ty;
    var hot = false;
    var cold = false;
    var @"noinline" = false;
    var always_inline = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        // zig fmt: off
        .noreturn, .unused, .used, .warning, .deprecated, .unavailable, .weak, .pure, .leaf,
        .@"const", .warn_unused_result, .section, .returns_nonnull, .returns_twice, .@"error",
        .externally_visible, .retain, .flatten, .gnu_inline, .alias, .asm_label, .nodiscard,
        .reproducible, .unsequenced,
         => try p.attr_application_buf.append(p.gpa, attr),
        // zig fmt: on
        .hot => if (cold) {
            try p.errTok(.ignore_hot, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            hot = true;
        },
        .cold => if (hot) {
            try p.errTok(.ignore_cold, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            cold = true;
        },
        .always_inline => if (@"noinline") {
            try p.errTok(.ignore_always_inline, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            always_inline = true;
        },
        .@"noinline" => if (always_inline) {
            try p.errTok(.ignore_noinline, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            @"noinline" = true;
        },
        .aligned => try attr.applyAligned(p, base_ty, null),
        .format => try attr.applyFormat(p, base_ty),
        .calling_convention => switch (attr.args.calling_convention.cc) {
            .C => continue,
            .stdcall, .thiscall => switch (p.comp.target.cpu.arch) {
                .x86 => try p.attr_application_buf.append(p.gpa, attr),
                else => try p.errStr(.callconv_not_supported, tok, p.tok_ids[tok].lexeme().?),
            },
            .vectorcall => switch (p.comp.target.cpu.arch) {
                .x86, .aarch64, .aarch64_be => try p.attr_application_buf.append(p.gpa, attr),
                else => try p.errStr(.callconv_not_supported, tok, p.tok_ids[tok].lexeme().?),
            },
        },
        .malloc => {
            if (base_ty.returnType().isPtr()) {
                try p.attr_application_buf.append(p.gpa, attr);
            } else {
                try ignoredAttrErr(p, tok, attr.tag, "functions that do not return pointers");
            }
        },
        .access,
        .alloc_align,
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
        // .nonnull,
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
        => |t| try p.errExtra(.attribute_todo, tok, .{ .attribute_todo = .{ .tag = t, .kind = .functions } }),
        else => try ignoredAttrErr(p, tok, attr.tag, "functions"),
    };
    return ty.withAttributes(p.arena, p.attr_application_buf.items);
}

pub fn applyLabelAttributes(p: *Parser, ty: Type, attr_buf_start: usize) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    var hot = false;
    var cold = false;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .unused => try p.attr_application_buf.append(p.gpa, attr),
        .hot => if (cold) {
            try p.errTok(.ignore_hot, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            hot = true;
        },
        .cold => if (hot) {
            try p.errTok(.ignore_cold, tok);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
            cold = true;
        },
        else => try ignoredAttrErr(p, tok, attr.tag, "labels"),
    };
    return ty.withAttributes(p.arena, p.attr_application_buf.items);
}

pub fn applyStatementAttributes(p: *Parser, ty: Type, expr_start: TokenIndex, attr_buf_start: usize) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .fallthrough => if (p.tok_ids[p.tok_i] != .keyword_case and p.tok_ids[p.tok_i] != .keyword_default) {
            // TODO: this condition is not completely correct; the last statement of a compound
            // statement is also valid if it precedes a switch label (so intervening '}' are ok,
            // but only if they close a compound statement)
            try p.errTok(.invalid_fallthrough, expr_start);
        } else {
            try p.attr_application_buf.append(p.gpa, attr);
        },
        else => try p.errStr(.cannot_apply_attribute_to_statement, tok, @tagName(attr.tag)),
    };
    return ty.withAttributes(p.arena, p.attr_application_buf.items);
}

pub fn applyEnumeratorAttributes(p: *Parser, ty: Type, attr_buf_start: usize) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    const toks = p.attr_buf.items(.tok)[attr_buf_start..];
    p.attr_application_buf.items.len = 0;
    for (attrs, toks) |attr, tok| switch (attr.tag) {
        .deprecated, .unavailable => try p.attr_application_buf.append(p.gpa, attr),
        else => try ignoredAttrErr(p, tok, attr.tag, "enums"),
    };
    return ty.withAttributes(p.arena, p.attr_application_buf.items);
}

fn applyAligned(attr: Attribute, p: *Parser, ty: Type, tag: ?Diagnostics.Tag) !void {
    const base = ty.canonicalize(.standard);
    if (attr.args.aligned.alignment) |alignment| alignas: {
        if (attr.syntax != .keyword) break :alignas;

        const align_tok = attr.args.aligned.__name_tok;
        if (tag) |t| try p.errTok(t, align_tok);

        const default_align = base.alignof(p.comp);
        if (ty.isFunc()) {
            try p.errTok(.alignas_on_func, align_tok);
        } else if (alignment.requested < default_align) {
            try p.errExtra(.minimum_alignment, align_tok, .{ .unsigned = default_align });
        }
    }
    try p.attr_application_buf.append(p.gpa, attr);
}

fn applyTransparentUnion(attr: Attribute, p: *Parser, tok: TokenIndex, ty: Type) !void {
    const union_ty = ty.get(.@"union") orelse {
        return p.errTok(.transparent_union_wrong_type, tok);
    };
    // TODO validate union defined at end
    if (union_ty.data.record.isIncomplete()) return;
    const fields = union_ty.data.record.fields;
    if (fields.len == 0) {
        return p.errTok(.transparent_union_one_field, tok);
    }
    const first_field_size = fields[0].ty.bitSizeof(p.comp).?;
    for (fields[1..]) |field| {
        const field_size = field.ty.bitSizeof(p.comp).?;
        if (field_size == first_field_size) continue;
        const mapper = p.comp.string_interner.getSlowTypeMapper();
        const str = try std.fmt.allocPrint(
            p.comp.diagnostics.arena.allocator(),
            "'{s}' ({d}",
            .{ mapper.lookup(field.name), field_size },
        );
        try p.errStr(.transparent_union_size, field.name_tok, str);
        return p.errExtra(.transparent_union_size_note, fields[0].name_tok, .{ .unsigned = first_field_size });
    }

    try p.attr_application_buf.append(p.gpa, attr);
}

fn applyVectorSize(attr: Attribute, p: *Parser, tok: TokenIndex, ty: *Type) !void {
    const base = ty.base();
    const is_enum = ty.is(.@"enum");
    if (!(ty.isInt() or ty.isFloat()) or !ty.isReal() or (is_enum and p.comp.langopts.emulate == .gcc)) {
        try p.errStr(.invalid_vec_elem_ty, tok, try p.typeStr(ty.*));
        return error.ParsingFailed;
    }
    if (is_enum) return;

    const vec_bytes = attr.args.vector_size.bytes;
    const ty_size = ty.sizeof(p.comp).?;
    if (vec_bytes % ty_size != 0) {
        return p.errTok(.vec_size_not_multiple, tok);
    }
    const vec_size = vec_bytes / ty_size;

    const arr_ty = try p.arena.create(Type.Array);
    arr_ty.* = .{ .elem = ty.*, .len = vec_size };
    base.* = .{
        .specifier = .vector,
        .data = .{ .array = arr_ty },
    };
}

fn applyFormat(attr: Attribute, p: *Parser, ty: Type) !void {
    // TODO validate
    _ = ty;
    try p.attr_application_buf.append(p.gpa, attr);
}
