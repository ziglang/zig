//! This file has to do with parsing and rendering the ZIR text format.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Type = @import("type.zig").Type;
const Value = @import("value.zig").Value;
const TypedValue = @import("TypedValue.zig");
const ir = @import("ir.zig");
const IrModule = @import("Module.zig");

/// This struct is relevent only for the ZIR Module text format. It is not used for
/// semantic analysis of Zig source code.
pub const Decl = struct {
    name: []const u8,

    /// Hash of slice into the source of the part after the = and before the next instruction.
    contents_hash: std.zig.SrcHash,

    inst: *Inst,
};

/// These are instructions that correspond to the ZIR text format. See `ir.Inst` for
/// in-memory, analyzed instructions with types and values.
pub const Inst = struct {
    tag: Tag,
    /// Byte offset into the source.
    src: usize,
    /// Pre-allocated field for mapping ZIR text instructions to post-analysis instructions.
    analyzed_inst: ?*ir.Inst = null,

    /// These names are used directly as the instruction names in the text format.
    pub const Tag = enum {
        /// Function parameter value. These must be first in a function's main block,
        /// in respective order with the parameters.
        arg,
        /// A labeled block of code, which can return a value.
        block,
        /// Return a value from a `Block`.
        @"break",
        breakpoint,
        /// Same as `break` but without an operand; the operand is assumed to be the void value.
        breakvoid,
        call,
        compileerror,
        /// Special case, has no textual representation.
        @"const",
        /// Represents a pointer to a global decl by name.
        declref,
        /// Represents a pointer to a global decl by string name.
        declref_str,
        /// The syntax `@foo` is equivalent to `declval("foo")`.
        /// declval is equivalent to declref followed by deref.
        declval,
        /// Same as declval but the parameter is a `*Module.Decl` rather than a name.
        declval_in_module,
        boolnot,
        /// String Literal. Makes an anonymous Decl and then takes a pointer to it.
        str,
        int,
        inttype,
        ptrtoint,
        fieldptr,
        deref,
        as,
        @"asm",
        @"unreachable",
        @"return",
        returnvoid,
        @"fn",
        fntype,
        @"export",
        primitive,
        intcast,
        bitcast,
        floatcast,
        elemptr,
        add,
        sub,
        cmp_lt,
        cmp_lte,
        cmp_eq,
        cmp_gte,
        cmp_gt,
        cmp_neq,
        condbr,
        isnull,
        isnonnull,

        pub fn Type(tag: Tag) type {
            return switch (tag) {
                .arg,
                .breakpoint,
                .@"unreachable",
                .returnvoid,
                => NoOp,

                .boolnot,
                .deref,
                .@"return",
                .isnull,
                .isnonnull,
                => UnOp,

                .add,
                .sub,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                => BinOp,

                .block => Block,
                .@"break" => Break,
                .breakvoid => BreakVoid,
                .call => Call,
                .declref => DeclRef,
                .declref_str => DeclRefStr,
                .declval => DeclVal,
                .declval_in_module => DeclValInModule,
                .compileerror => CompileError,
                .@"const" => Const,
                .str => Str,
                .int => Int,
                .inttype => IntType,
                .ptrtoint => PtrToInt,
                .fieldptr => FieldPtr,
                .as => As,
                .@"asm" => Asm,
                .@"fn" => Fn,
                .@"export" => Export,
                .primitive => Primitive,
                .fntype => FnType,
                .intcast => IntCast,
                .bitcast => BitCast,
                .floatcast => FloatCast,
                .elemptr => ElemPtr,
                .condbr => CondBr,
            };
        }

        /// Returns whether the instruction is one of the control flow "noreturn" types.
        /// Function calls do not count.
        pub fn isNoReturn(tag: Tag) bool {
            return switch (tag) {
                .arg,
                .block,
                .breakpoint,
                .call,
                .@"const",
                .declref,
                .declref_str,
                .declval,
                .declval_in_module,
                .str,
                .int,
                .inttype,
                .ptrtoint,
                .fieldptr,
                .deref,
                .as,
                .@"asm",
                .@"fn",
                .fntype,
                .@"export",
                .primitive,
                .intcast,
                .bitcast,
                .floatcast,
                .elemptr,
                .add,
                .sub,
                .cmp_lt,
                .cmp_lte,
                .cmp_eq,
                .cmp_gte,
                .cmp_gt,
                .cmp_neq,
                .isnull,
                .isnonnull,
                .boolnot,
                => false,

                .condbr,
                .@"unreachable",
                .@"return",
                .returnvoid,
                .@"break",
                .breakvoid,
                .compileerror,
                => true,
            };
        }
    };

    /// Prefer `castTag` to this.
    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (@hasField(T, "base_tag")) {
            return base.castTag(T.base_tag);
        }
        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const tag = @intToEnum(Tag, field.value);
            if (base.tag == tag) {
                if (T == tag.Type()) {
                    return @fieldParentPtr(T, "base", base);
                }
                return null;
            }
        }
        unreachable;
    }

    pub fn castTag(base: *Inst, comptime tag: Tag) ?*tag.Type() {
        if (base.tag == tag) {
            return @fieldParentPtr(tag.Type(), "base", base);
        }
        return null;
    }

    pub const NoOp = struct {
        base: Inst,

        positionals: struct {},
        kw_args: struct {},
    };

    pub const UnOp = struct {
        base: Inst,

        positionals: struct {
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const BinOp = struct {
        base: Inst,

        positionals: struct {
            lhs: *Inst,
            rhs: *Inst,
        },
        kw_args: struct {},
    };

    pub const Block = struct {
        pub const base_tag = Tag.block;
        base: Inst,

        positionals: struct {
            body: Module.Body,
        },
        kw_args: struct {},
    };

    pub const Break = struct {
        pub const base_tag = Tag.@"break";
        base: Inst,

        positionals: struct {
            block: *Block,
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const BreakVoid = struct {
        pub const base_tag = Tag.breakvoid;
        base: Inst,

        positionals: struct {
            block: *Block,
        },
        kw_args: struct {},
    };

    pub const Call = struct {
        pub const base_tag = Tag.call;
        base: Inst,

        positionals: struct {
            func: *Inst,
            args: []*Inst,
        },
        kw_args: struct {
            modifier: std.builtin.CallOptions.Modifier = .auto,
        },
    };

    pub const DeclRef = struct {
        pub const base_tag = Tag.declref;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const DeclRefStr = struct {
        pub const base_tag = Tag.declref_str;
        base: Inst,

        positionals: struct {
            name: *Inst,
        },
        kw_args: struct {},
    };

    pub const DeclVal = struct {
        pub const base_tag = Tag.declval;
        base: Inst,

        positionals: struct {
            name: []const u8,
        },
        kw_args: struct {},
    };

    pub const DeclValInModule = struct {
        pub const base_tag = Tag.declval_in_module;
        base: Inst,

        positionals: struct {
            decl: *IrModule.Decl,
        },
        kw_args: struct {},
    };

    pub const CompileError = struct {
        pub const base_tag = Tag.compileerror;
        base: Inst,

        positionals: struct {
            msg: []const u8,
        },
        kw_args: struct {},
    };

    pub const Const = struct {
        pub const base_tag = Tag.@"const";
        base: Inst,

        positionals: struct {
            typed_value: TypedValue,
        },
        kw_args: struct {},
    };

    pub const Str = struct {
        pub const base_tag = Tag.str;
        base: Inst,

        positionals: struct {
            bytes: []const u8,
        },
        kw_args: struct {},
    };

    pub const Int = struct {
        pub const base_tag = Tag.int;
        base: Inst,

        positionals: struct {
            int: BigIntConst,
        },
        kw_args: struct {},
    };

    pub const PtrToInt = struct {
        pub const builtin_name = "@ptrToInt";
        pub const base_tag = Tag.ptrtoint;
        base: Inst,

        positionals: struct {
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const FieldPtr = struct {
        pub const base_tag = Tag.fieldptr;
        base: Inst,

        positionals: struct {
            object_ptr: *Inst,
            field_name: *Inst,
        },
        kw_args: struct {},
    };

    pub const As = struct {
        pub const base_tag = Tag.as;
        pub const builtin_name = "@as";
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            value: *Inst,
        },
        kw_args: struct {},
    };

    pub const Asm = struct {
        pub const base_tag = Tag.@"asm";
        base: Inst,

        positionals: struct {
            asm_source: *Inst,
            return_type: *Inst,
        },
        kw_args: struct {
            @"volatile": bool = false,
            output: ?*Inst = null,
            inputs: []*Inst = &[0]*Inst{},
            clobbers: []*Inst = &[0]*Inst{},
            args: []*Inst = &[0]*Inst{},
        },
    };

    pub const Fn = struct {
        pub const base_tag = Tag.@"fn";
        base: Inst,

        positionals: struct {
            fn_type: *Inst,
            body: Module.Body,
        },
        kw_args: struct {},
    };

    pub const FnType = struct {
        pub const base_tag = Tag.fntype;
        base: Inst,

        positionals: struct {
            param_types: []*Inst,
            return_type: *Inst,
        },
        kw_args: struct {
            cc: std.builtin.CallingConvention = .Unspecified,
        },
    };

    pub const IntType = struct {
        pub const base_tag = Tag.inttype;
        base: Inst,

        positionals: struct {
            signed: *Inst,
            bits: *Inst,
        },
        kw_args: struct {},
    };

    pub const Export = struct {
        pub const base_tag = Tag.@"export";
        base: Inst,

        positionals: struct {
            symbol_name: *Inst,
            decl_name: []const u8,
        },
        kw_args: struct {},
    };

    pub const Primitive = struct {
        pub const base_tag = Tag.primitive;
        base: Inst,

        positionals: struct {
            tag: Builtin,
        },
        kw_args: struct {},

        pub const Builtin = enum {
            i8,
            u8,
            i16,
            u16,
            i32,
            u32,
            i64,
            u64,
            isize,
            usize,
            c_short,
            c_ushort,
            c_int,
            c_uint,
            c_long,
            c_ulong,
            c_longlong,
            c_ulonglong,
            c_longdouble,
            c_void,
            f16,
            f32,
            f64,
            f128,
            bool,
            void,
            noreturn,
            type,
            anyerror,
            comptime_int,
            comptime_float,
            @"true",
            @"false",
            @"null",
            @"undefined",
            void_value,

            pub fn toTypedValue(self: Builtin) TypedValue {
                return switch (self) {
                    .i8 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i8_type) },
                    .u8 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u8_type) },
                    .i16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i16_type) },
                    .u16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u16_type) },
                    .i32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i32_type) },
                    .u32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u32_type) },
                    .i64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.i64_type) },
                    .u64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.u64_type) },
                    .isize => .{ .ty = Type.initTag(.type), .val = Value.initTag(.isize_type) },
                    .usize => .{ .ty = Type.initTag(.type), .val = Value.initTag(.usize_type) },
                    .c_short => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_short_type) },
                    .c_ushort => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ushort_type) },
                    .c_int => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_int_type) },
                    .c_uint => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_uint_type) },
                    .c_long => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_long_type) },
                    .c_ulong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ulong_type) },
                    .c_longlong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_longlong_type) },
                    .c_ulonglong => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_ulonglong_type) },
                    .c_longdouble => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_longdouble_type) },
                    .c_void => .{ .ty = Type.initTag(.type), .val = Value.initTag(.c_void_type) },
                    .f16 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f16_type) },
                    .f32 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f32_type) },
                    .f64 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f64_type) },
                    .f128 => .{ .ty = Type.initTag(.type), .val = Value.initTag(.f128_type) },
                    .bool => .{ .ty = Type.initTag(.type), .val = Value.initTag(.bool_type) },
                    .void => .{ .ty = Type.initTag(.type), .val = Value.initTag(.void_type) },
                    .noreturn => .{ .ty = Type.initTag(.type), .val = Value.initTag(.noreturn_type) },
                    .type => .{ .ty = Type.initTag(.type), .val = Value.initTag(.type_type) },
                    .anyerror => .{ .ty = Type.initTag(.type), .val = Value.initTag(.anyerror_type) },
                    .comptime_int => .{ .ty = Type.initTag(.type), .val = Value.initTag(.comptime_int_type) },
                    .comptime_float => .{ .ty = Type.initTag(.type), .val = Value.initTag(.comptime_float_type) },
                    .@"true" => .{ .ty = Type.initTag(.bool), .val = Value.initTag(.bool_true) },
                    .@"false" => .{ .ty = Type.initTag(.bool), .val = Value.initTag(.bool_false) },
                    .@"null" => .{ .ty = Type.initTag(.@"null"), .val = Value.initTag(.null_value) },
                    .@"undefined" => .{ .ty = Type.initTag(.@"undefined"), .val = Value.initTag(.undef) },
                    .void_value => .{ .ty = Type.initTag(.void), .val = Value.initTag(.the_one_possible_value) },
                };
            }
        };
    };

    pub const FloatCast = struct {
        pub const base_tag = Tag.floatcast;
        pub const builtin_name = "@floatCast";
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const IntCast = struct {
        pub const base_tag = Tag.intcast;
        pub const builtin_name = "@intCast";
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const BitCast = struct {
        pub const base_tag = Tag.bitcast;
        pub const builtin_name = "@bitCast";
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            operand: *Inst,
        },
        kw_args: struct {},
    };

    pub const ElemPtr = struct {
        pub const base_tag = Tag.elemptr;
        base: Inst,

        positionals: struct {
            array_ptr: *Inst,
            index: *Inst,
        },
        kw_args: struct {},
    };

    pub const CondBr = struct {
        pub const base_tag = Tag.condbr;
        base: Inst,

        positionals: struct {
            condition: *Inst,
            then_body: Module.Body,
            else_body: Module.Body,
        },
        kw_args: struct {},
    };
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Module = struct {
    decls: []*Decl,
    arena: std.heap.ArenaAllocator,
    error_msg: ?ErrorMsg = null,

    pub const Body = struct {
        instructions: []*Inst,
    };

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        allocator.free(self.decls);
        self.arena.deinit();
        self.* = undefined;
    }

    /// This is a debugging utility for rendering the tree to stderr.
    pub fn dump(self: Module) void {
        self.writeToStream(std.heap.page_allocator, std.io.getStdErr().outStream()) catch {};
    }

    const DeclAndIndex = struct {
        decl: *Decl,
        index: usize,
    };

    /// TODO Look into making a table to speed this up.
    pub fn findDecl(self: Module, name: []const u8) ?DeclAndIndex {
        for (self.decls) |decl, i| {
            if (mem.eql(u8, decl.name, name)) {
                return DeclAndIndex{
                    .decl = decl,
                    .index = i,
                };
            }
        }
        return null;
    }

    pub fn findInstDecl(self: Module, inst: *Inst) ?DeclAndIndex {
        for (self.decls) |decl, i| {
            if (decl.inst == inst) {
                return DeclAndIndex{
                    .decl = decl,
                    .index = i,
                };
            }
        }
        return null;
    }

    /// The allocator is used for temporary storage, but this function always returns
    /// with no resources allocated.
    pub fn writeToStream(self: Module, allocator: *Allocator, stream: anytype) !void {
        var write = Writer{
            .module = &self,
            .inst_table = InstPtrTable.init(allocator),
            .block_table = std.AutoHashMap(*Inst.Block, []const u8).init(allocator),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .indent = 2,
        };
        defer write.arena.deinit();
        defer write.inst_table.deinit();
        defer write.block_table.deinit();

        // First, build a map of *Inst to @ or % indexes
        try write.inst_table.ensureCapacity(self.decls.len);

        for (self.decls) |decl, decl_i| {
            try write.inst_table.putNoClobber(decl.inst, .{ .inst = decl.inst, .index = null, .name = decl.name });

            if (decl.inst.cast(Inst.Fn)) |fn_inst| {
                for (fn_inst.positionals.body.instructions) |inst, inst_i| {
                    try write.inst_table.putNoClobber(inst, .{ .inst = inst, .index = inst_i, .name = undefined });
                }
            }
        }

        for (self.decls) |decl, i| {
            try stream.print("@{} ", .{decl.name});
            try write.writeInstToStream(stream, decl.inst);
            try stream.writeByte('\n');
        }
    }
};

const InstPtrTable = std.AutoHashMap(*Inst, struct { inst: *Inst, index: ?usize, name: []const u8 });

const Writer = struct {
    module: *const Module,
    inst_table: InstPtrTable,
    block_table: std.AutoHashMap(*Inst.Block, []const u8),
    arena: std.heap.ArenaAllocator,
    indent: usize,

    fn writeInstToStream(
        self: *Writer,
        stream: anytype,
        inst: *Inst,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        inline for (@typeInfo(Inst.Tag).Enum.fields) |enum_field| {
            const expected_tag = @field(Inst.Tag, enum_field.name);
            if (inst.tag == expected_tag) {
                return self.writeInstToStreamGeneric(stream, expected_tag, inst);
            }
        }
        unreachable; // all tags handled
    }

    fn writeInstToStreamGeneric(
        self: *Writer,
        stream: anytype,
        comptime inst_tag: Inst.Tag,
        base: *Inst,
    ) (@TypeOf(stream).Error || error{OutOfMemory})!void {
        const SpecificInst = inst_tag.Type();
        const inst = @fieldParentPtr(SpecificInst, "base", base);
        const Positionals = @TypeOf(inst.positionals);
        try stream.writeAll("= " ++ @tagName(inst_tag) ++ "(");
        const pos_fields = @typeInfo(Positionals).Struct.fields;
        inline for (pos_fields) |arg_field, i| {
            if (i != 0) {
                try stream.writeAll(", ");
            }
            try self.writeParamToStream(stream, @field(inst.positionals, arg_field.name));
        }

        comptime var need_comma = pos_fields.len != 0;
        const KW_Args = @TypeOf(inst.kw_args);
        inline for (@typeInfo(KW_Args).Struct.fields) |arg_field, i| {
            if (@typeInfo(arg_field.field_type) == .Optional) {
                if (@field(inst.kw_args, arg_field.name)) |non_optional| {
                    if (need_comma) try stream.writeAll(", ");
                    try stream.print("{}=", .{arg_field.name});
                    try self.writeParamToStream(stream, non_optional);
                    need_comma = true;
                }
            } else {
                if (need_comma) try stream.writeAll(", ");
                try stream.print("{}=", .{arg_field.name});
                try self.writeParamToStream(stream, @field(inst.kw_args, arg_field.name));
                need_comma = true;
            }
        }

        try stream.writeByte(')');
    }

    fn writeParamToStream(self: *Writer, stream: anytype, param: anytype) !void {
        if (@typeInfo(@TypeOf(param)) == .Enum) {
            return stream.writeAll(@tagName(param));
        }
        switch (@TypeOf(param)) {
            *Inst => return self.writeInstParamToStream(stream, param),
            []*Inst => {
                try stream.writeByte('[');
                for (param) |inst, i| {
                    if (i != 0) {
                        try stream.writeAll(", ");
                    }
                    try self.writeInstParamToStream(stream, inst);
                }
                try stream.writeByte(']');
            },
            Module.Body => {
                try stream.writeAll("{\n");
                for (param.instructions) |inst, i| {
                    try stream.writeByteNTimes(' ', self.indent);
                    try stream.print("%{} ", .{i});
                    if (inst.cast(Inst.Block)) |block| {
                        const name = try std.fmt.allocPrint(&self.arena.allocator, "label_{}", .{i});
                        try self.block_table.put(block, name);
                    }
                    self.indent += 2;
                    try self.writeInstToStream(stream, inst);
                    self.indent -= 2;
                    try stream.writeByte('\n');
                }
                try stream.writeByteNTimes(' ', self.indent - 2);
                try stream.writeByte('}');
            },
            bool => return stream.writeByte("01"[@boolToInt(param)]),
            []u8, []const u8 => return std.zig.renderStringLiteral(param, stream),
            BigIntConst, usize => return stream.print("{}", .{param}),
            TypedValue => unreachable, // this is a special case
            *IrModule.Decl => unreachable, // this is a special case
            *Inst.Block => {
                const name = self.block_table.get(param).?;
                return std.zig.renderStringLiteral(name, stream);
            },
            else => |T| @compileError("unimplemented: rendering parameter of type " ++ @typeName(T)),
        }
    }

    fn writeInstParamToStream(self: *Writer, stream: anytype, inst: *Inst) !void {
        if (self.inst_table.get(inst)) |info| {
            if (info.index) |i| {
                try stream.print("%{}", .{info.index});
            } else {
                try stream.print("@{}", .{info.name});
            }
        } else if (inst.cast(Inst.DeclVal)) |decl_val| {
            try stream.print("@{}", .{decl_val.positionals.name});
        } else if (inst.cast(Inst.DeclValInModule)) |decl_val| {
            try stream.print("@{}", .{decl_val.positionals.decl.name});
        } else {
            // This should be unreachable in theory, but since ZIR is used for debugging the compiler
            // we output some debug text instead.
            try stream.print("?{}?", .{@tagName(inst.tag)});
        }
    }
};

pub fn parse(allocator: *Allocator, source: [:0]const u8) Allocator.Error!Module {
    var global_name_map = std.StringHashMap(*Inst).init(allocator);
    defer global_name_map.deinit();

    var parser: Parser = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .i = 0,
        .source = source,
        .global_name_map = &global_name_map,
        .decls = .{},
        .unnamed_index = 0,
        .block_table = std.StringHashMap(*Inst.Block).init(allocator),
    };
    defer parser.block_table.deinit();
    errdefer parser.arena.deinit();

    parser.parseRoot() catch |err| switch (err) {
        error.ParseFailure => {
            assert(parser.error_msg != null);
        },
        else => |e| return e,
    };

    return Module{
        .decls = parser.decls.toOwnedSlice(allocator),
        .arena = parser.arena,
        .error_msg = parser.error_msg,
    };
}

const Parser = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    i: usize,
    source: [:0]const u8,
    decls: std.ArrayListUnmanaged(*Decl),
    global_name_map: *std.StringHashMap(*Inst),
    error_msg: ?ErrorMsg = null,
    unnamed_index: usize,
    block_table: std.StringHashMap(*Inst.Block),

    const Body = struct {
        instructions: std.ArrayList(*Inst),
        name_map: *std.StringHashMap(*Inst),
    };

    fn parseBody(self: *Parser, body_ctx: ?*Body) !Module.Body {
        var name_map = std.StringHashMap(*Inst).init(self.allocator);
        defer name_map.deinit();

        var body_context = Body{
            .instructions = std.ArrayList(*Inst).init(self.allocator),
            .name_map = if (body_ctx) |bctx| bctx.name_map else &name_map,
        };
        defer body_context.instructions.deinit();

        try requireEatBytes(self, "{");
        skipSpace(self);

        while (true) : (self.i += 1) switch (self.source[self.i]) {
            ';' => _ = try skipToAndOver(self, '\n'),
            '%' => {
                self.i += 1;
                const ident = try skipToAndOver(self, ' ');
                skipSpace(self);
                try requireEatBytes(self, "=");
                skipSpace(self);
                const decl = try parseInstruction(self, &body_context, ident);
                const ident_index = body_context.instructions.items.len;
                if (try body_context.name_map.fetchPut(ident, decl.inst)) |_| {
                    return self.fail("redefinition of identifier '{}'", .{ident});
                }
                try body_context.instructions.append(decl.inst);
                continue;
            },
            ' ', '\n' => continue,
            '}' => {
                self.i += 1;
                break;
            },
            else => |byte| return self.failByte(byte),
        };

        // Move the instructions to the arena
        const instrs = try self.arena.allocator.alloc(*Inst, body_context.instructions.items.len);
        mem.copy(*Inst, instrs, body_context.instructions.items);
        return Module.Body{ .instructions = instrs };
    }

    fn parseStringLiteral(self: *Parser) ![]u8 {
        const start = self.i;
        try self.requireEatBytes("\"");

        while (true) : (self.i += 1) switch (self.source[self.i]) {
            '"' => {
                self.i += 1;
                const span = self.source[start..self.i];
                var bad_index: usize = undefined;
                const parsed = std.zig.parseStringLiteral(&self.arena.allocator, span, &bad_index) catch |err| switch (err) {
                    error.InvalidCharacter => {
                        self.i = start + bad_index;
                        const bad_byte = self.source[self.i];
                        return self.fail("invalid string literal character: '{c}'\n", .{bad_byte});
                    },
                    else => |e| return e,
                };
                return parsed;
            },
            '\\' => {
                self.i += 1;
                continue;
            },
            0 => return self.failByte(0),
            else => continue,
        };
    }

    fn parseIntegerLiteral(self: *Parser) !BigIntConst {
        const start = self.i;
        if (self.source[self.i] == '-') self.i += 1;
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            '0'...'9' => continue,
            else => break,
        };
        const number_text = self.source[start..self.i];
        const base = 10;
        // TODO reuse the same array list for this
        const limbs_buffer_len = std.math.big.int.calcSetStringLimbsBufferLen(base, number_text.len);
        const limbs_buffer = try self.allocator.alloc(std.math.big.Limb, limbs_buffer_len);
        defer self.allocator.free(limbs_buffer);
        const limb_len = std.math.big.int.calcSetStringLimbCount(base, number_text.len);
        const limbs = try self.arena.allocator.alloc(std.math.big.Limb, limb_len);
        var result = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
        result.setString(base, number_text, limbs_buffer, self.allocator) catch |err| switch (err) {
            error.InvalidCharacter => {
                self.i = start;
                return self.fail("invalid digit in integer literal", .{});
            },
        };
        return result.toConst();
    }

    fn parseRoot(self: *Parser) !void {
        // The IR format is designed so that it can be tokenized and parsed at the same time.
        while (true) {
            switch (self.source[self.i]) {
                ';' => _ = try skipToAndOver(self, '\n'),
                '@' => {
                    self.i += 1;
                    const ident = try skipToAndOver(self, ' ');
                    skipSpace(self);
                    try requireEatBytes(self, "=");
                    skipSpace(self);
                    const decl = try parseInstruction(self, null, ident);
                    const ident_index = self.decls.items.len;
                    if (try self.global_name_map.fetchPut(ident, decl.inst)) |_| {
                        return self.fail("redefinition of identifier '{}'", .{ident});
                    }
                    try self.decls.append(self.allocator, decl);
                },
                ' ', '\n' => self.i += 1,
                0 => break,
                else => |byte| return self.fail("unexpected byte: '{c}'", .{byte}),
            }
        }
    }

    fn eatByte(self: *Parser, byte: u8) bool {
        if (self.source[self.i] != byte) return false;
        self.i += 1;
        return true;
    }

    fn skipSpace(self: *Parser) void {
        while (self.source[self.i] == ' ' or self.source[self.i] == '\n') {
            self.i += 1;
        }
    }

    fn requireEatBytes(self: *Parser, bytes: []const u8) !void {
        const start = self.i;
        for (bytes) |byte| {
            if (self.source[self.i] != byte) {
                self.i = start;
                return self.fail("expected '{}'", .{bytes});
            }
            self.i += 1;
        }
    }

    fn skipToAndOver(self: *Parser, byte: u8) ![]const u8 {
        const start_i = self.i;
        while (self.source[self.i] != 0) : (self.i += 1) {
            if (self.source[self.i] == byte) {
                const result = self.source[start_i..self.i];
                self.i += 1;
                return result;
            }
        }
        return self.fail("unexpected EOF", .{});
    }

    /// ParseFailure is an internal error code; handled in `parse`.
    const InnerError = error{ ParseFailure, OutOfMemory };

    fn failByte(self: *Parser, byte: u8) InnerError {
        if (byte == 0) {
            return self.fail("unexpected EOF", .{});
        } else {
            return self.fail("unexpected byte: '{c}'", .{byte});
        }
    }

    fn fail(self: *Parser, comptime format: []const u8, args: anytype) InnerError {
        @setCold(true);
        self.error_msg = ErrorMsg{
            .byte_offset = self.i,
            .msg = try std.fmt.allocPrint(&self.arena.allocator, format, args),
        };
        return error.ParseFailure;
    }

    fn parseInstruction(self: *Parser, body_ctx: ?*Body, name: []const u8) InnerError!*Decl {
        const contents_start = self.i;
        const fn_name = try skipToAndOver(self, '(');
        inline for (@typeInfo(Inst.Tag).Enum.fields) |field| {
            if (mem.eql(u8, field.name, fn_name)) {
                const tag = @field(Inst.Tag, field.name);
                return parseInstructionGeneric(self, field.name, tag.Type(), tag, body_ctx, name, contents_start);
            }
        }
        return self.fail("unknown instruction '{}'", .{fn_name});
    }

    fn parseInstructionGeneric(
        self: *Parser,
        comptime fn_name: []const u8,
        comptime InstType: type,
        tag: Inst.Tag,
        body_ctx: ?*Body,
        inst_name: []const u8,
        contents_start: usize,
    ) InnerError!*Decl {
        const inst_specific = try self.arena.allocator.create(InstType);
        inst_specific.base = .{
            .src = self.i,
            .tag = tag,
        };

        if (InstType == Inst.Block) {
            try self.block_table.put(inst_name, inst_specific);
        }

        if (@hasField(InstType, "ty")) {
            inst_specific.ty = opt_type orelse {
                return self.fail("instruction '" ++ fn_name ++ "' requires type", .{});
            };
        }

        const Positionals = @TypeOf(inst_specific.positionals);
        inline for (@typeInfo(Positionals).Struct.fields) |arg_field| {
            if (self.source[self.i] == ',') {
                self.i += 1;
                skipSpace(self);
            } else if (self.source[self.i] == ')') {
                return self.fail("expected positional parameter '{}'", .{arg_field.name});
            }
            @field(inst_specific.positionals, arg_field.name) = try parseParameterGeneric(
                self,
                arg_field.field_type,
                body_ctx,
            );
            skipSpace(self);
        }

        const KW_Args = @TypeOf(inst_specific.kw_args);
        inst_specific.kw_args = .{}; // assign defaults
        skipSpace(self);
        while (eatByte(self, ',')) {
            skipSpace(self);
            const name = try skipToAndOver(self, '=');
            inline for (@typeInfo(KW_Args).Struct.fields) |arg_field| {
                const field_name = arg_field.name;
                if (mem.eql(u8, name, field_name)) {
                    const NonOptional = switch (@typeInfo(arg_field.field_type)) {
                        .Optional => |info| info.child,
                        else => arg_field.field_type,
                    };
                    @field(inst_specific.kw_args, field_name) = try parseParameterGeneric(self, NonOptional, body_ctx);
                    break;
                }
            } else {
                return self.fail("unrecognized keyword parameter: '{}'", .{name});
            }
            skipSpace(self);
        }
        try requireEatBytes(self, ")");

        const decl = try self.arena.allocator.create(Decl);
        decl.* = .{
            .name = inst_name,
            .contents_hash = std.zig.hashSrc(self.source[contents_start..self.i]),
            .inst = &inst_specific.base,
        };
        //std.debug.warn("parsed {} = '{}'\n", .{ inst_specific.base.name, inst_specific.base.contents });

        return decl;
    }

    fn parseParameterGeneric(self: *Parser, comptime T: type, body_ctx: ?*Body) !T {
        if (@typeInfo(T) == .Enum) {
            const start = self.i;
            while (true) : (self.i += 1) switch (self.source[self.i]) {
                ' ', '\n', ',', ')' => {
                    const enum_name = self.source[start..self.i];
                    return std.meta.stringToEnum(T, enum_name) orelse {
                        return self.fail("tag '{}' not a member of enum '{}'", .{ enum_name, @typeName(T) });
                    };
                },
                0 => return self.failByte(0),
                else => continue,
            };
        }
        switch (T) {
            Module.Body => return parseBody(self, body_ctx),
            bool => {
                const bool_value = switch (self.source[self.i]) {
                    '0' => false,
                    '1' => true,
                    else => |byte| return self.fail("expected '0' or '1' for boolean value, found {c}", .{byte}),
                };
                self.i += 1;
                return bool_value;
            },
            []*Inst => {
                try requireEatBytes(self, "[");
                skipSpace(self);
                if (eatByte(self, ']')) return &[0]*Inst{};

                var instructions = std.ArrayList(*Inst).init(&self.arena.allocator);
                while (true) {
                    skipSpace(self);
                    try instructions.append(try parseParameterInst(self, body_ctx));
                    skipSpace(self);
                    if (!eatByte(self, ',')) break;
                }
                try requireEatBytes(self, "]");
                return instructions.toOwnedSlice();
            },
            *Inst => return parseParameterInst(self, body_ctx),
            []u8, []const u8 => return self.parseStringLiteral(),
            BigIntConst => return self.parseIntegerLiteral(),
            usize => {
                const big_int = try self.parseIntegerLiteral();
                return big_int.to(usize) catch |err| return self.fail("integer literal: {}", .{@errorName(err)});
            },
            TypedValue => return self.fail("'const' is a special instruction; not legal in ZIR text", .{}),
            *IrModule.Decl => return self.fail("'declval_in_module' is a special instruction; not legal in ZIR text", .{}),
            *Inst.Block => {
                const name = try self.parseStringLiteral();
                return self.block_table.get(name).?;
            },
            else => @compileError("Unimplemented: ir parseParameterGeneric for type " ++ @typeName(T)),
        }
        return self.fail("TODO parse parameter {}", .{@typeName(T)});
    }

    fn parseParameterInst(self: *Parser, body_ctx: ?*Body) !*Inst {
        const local_ref = switch (self.source[self.i]) {
            '@' => false,
            '%' => true,
            else => |byte| return self.fail("unexpected byte: '{c}'", .{byte}),
        };
        const map = if (local_ref)
            if (body_ctx) |bc|
                bc.name_map
            else
                return self.fail("referencing a % instruction in global scope", .{})
        else
            self.global_name_map;

        self.i += 1;
        const name_start = self.i;
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            0, ' ', '\n', ',', ')', ']' => break,
            else => continue,
        };
        const ident = self.source[name_start..self.i];
        return map.get(ident) orelse {
            const bad_name = self.source[name_start - 1 .. self.i];
            const src = name_start - 1;
            if (local_ref) {
                self.i = src;
                return self.fail("unrecognized identifier: {}", .{bad_name});
            } else {
                const declval = try self.arena.allocator.create(Inst.DeclVal);
                declval.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.DeclVal.base_tag,
                    },
                    .positionals = .{ .name = ident },
                    .kw_args = .{},
                };
                return &declval.base;
            }
        };
    }

    fn generateName(self: *Parser) ![]u8 {
        const result = try std.fmt.allocPrint(&self.arena.allocator, "unnamed${}", .{self.unnamed_index});
        self.unnamed_index += 1;
        return result;
    }
};

pub fn emit(allocator: *Allocator, old_module: IrModule) !Module {
    var ctx: EmitZIR = .{
        .allocator = allocator,
        .decls = .{},
        .arena = std.heap.ArenaAllocator.init(allocator),
        .old_module = &old_module,
        .next_auto_name = 0,
        .names = std.StringHashMap(void).init(allocator),
        .primitive_table = std.AutoHashMap(Inst.Primitive.Builtin, *Decl).init(allocator),
        .indent = 0,
        .block_table = std.AutoHashMap(*ir.Inst.Block, *Inst.Block).init(allocator),
    };
    defer ctx.block_table.deinit();
    defer ctx.decls.deinit(allocator);
    defer ctx.names.deinit();
    defer ctx.primitive_table.deinit();
    errdefer ctx.arena.deinit();

    try ctx.emit();

    return Module{
        .decls = ctx.decls.toOwnedSlice(allocator),
        .arena = ctx.arena,
    };
}

const EmitZIR = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    old_module: *const IrModule,
    decls: std.ArrayListUnmanaged(*Decl),
    names: std.StringHashMap(void),
    next_auto_name: usize,
    primitive_table: std.AutoHashMap(Inst.Primitive.Builtin, *Decl),
    indent: usize,
    block_table: std.AutoHashMap(*ir.Inst.Block, *Inst.Block),

    fn emit(self: *EmitZIR) !void {
        // Put all the Decls in a list and sort them by name to avoid nondeterminism introduced
        // by the hash table.
        var src_decls = std.ArrayList(*IrModule.Decl).init(self.allocator);
        defer src_decls.deinit();
        try src_decls.ensureCapacity(self.old_module.decl_table.items().len);
        try self.decls.ensureCapacity(self.allocator, self.old_module.decl_table.items().len);
        try self.names.ensureCapacity(self.old_module.decl_table.items().len);

        for (self.old_module.decl_table.items()) |entry| {
            const decl = entry.value;
            src_decls.appendAssumeCapacity(decl);
            self.names.putAssumeCapacityNoClobber(mem.spanZ(decl.name), {});
        }
        std.sort.sort(*IrModule.Decl, src_decls.items, {}, (struct {
            fn lessThan(context: void, a: *IrModule.Decl, b: *IrModule.Decl) bool {
                return a.src_index < b.src_index;
            }
        }).lessThan);

        // Emit all the decls.
        for (src_decls.items) |ir_decl| {
            switch (ir_decl.analysis) {
                .unreferenced => continue,

                .complete => {},
                .codegen_failure => {}, // We still can emit the ZIR.
                .codegen_failure_retryable => {}, // We still can emit the ZIR.

                .in_progress => unreachable,
                .outdated => unreachable,

                .sema_failure,
                .sema_failure_retryable,
                .dependency_failure,
                => if (self.old_module.failed_decls.get(ir_decl)) |err_msg| {
                    const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                    fail_inst.* = .{
                        .base = .{
                            .src = ir_decl.src(),
                            .tag = Inst.CompileError.base_tag,
                        },
                        .positionals = .{
                            .msg = try self.arena.allocator.dupe(u8, err_msg.msg),
                        },
                        .kw_args = .{},
                    };
                    const decl = try self.arena.allocator.create(Decl);
                    decl.* = .{
                        .name = mem.spanZ(ir_decl.name),
                        .contents_hash = undefined,
                        .inst = &fail_inst.base,
                    };
                    try self.decls.append(self.allocator, decl);
                    continue;
                },
            }
            if (self.old_module.export_owners.get(ir_decl)) |exports| {
                for (exports) |module_export| {
                    const symbol_name = try self.emitStringLiteral(module_export.src, module_export.options.name);
                    const export_inst = try self.arena.allocator.create(Inst.Export);
                    export_inst.* = .{
                        .base = .{
                            .src = module_export.src,
                            .tag = Inst.Export.base_tag,
                        },
                        .positionals = .{
                            .symbol_name = symbol_name.inst,
                            .decl_name = mem.spanZ(module_export.exported_decl.name),
                        },
                        .kw_args = .{},
                    };
                    _ = try self.emitUnnamedDecl(&export_inst.base);
                }
            } else {
                const new_decl = try self.emitTypedValue(ir_decl.src(), ir_decl.typed_value.most_recent.typed_value);
                new_decl.name = try self.arena.allocator.dupe(u8, mem.spanZ(ir_decl.name));
            }
        }
    }

    const ZirBody = struct {
        inst_table: *std.AutoHashMap(*ir.Inst, *Inst),
        instructions: *std.ArrayList(*Inst),
    };

    fn resolveInst(self: *EmitZIR, new_body: ZirBody, inst: *ir.Inst) !*Inst {
        if (inst.cast(ir.Inst.Constant)) |const_inst| {
            const new_inst = if (const_inst.val.cast(Value.Payload.Function)) |func_pl| blk: {
                const owner_decl = func_pl.func.owner_decl;
                break :blk try self.emitDeclVal(inst.src, mem.spanZ(owner_decl.name));
            } else if (const_inst.val.cast(Value.Payload.DeclRef)) |declref| blk: {
                const decl_ref = try self.emitDeclRef(inst.src, declref.decl);
                try new_body.instructions.append(decl_ref);
                break :blk decl_ref;
            } else blk: {
                break :blk (try self.emitTypedValue(inst.src, .{ .ty = inst.ty, .val = const_inst.val })).inst;
            };
            try new_body.inst_table.putNoClobber(inst, new_inst);
            return new_inst;
        } else {
            return new_body.inst_table.get(inst).?;
        }
    }

    fn emitDeclVal(self: *EmitZIR, src: usize, decl_name: []const u8) !*Inst {
        const declval = try self.arena.allocator.create(Inst.DeclVal);
        declval.* = .{
            .base = .{
                .src = src,
                .tag = Inst.DeclVal.base_tag,
            },
            .positionals = .{ .name = try self.arena.allocator.dupe(u8, decl_name) },
            .kw_args = .{},
        };
        return &declval.base;
    }

    fn emitComptimeIntVal(self: *EmitZIR, src: usize, val: Value) !*Decl {
        const big_int_space = try self.arena.allocator.create(Value.BigIntSpace);
        const int_inst = try self.arena.allocator.create(Inst.Int);
        int_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.Int.base_tag,
            },
            .positionals = .{
                .int = val.toBigInt(big_int_space),
            },
            .kw_args = .{},
        };
        return self.emitUnnamedDecl(&int_inst.base);
    }

    fn emitDeclRef(self: *EmitZIR, src: usize, module_decl: *IrModule.Decl) !*Inst {
        const declref_inst = try self.arena.allocator.create(Inst.DeclRef);
        declref_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.DeclRef.base_tag,
            },
            .positionals = .{
                .name = mem.spanZ(module_decl.name),
            },
            .kw_args = .{},
        };
        return &declref_inst.base;
    }

    fn emitTypedValue(self: *EmitZIR, src: usize, typed_value: TypedValue) Allocator.Error!*Decl {
        const allocator = &self.arena.allocator;
        if (typed_value.val.cast(Value.Payload.DeclRef)) |decl_ref| {
            const decl = decl_ref.decl;
            return try self.emitUnnamedDecl(try self.emitDeclRef(src, decl));
        }
        switch (typed_value.ty.zigTypeTag()) {
            .Pointer => {
                const ptr_elem_type = typed_value.ty.elemType();
                switch (ptr_elem_type.zigTypeTag()) {
                    .Array => {
                        // TODO more checks to make sure this can be emitted as a string literal
                        //const array_elem_type = ptr_elem_type.elemType();
                        //if (array_elem_type.eql(Type.initTag(.u8)) and
                        //    ptr_elem_type.hasSentinel(Value.initTag(.zero)))
                        //{
                        //}
                        const bytes = typed_value.val.toAllocatedBytes(allocator) catch |err| switch (err) {
                            error.AnalysisFail => unreachable,
                            else => |e| return e,
                        };
                        return self.emitStringLiteral(src, bytes);
                    },
                    else => |t| std.debug.panic("TODO implement emitTypedValue for pointer to {}", .{@tagName(t)}),
                }
            },
            .ComptimeInt => return self.emitComptimeIntVal(src, typed_value.val),
            .Int => {
                const as_inst = try self.arena.allocator.create(Inst.As);
                as_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.As.base_tag,
                    },
                    .positionals = .{
                        .dest_type = (try self.emitType(src, typed_value.ty)).inst,
                        .value = (try self.emitComptimeIntVal(src, typed_value.val)).inst,
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&as_inst.base);
            },
            .Type => {
                const ty = typed_value.val.toType();
                return self.emitType(src, ty);
            },
            .Fn => {
                const module_fn = typed_value.val.cast(Value.Payload.Function).?.func;

                var inst_table = std.AutoHashMap(*ir.Inst, *Inst).init(self.allocator);
                defer inst_table.deinit();

                var instructions = std.ArrayList(*Inst).init(self.allocator);
                defer instructions.deinit();

                switch (module_fn.analysis) {
                    .queued => unreachable,
                    .in_progress => unreachable,
                    .success => |body| {
                        try self.emitBody(body, &inst_table, &instructions);
                    },
                    .sema_failure => {
                        const err_msg = self.old_module.failed_decls.get(module_fn.owner_decl).?;
                        const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                        fail_inst.* = .{
                            .base = .{
                                .src = src,
                                .tag = Inst.CompileError.base_tag,
                            },
                            .positionals = .{
                                .msg = try self.arena.allocator.dupe(u8, err_msg.msg),
                            },
                            .kw_args = .{},
                        };
                        try instructions.append(&fail_inst.base);
                    },
                    .dependency_failure => {
                        const fail_inst = try self.arena.allocator.create(Inst.CompileError);
                        fail_inst.* = .{
                            .base = .{
                                .src = src,
                                .tag = Inst.CompileError.base_tag,
                            },
                            .positionals = .{
                                .msg = try self.arena.allocator.dupe(u8, "depends on another failed Decl"),
                            },
                            .kw_args = .{},
                        };
                        try instructions.append(&fail_inst.base);
                    },
                }

                const fn_type = try self.emitType(src, typed_value.ty);

                const arena_instrs = try self.arena.allocator.alloc(*Inst, instructions.items.len);
                mem.copy(*Inst, arena_instrs, instructions.items);

                const fn_inst = try self.arena.allocator.create(Inst.Fn);
                fn_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.Fn.base_tag,
                    },
                    .positionals = .{
                        .fn_type = fn_type.inst,
                        .body = .{ .instructions = arena_instrs },
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&fn_inst.base);
            },
            .Array => {
                // TODO more checks to make sure this can be emitted as a string literal
                //const array_elem_type = ptr_elem_type.elemType();
                //if (array_elem_type.eql(Type.initTag(.u8)) and
                //    ptr_elem_type.hasSentinel(Value.initTag(.zero)))
                //{
                //}
                const bytes = typed_value.val.toAllocatedBytes(allocator) catch |err| switch (err) {
                    error.AnalysisFail => unreachable,
                    else => |e| return e,
                };
                const str_inst = try self.arena.allocator.create(Inst.Str);
                str_inst.* = .{
                    .base = .{
                        .src = src,
                        .tag = Inst.Str.base_tag,
                    },
                    .positionals = .{
                        .bytes = bytes,
                    },
                    .kw_args = .{},
                };
                return self.emitUnnamedDecl(&str_inst.base);
            },
            .Void => return self.emitPrimitive(src, .void_value),
            else => |t| std.debug.panic("TODO implement emitTypedValue for {}", .{@tagName(t)}),
        }
    }

    fn emitNoOp(self: *EmitZIR, src: usize, tag: Inst.Tag) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.NoOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{},
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitUnOp(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.UnOp,
        tag: Inst.Tag,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.UnOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{
                .operand = try self.resolveInst(new_body, old_inst.operand),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitBinOp(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.BinOp,
        tag: Inst.Tag,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(Inst.BinOp);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = tag,
            },
            .positionals = .{
                .lhs = try self.resolveInst(new_body, old_inst.lhs),
                .rhs = try self.resolveInst(new_body, old_inst.rhs),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitCast(
        self: *EmitZIR,
        src: usize,
        new_body: ZirBody,
        old_inst: *ir.Inst.UnOp,
        comptime I: type,
    ) Allocator.Error!*Inst {
        const new_inst = try self.arena.allocator.create(I);
        new_inst.* = .{
            .base = .{
                .src = src,
                .tag = I.base_tag,
            },
            .positionals = .{
                .dest_type = (try self.emitType(src, old_inst.base.ty)).inst,
                .operand = try self.resolveInst(new_body, old_inst.operand),
            },
            .kw_args = .{},
        };
        return &new_inst.base;
    }

    fn emitBody(
        self: *EmitZIR,
        body: ir.Body,
        inst_table: *std.AutoHashMap(*ir.Inst, *Inst),
        instructions: *std.ArrayList(*Inst),
    ) Allocator.Error!void {
        const new_body = ZirBody{
            .inst_table = inst_table,
            .instructions = instructions,
        };
        for (body.instructions) |inst| {
            const new_inst = switch (inst.tag) {
                .constant => unreachable, // excluded from function bodies

                .arg => try self.emitNoOp(inst.src, .arg),
                .breakpoint => try self.emitNoOp(inst.src, .breakpoint),
                .unreach => try self.emitNoOp(inst.src, .@"unreachable"),
                .retvoid => try self.emitNoOp(inst.src, .returnvoid),

                .not => try self.emitUnOp(inst.src, new_body, inst.castTag(.not).?, .boolnot),
                .ret => try self.emitUnOp(inst.src, new_body, inst.castTag(.ret).?, .@"return"),
                .ptrtoint => try self.emitUnOp(inst.src, new_body, inst.castTag(.ptrtoint).?, .ptrtoint),
                .isnull => try self.emitUnOp(inst.src, new_body, inst.castTag(.isnull).?, .isnull),
                .isnonnull => try self.emitUnOp(inst.src, new_body, inst.castTag(.isnonnull).?, .isnonnull),

                .add => try self.emitBinOp(inst.src, new_body, inst.castTag(.add).?, .add),
                .sub => try self.emitBinOp(inst.src, new_body, inst.castTag(.sub).?, .sub),
                .cmp_lt => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_lt).?, .cmp_lt),
                .cmp_lte => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_lte).?, .cmp_lte),
                .cmp_eq => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_eq).?, .cmp_eq),
                .cmp_gte => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_gte).?, .cmp_gte),
                .cmp_gt => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_gt).?, .cmp_gt),
                .cmp_neq => try self.emitBinOp(inst.src, new_body, inst.castTag(.cmp_neq).?, .cmp_neq),

                .bitcast => try self.emitCast(inst.src, new_body, inst.castTag(.bitcast).?, Inst.BitCast),
                .intcast => try self.emitCast(inst.src, new_body, inst.castTag(.intcast).?, Inst.IntCast),
                .floatcast => try self.emitCast(inst.src, new_body, inst.castTag(.floatcast).?, Inst.FloatCast),

                .block => blk: {
                    const old_inst = inst.castTag(.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.Block);

                    try self.block_table.put(old_inst, new_inst);

                    var block_body = std.ArrayList(*Inst).init(self.allocator);
                    defer block_body.deinit();

                    try self.emitBody(old_inst.body, inst_table, &block_body);

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Block.base_tag,
                        },
                        .positionals = .{
                            .body = .{ .instructions = block_body.toOwnedSlice() },
                        },
                        .kw_args = .{},
                    };

                    break :blk &new_inst.base;
                },

                .brvoid => blk: {
                    const old_inst = inst.cast(ir.Inst.BrVoid).?;
                    const new_block = self.block_table.get(old_inst.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.BreakVoid);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.BreakVoid.base_tag,
                        },
                        .positionals = .{
                            .block = new_block,
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .br => blk: {
                    const old_inst = inst.castTag(.br).?;
                    const new_block = self.block_table.get(old_inst.block).?;
                    const new_inst = try self.arena.allocator.create(Inst.Break);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Break.base_tag,
                        },
                        .positionals = .{
                            .block = new_block,
                            .operand = try self.resolveInst(new_body, old_inst.operand),
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .call => blk: {
                    const old_inst = inst.castTag(.call).?;
                    const new_inst = try self.arena.allocator.create(Inst.Call);

                    const args = try self.arena.allocator.alloc(*Inst, old_inst.args.len);
                    for (args) |*elem, i| {
                        elem.* = try self.resolveInst(new_body, old_inst.args[i]);
                    }
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Call.base_tag,
                        },
                        .positionals = .{
                            .func = try self.resolveInst(new_body, old_inst.func),
                            .args = args,
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },

                .assembly => blk: {
                    const old_inst = inst.castTag(.assembly).?;
                    const new_inst = try self.arena.allocator.create(Inst.Asm);

                    const inputs = try self.arena.allocator.alloc(*Inst, old_inst.inputs.len);
                    for (inputs) |*elem, i| {
                        elem.* = (try self.emitStringLiteral(inst.src, old_inst.inputs[i])).inst;
                    }

                    const clobbers = try self.arena.allocator.alloc(*Inst, old_inst.clobbers.len);
                    for (clobbers) |*elem, i| {
                        elem.* = (try self.emitStringLiteral(inst.src, old_inst.clobbers[i])).inst;
                    }

                    const args = try self.arena.allocator.alloc(*Inst, old_inst.args.len);
                    for (args) |*elem, i| {
                        elem.* = try self.resolveInst(new_body, old_inst.args[i]);
                    }

                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.Asm.base_tag,
                        },
                        .positionals = .{
                            .asm_source = (try self.emitStringLiteral(inst.src, old_inst.asm_source)).inst,
                            .return_type = (try self.emitType(inst.src, inst.ty)).inst,
                        },
                        .kw_args = .{
                            .@"volatile" = old_inst.is_volatile,
                            .output = if (old_inst.output) |o|
                                (try self.emitStringLiteral(inst.src, o)).inst
                            else
                                null,
                            .inputs = inputs,
                            .clobbers = clobbers,
                            .args = args,
                        },
                    };
                    break :blk &new_inst.base;
                },

                .condbr => blk: {
                    const old_inst = inst.castTag(.condbr).?;

                    var then_body = std.ArrayList(*Inst).init(self.allocator);
                    var else_body = std.ArrayList(*Inst).init(self.allocator);

                    defer then_body.deinit();
                    defer else_body.deinit();

                    try self.emitBody(old_inst.then_body, inst_table, &then_body);
                    try self.emitBody(old_inst.else_body, inst_table, &else_body);

                    const new_inst = try self.arena.allocator.create(Inst.CondBr);
                    new_inst.* = .{
                        .base = .{
                            .src = inst.src,
                            .tag = Inst.CondBr.base_tag,
                        },
                        .positionals = .{
                            .condition = try self.resolveInst(new_body, old_inst.condition),
                            .then_body = .{ .instructions = then_body.toOwnedSlice() },
                            .else_body = .{ .instructions = else_body.toOwnedSlice() },
                        },
                        .kw_args = .{},
                    };
                    break :blk &new_inst.base;
                },
            };
            try instructions.append(new_inst);
            try inst_table.put(inst, new_inst);
        }
    }

    fn emitType(self: *EmitZIR, src: usize, ty: Type) Allocator.Error!*Decl {
        switch (ty.tag()) {
            .i8 => return self.emitPrimitive(src, .i8),
            .u8 => return self.emitPrimitive(src, .u8),
            .i16 => return self.emitPrimitive(src, .i16),
            .u16 => return self.emitPrimitive(src, .u16),
            .i32 => return self.emitPrimitive(src, .i32),
            .u32 => return self.emitPrimitive(src, .u32),
            .i64 => return self.emitPrimitive(src, .i64),
            .u64 => return self.emitPrimitive(src, .u64),
            .isize => return self.emitPrimitive(src, .isize),
            .usize => return self.emitPrimitive(src, .usize),
            .c_short => return self.emitPrimitive(src, .c_short),
            .c_ushort => return self.emitPrimitive(src, .c_ushort),
            .c_int => return self.emitPrimitive(src, .c_int),
            .c_uint => return self.emitPrimitive(src, .c_uint),
            .c_long => return self.emitPrimitive(src, .c_long),
            .c_ulong => return self.emitPrimitive(src, .c_ulong),
            .c_longlong => return self.emitPrimitive(src, .c_longlong),
            .c_ulonglong => return self.emitPrimitive(src, .c_ulonglong),
            .c_longdouble => return self.emitPrimitive(src, .c_longdouble),
            .c_void => return self.emitPrimitive(src, .c_void),
            .f16 => return self.emitPrimitive(src, .f16),
            .f32 => return self.emitPrimitive(src, .f32),
            .f64 => return self.emitPrimitive(src, .f64),
            .f128 => return self.emitPrimitive(src, .f128),
            .anyerror => return self.emitPrimitive(src, .anyerror),
            else => switch (ty.zigTypeTag()) {
                .Bool => return self.emitPrimitive(src, .bool),
                .Void => return self.emitPrimitive(src, .void),
                .NoReturn => return self.emitPrimitive(src, .noreturn),
                .Type => return self.emitPrimitive(src, .type),
                .ComptimeInt => return self.emitPrimitive(src, .comptime_int),
                .ComptimeFloat => return self.emitPrimitive(src, .comptime_float),
                .Fn => {
                    const param_types = try self.allocator.alloc(Type, ty.fnParamLen());
                    defer self.allocator.free(param_types);

                    ty.fnParamTypes(param_types);
                    const emitted_params = try self.arena.allocator.alloc(*Inst, param_types.len);
                    for (param_types) |param_type, i| {
                        emitted_params[i] = (try self.emitType(src, param_type)).inst;
                    }

                    const fntype_inst = try self.arena.allocator.create(Inst.FnType);
                    fntype_inst.* = .{
                        .base = .{
                            .src = src,
                            .tag = Inst.FnType.base_tag,
                        },
                        .positionals = .{
                            .param_types = emitted_params,
                            .return_type = (try self.emitType(src, ty.fnReturnType())).inst,
                        },
                        .kw_args = .{
                            .cc = ty.fnCallingConvention(),
                        },
                    };
                    return self.emitUnnamedDecl(&fntype_inst.base);
                },
                .Int => {
                    const info = ty.intInfo(self.old_module.target());
                    const signed = try self.emitPrimitive(src, if (info.signed) .@"true" else .@"false");
                    const bits_payload = try self.arena.allocator.create(Value.Payload.Int_u64);
                    bits_payload.* = .{ .int = info.bits };
                    const bits = try self.emitComptimeIntVal(src, Value.initPayload(&bits_payload.base));
                    const inttype_inst = try self.arena.allocator.create(Inst.IntType);
                    inttype_inst.* = .{
                        .base = .{
                            .src = src,
                            .tag = Inst.IntType.base_tag,
                        },
                        .positionals = .{
                            .signed = signed.inst,
                            .bits = bits.inst,
                        },
                        .kw_args = .{},
                    };
                    return self.emitUnnamedDecl(&inttype_inst.base);
                },
                else => std.debug.panic("TODO implement emitType for {}", .{ty}),
            },
        }
    }

    fn autoName(self: *EmitZIR) ![]u8 {
        while (true) {
            const proposed_name = try std.fmt.allocPrint(&self.arena.allocator, "unnamed${}", .{self.next_auto_name});
            self.next_auto_name += 1;
            const gop = try self.names.getOrPut(proposed_name);
            if (!gop.found_existing) {
                gop.entry.value = {};
                return proposed_name;
            }
        }
    }

    fn emitPrimitive(self: *EmitZIR, src: usize, tag: Inst.Primitive.Builtin) !*Decl {
        const gop = try self.primitive_table.getOrPut(tag);
        if (!gop.found_existing) {
            const primitive_inst = try self.arena.allocator.create(Inst.Primitive);
            primitive_inst.* = .{
                .base = .{
                    .src = src,
                    .tag = Inst.Primitive.base_tag,
                },
                .positionals = .{
                    .tag = tag,
                },
                .kw_args = .{},
            };
            gop.entry.value = try self.emitUnnamedDecl(&primitive_inst.base);
        }
        return gop.entry.value;
    }

    fn emitStringLiteral(self: *EmitZIR, src: usize, str: []const u8) !*Decl {
        const str_inst = try self.arena.allocator.create(Inst.Str);
        str_inst.* = .{
            .base = .{
                .src = src,
                .tag = Inst.Str.base_tag,
            },
            .positionals = .{
                .bytes = str,
            },
            .kw_args = .{},
        };
        return self.emitUnnamedDecl(&str_inst.base);
    }

    fn emitUnnamedDecl(self: *EmitZIR, inst: *Inst) !*Decl {
        const decl = try self.arena.allocator.create(Decl);
        decl.* = .{
            .name = try self.autoName(),
            .contents_hash = undefined,
            .inst = inst,
        };
        try self.decls.append(self.allocator, decl);
        return decl;
    }
};
