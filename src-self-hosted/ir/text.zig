//! This file has to do with parsing and rendering the ZIR text format.

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("../value.zig").Value;
const assert = std.debug.assert;
const ir = @import("../ir.zig");
const BigInt = std.math.big.Int;

/// These are instructions that correspond to the ZIR text format. See `ir.Inst` for
/// in-memory, analyzed instructions with types and values.
pub const Inst = struct {
    tag: Tag,
    /// Byte offset into the source.
    src: usize,

    /// These names are used directly as the instruction names in the text format.
    pub const Tag = enum {
        str,
        int,
        ptrtoint,
        fieldptr,
        deref,
        as,
        @"asm",
        @"unreachable",
        @"fn",
        @"export",
        primitive,
        fntype,
    };

    pub fn TagToType(tag: Tag) type {
        return switch (tag) {
            .str => Str,
            .int => Int,
            .ptrtoint => PtrToInt,
            .fieldptr => FieldPtr,
            .deref => Deref,
            .as => As,
            .@"asm" => Assembly,
            .@"unreachable" => Unreachable,
            .@"fn" => Fn,
            .@"export" => Export,
            .primitive => Primitive,
            .fntype => FnType,
        };
    }

    pub fn cast(base: *Inst, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    pub const Str = struct {
        pub const base_tag = Tag.str;
        base: Inst,

        positionals: struct {
            bytes: []u8,
        },
        kw_args: struct {},
    };

    pub const Int = struct {
        pub const base_tag = Tag.int;
        base: Inst,

        positionals: struct {
            int: BigInt,
        },
        kw_args: struct {},
    };

    pub const PtrToInt = struct {
        pub const base_tag = Tag.ptrtoint;
        base: Inst,

        positionals: struct {
            ptr: *Inst,
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

    pub const Deref = struct {
        pub const base_tag = Tag.deref;
        base: Inst,

        positionals: struct {
            ptr: *Inst,
        },
        kw_args: struct {},
    };

    pub const As = struct {
        pub const base_tag = Tag.as;
        base: Inst,

        positionals: struct {
            dest_type: *Inst,
            value: *Inst,
        },
        kw_args: struct {},
    };

    pub const Assembly = struct {
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

    pub const Unreachable = struct {
        pub const base_tag = Tag.@"unreachable";
        base: Inst,

        positionals: struct {},
        kw_args: struct {},
    };

    pub const Fn = struct {
        pub const base_tag = Tag.@"fn";
        base: Inst,

        positionals: struct {
            fn_type: *Inst,
            body: Body,
        },
        kw_args: struct {},

        pub const Body = struct {
            instructions: []*Inst,
        };
    };

    pub const Export = struct {
        pub const base_tag = Tag.@"export";
        base: Inst,

        positionals: struct {
            symbol_name: *Inst,
            value: *Inst,
        },
        kw_args: struct {},
    };

    pub const Primitive = struct {
        pub const base_tag = Tag.primitive;
        base: Inst,

        positionals: struct {
            tag: BuiltinType,
        },
        kw_args: struct {},

        pub const BuiltinType = enum {
            @"isize",
            @"usize",
            @"c_short",
            @"c_ushort",
            @"c_int",
            @"c_uint",
            @"c_long",
            @"c_ulong",
            @"c_longlong",
            @"c_ulonglong",
            @"c_longdouble",
            @"c_void",
            @"f16",
            @"f32",
            @"f64",
            @"f128",
            @"bool",
            @"void",
            @"noreturn",
            @"type",
            @"anyerror",
            @"comptime_int",
            @"comptime_float",
        };
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
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Module = struct {
    decls: []*Inst,
    errors: []ErrorMsg,
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *Module, allocator: *Allocator) void {
        allocator.free(self.decls);
        allocator.free(self.errors);
        self.arena.deinit();
        self.* = undefined;
    }

    /// This is a debugging utility for rendering the tree to stderr.
    pub fn dump(self: Module) void {
        self.writeToStream(std.heap.page_allocator, std.io.getStdErr().outStream()) catch {};
    }

    const InstPtrTable = std.AutoHashMap(*Inst, struct { index: usize, fn_body: ?*Inst.Fn.Body });

    /// The allocator is used for temporary storage, but this function always returns
    /// with no resources allocated.
    pub fn writeToStream(self: Module, allocator: *Allocator, stream: var) !void {
        // First, build a map of *Inst to @ or % indexes
        var inst_table = InstPtrTable.init(allocator);
        defer inst_table.deinit();

        try inst_table.ensureCapacity(self.decls.len);

        for (self.decls) |decl, decl_i| {
            try inst_table.putNoClobber(decl, .{ .index = decl_i, .fn_body = null });

            if (decl.cast(Inst.Fn)) |fn_inst| {
                for (fn_inst.positionals.body.instructions) |inst, inst_i| {
                    try inst_table.putNoClobber(inst, .{ .index = inst_i, .fn_body = &fn_inst.positionals.body });
                }
            }
        }

        for (self.decls) |decl, i| {
            try stream.print("@{} ", .{i});
            try self.writeInstToStream(stream, decl, &inst_table);
            try stream.writeByte('\n');
        }
    }

    fn writeInstToStream(
        self: Module,
        stream: var,
        decl: *Inst,
        inst_table: *const InstPtrTable,
    ) @TypeOf(stream).Error!void {
        // TODO I tried implementing this with an inline for loop and hit a compiler bug
        switch (decl.tag) {
            .str => return self.writeInstToStreamGeneric(stream, .str, decl, inst_table),
            .int => return self.writeInstToStreamGeneric(stream, .int, decl, inst_table),
            .ptrtoint => return self.writeInstToStreamGeneric(stream, .ptrtoint, decl, inst_table),
            .fieldptr => return self.writeInstToStreamGeneric(stream, .fieldptr, decl, inst_table),
            .deref => return self.writeInstToStreamGeneric(stream, .deref, decl, inst_table),
            .as => return self.writeInstToStreamGeneric(stream, .as, decl, inst_table),
            .@"asm" => return self.writeInstToStreamGeneric(stream, .@"asm", decl, inst_table),
            .@"unreachable" => return self.writeInstToStreamGeneric(stream, .@"unreachable", decl, inst_table),
            .@"fn" => return self.writeInstToStreamGeneric(stream, .@"fn", decl, inst_table),
            .@"export" => return self.writeInstToStreamGeneric(stream, .@"export", decl, inst_table),
            .primitive => return self.writeInstToStreamGeneric(stream, .primitive, decl, inst_table),
            .fntype => return self.writeInstToStreamGeneric(stream, .fntype, decl, inst_table),
        }
    }

    fn writeInstToStreamGeneric(
        self: Module,
        stream: var,
        comptime inst_tag: Inst.Tag,
        base: *Inst,
        inst_table: *const InstPtrTable,
    ) !void {
        const SpecificInst = Inst.TagToType(inst_tag);
        const inst = @fieldParentPtr(SpecificInst, "base", base);
        const Positionals = @TypeOf(inst.positionals);
        try stream.writeAll("= " ++ @tagName(inst_tag) ++ "(");
        const pos_fields = @typeInfo(Positionals).Struct.fields;
        inline for (pos_fields) |arg_field, i| {
            if (i != 0) {
                try stream.writeAll(", ");
            }
            try self.writeParamToStream(stream, @field(inst.positionals, arg_field.name), inst_table);
        }

        comptime var need_comma = pos_fields.len != 0;
        const KW_Args = @TypeOf(inst.kw_args);
        inline for (@typeInfo(KW_Args).Struct.fields) |arg_field, i| {
            if (need_comma) {
                try stream.writeAll(", ");
            }
            if (@typeInfo(arg_field.field_type) == .Optional) {
                if (@field(inst.kw_args, arg_field.name)) |non_optional| {
                    try stream.print("{}=", .{arg_field.name});
                    try self.writeParamToStream(stream, non_optional, inst_table);
                    need_comma = true;
                }
            } else {
                try stream.print("{}=", .{arg_field.name});
                try self.writeParamToStream(stream, @field(inst.kw_args, arg_field.name), inst_table);
                need_comma = true;
            }
        }

        try stream.writeByte(')');
    }

    fn writeParamToStream(self: Module, stream: var, param: var, inst_table: *const InstPtrTable) !void {
        if (@typeInfo(@TypeOf(param)) == .Enum) {
            return stream.writeAll(@tagName(param));
        }
        switch (@TypeOf(param)) {
            Value => return stream.print("{}", .{param}),
            *Inst => return self.writeInstParamToStream(stream, param, inst_table),
            []*Inst => {
                try stream.writeByte('[');
                for (param) |inst, i| {
                    if (i != 0) {
                        try stream.writeAll(", ");
                    }
                    try self.writeInstParamToStream(stream, inst, inst_table);
                }
                try stream.writeByte(']');
            },
            Inst.Fn.Body => {
                try stream.writeAll("{\n");
                for (param.instructions) |inst, i| {
                    try stream.print("  %{} ", .{i});
                    try self.writeInstToStream(stream, inst, inst_table);
                    try stream.writeByte('\n');
                }
                try stream.writeByte('}');
            },
            bool => return stream.writeByte("01"[@boolToInt(param)]),
            []u8 => return std.zig.renderStringLiteral(param, stream),
            BigInt => return stream.print("{}", .{param}),
            else => |T| @compileError("unimplemented: rendering parameter of type " ++ @typeName(T)),
        }
    }

    fn writeInstParamToStream(self: Module, stream: var, inst: *Inst, inst_table: *const InstPtrTable) !void {
        const info = inst_table.getValue(inst).?;
        const prefix = if (info.fn_body == null) "@" else "%";
        try stream.print("{}{}", .{ prefix, info.index });
    }
};

pub fn parse(allocator: *Allocator, source: [:0]const u8) Allocator.Error!Module {
    var global_name_map = std.StringHashMap(usize).init(allocator);
    defer global_name_map.deinit();

    var parser: Parser = .{
        .allocator = allocator,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .i = 0,
        .source = source,
        .decls = std.ArrayList(*Inst).init(allocator),
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .global_name_map = &global_name_map,
    };
    parser.parseRoot() catch |err| switch (err) {
        error.ParseFailure => {
            assert(parser.errors.items.len != 0);
        },
        else => |e| return e,
    };
    return Module{
        .decls = parser.decls.toOwnedSlice(),
        .errors = parser.errors.toOwnedSlice(),
        .arena = parser.arena,
    };
}

const Parser = struct {
    allocator: *Allocator,
    arena: std.heap.ArenaAllocator,
    i: usize,
    source: [:0]const u8,
    errors: std.ArrayList(ErrorMsg),
    decls: std.ArrayList(*Inst),
    global_name_map: *std.StringHashMap(usize),

    const Body = struct {
        instructions: std.ArrayList(*Inst),
        name_map: std.StringHashMap(usize),
    };

    fn parseBody(self: *Parser) !Inst.Fn.Body {
        var body_context = Body{
            .instructions = std.ArrayList(*Inst).init(self.allocator),
            .name_map = std.StringHashMap(usize).init(self.allocator),
        };
        defer body_context.instructions.deinit();
        defer body_context.name_map.deinit();

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
                const inst = try parseInstruction(self, &body_context);
                const ident_index = body_context.instructions.items.len;
                if (try body_context.name_map.put(ident, ident_index)) |_| {
                    return self.fail("redefinition of identifier '{}'", .{ident});
                }
                try body_context.instructions.append(inst);
                continue;
            },
            ' ', '\n' => continue,
            '}' => {
                self.i += 1;
                break;
            },
            else => |byte| return self.failByte(byte),
        };

        return Inst.Fn.Body{
            .instructions = body_context.instructions.toOwnedSlice(),
        };
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

    fn parseIntegerLiteral(self: *Parser) !BigInt {
        const start = self.i;
        if (self.source[self.i] == '-') self.i += 1;
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            '0'...'9' => continue,
            else => break,
        };
        const number_text = self.source[start..self.i];
        var result = try BigInt.init(&self.arena.allocator);
        result.setString(10, number_text) catch |err| {
            self.i = start;
            switch (err) {
                error.InvalidBase => unreachable,
                error.InvalidCharForDigit => return self.fail("invalid digit in integer literal", .{}),
                error.DigitTooLargeForBase => return self.fail("digit too large in integer literal", .{}),
                else => |e| return e,
            }
        };
        return result;
    }

    fn parseRoot(self: *Parser) !void {
        // The IR format is designed so that it can be tokenized and parsed at the same time.
        while (true) : (self.i += 1) switch (self.source[self.i]) {
            ';' => _ = try skipToAndOver(self, '\n'),
            '@' => {
                self.i += 1;
                const ident = try skipToAndOver(self, ' ');
                skipSpace(self);
                try requireEatBytes(self, "=");
                skipSpace(self);
                const inst = try parseInstruction(self, null);
                const ident_index = self.decls.items.len;
                if (try self.global_name_map.put(ident, ident_index)) |_| {
                    return self.fail("redefinition of identifier '{}'", .{ident});
                }
                try self.decls.append(inst);
                continue;
            },
            ' ', '\n' => continue,
            0 => break,
            else => |byte| return self.fail("unexpected byte: '{c}'", .{byte}),
        };
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

    fn fail(self: *Parser, comptime format: []const u8, args: var) InnerError {
        @setCold(true);
        const msg = try std.fmt.allocPrint(&self.arena.allocator, format, args);
        (try self.errors.addOne()).* = .{
            .byte_offset = self.i,
            .msg = msg,
        };
        return error.ParseFailure;
    }

    fn parseInstruction(self: *Parser, body_ctx: ?*Body) InnerError!*Inst {
        const fn_name = try skipToAndOver(self, '(');
        inline for (@typeInfo(Inst.Tag).Enum.fields) |field| {
            if (mem.eql(u8, field.name, fn_name)) {
                const tag = @field(Inst.Tag, field.name);
                return parseInstructionGeneric(self, field.name, Inst.TagToType(tag), body_ctx);
            }
        }
        return self.fail("unknown instruction '{}'", .{fn_name});
    }

    fn parseInstructionGeneric(
        self: *Parser,
        comptime fn_name: []const u8,
        comptime InstType: type,
        body_ctx: ?*Body,
    ) !*Inst {
        const inst_specific = try self.arena.allocator.create(InstType);
        inst_specific.base = .{
            .src = self.i,
            .tag = InstType.base_tag,
        };

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

        return &inst_specific.base;
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
            Inst.Fn.Body => return parseBody(self),
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
            Value => return self.fail("TODO implement parseParameterGeneric for type Value", .{}),
            []u8 => return self.parseStringLiteral(),
            BigInt => return self.parseIntegerLiteral(),
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
                &bc.name_map
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
        const kv = map.get(ident) orelse {
            const bad_name = self.source[name_start - 1 .. self.i];
            self.i = name_start - 1;
            return self.fail("unrecognized identifier: {}", .{bad_name});
        };
        if (local_ref) {
            return body_ctx.?.instructions.items[kv.value];
        } else {
            return self.decls.items[kv.value];
        }
    }
};
