const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const assert = std.debug.assert;

pub const Inst = struct {
    tag: Tag,

    /// These names are used for the IR text format.
    pub const Tag = enum {
        constant,
        ptrtoint,
        fieldptr,
        deref,
        @"asm",
        @"unreachable",
        @"fn",
        @"export",
    };

    pub fn TagToType(tag: Tag) type {
        return switch (tag) {
            .constant => Constant,
            .ptrtoint => PtrToInt,
            .fieldptr => FieldPtr,
            .deref => Deref,
            .@"asm" => Assembly,
            .@"unreachable" => Unreachable,
            .@"fn" => Fn,
            .@"export" => Export,
        };
    }

    pub fn cast(base: *Inst, comptime T: type) ?*T {
        const expected_tag = std.meta.fieldInfo(T, "base").default_value.?.tag;
        if (base.tag != expected_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    /// This struct owns the `Value` memory. When the struct is deallocated,
    /// so is the `Value`. The value of a constant must be copied into
    /// a memory location for the value to survive after a const instruction.
    pub const Constant = struct {
        base: Inst = Inst{ .tag = .constant },
        ty: Type,

        positionals: struct {
            value: Value,
        },
        kw_args: struct {},
    };

    pub const PtrToInt = struct {
        base: Inst = Inst{ .tag = .ptrtoint },

        positionals: struct {
            ptr: *Inst,
        },
        kw_args: struct {},
    };

    pub const FieldPtr = struct {
        base: Inst = Inst{ .tag = .fieldptr },

        positionals: struct {
            object_ptr: *Inst,
            field_name: *Inst,
        },
        kw_args: struct {},
    };

    pub const Deref = struct {
        base: Inst = Inst{ .tag = .deref },

        positionals: struct {
            ptr: *Inst,
        },
        kw_args: struct {},
    };

    pub const Assembly = struct {
        base: Inst = Inst{ .tag = .@"asm" },

        positionals: struct {
            asm_source: *Inst,
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
        base: Inst = Inst{ .tag = .@"unreachable" },

        positionals: struct {},
        kw_args: struct {},
    };

    pub const Fn = struct {
        base: Inst = Inst{ .tag = .@"fn" },

        positionals: struct {
            body: Body,
        },
        kw_args: struct {
            cc: std.builtin.CallingConvention = .Unspecified,
        },

        pub const Body = struct {
            instructions: []*Inst,
        };
    };

    pub const Export = struct {
        base: Inst = Inst{ .tag = .@"export" },

        positionals: struct {
            symbol_name: *Inst,
            value: *Inst,
        },
        kw_args: struct {},
    };
};

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,
};

pub const Tree = struct {
    decls: []*Inst,
    errors: []ErrorMsg,

    pub fn deinit(self: *Tree) void {
        // TODO resource deallocation
        self.* = undefined;
    }

    /// This is a debugging utility for rendering the tree to stderr.
    pub fn dump(self: Tree) void {
        self.writeToStream(std.heap.page_allocator, std.io.getStdErr().outStream()) catch {};
    }

    const InstPtrTable = std.AutoHashMap(*Inst, struct { index: usize, fn_body: ?*Inst.Fn.Body });

    pub fn writeToStream(self: Tree, allocator: *Allocator, stream: var) !void {
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
        self: Tree,
        stream: var,
        decl: *Inst,
        inst_table: *const InstPtrTable,
    ) @TypeOf(stream).Error!void {
        // TODO I tried implementing this with an inline for loop and hit a compiler bug
        switch (decl.tag) {
            .constant => return self.writeInstToStreamGeneric(stream, .constant, decl, inst_table),
            .ptrtoint => return self.writeInstToStreamGeneric(stream, .ptrtoint, decl, inst_table),
            .fieldptr => return self.writeInstToStreamGeneric(stream, .fieldptr, decl, inst_table),
            .deref => return self.writeInstToStreamGeneric(stream, .deref, decl, inst_table),
            .@"asm" => return self.writeInstToStreamGeneric(stream, .@"asm", decl, inst_table),
            .@"unreachable" => return self.writeInstToStreamGeneric(stream, .@"unreachable", decl, inst_table),
            .@"fn" => return self.writeInstToStreamGeneric(stream, .@"fn", decl, inst_table),
            .@"export" => return self.writeInstToStreamGeneric(stream, .@"export", decl, inst_table),
        }
    }

    fn writeInstToStreamGeneric(
        self: Tree,
        stream: var,
        comptime inst_tag: Inst.Tag,
        base: *Inst,
        inst_table: *const InstPtrTable,
    ) !void {
        const SpecificInst = Inst.TagToType(inst_tag);
        const inst = @fieldParentPtr(SpecificInst, "base", base);
        if (@hasField(SpecificInst, "ty")) {
            try stream.print(": {} ", .{inst.ty});
        }
        if (inst_tag == .constant) {
            if (inst.positionals.value.cast(Value.Payload.Bytes)) |bytes_value| {
                try stream.writeAll("= ");
                return std.zig.renderStringLiteral(bytes_value.data, stream);
            } else if (inst.positionals.value.cast(Value.Payload.Int_u64)) |v| {
                return stream.print("= {}", .{v.int});
            } else if (inst.positionals.value.cast(Value.Payload.Int_i64)) |v| {
                return stream.print("= {}", .{v.int});
            }
        }
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
                try stream.writeAll(",\n    ");
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

    fn writeParamToStream(self: Tree, stream: var, param: var, inst_table: *const InstPtrTable) !void {
        if (@typeInfo(@TypeOf(param)) == .Enum) {
            return stream.writeAll(@tagName(param));
        }
        switch (@TypeOf(param)) {
            Value => {
                try stream.print("{}", .{param});
            },
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
            else => |T| @compileError("unimplemented: rendering parameter of type " ++ @typeName(T)),
        }
    }

    fn writeInstParamToStream(self: Tree, stream: var, inst: *Inst, inst_table: *const InstPtrTable) !void {
        const info = inst_table.getValue(inst).?;
        const prefix = if (info.fn_body == null) "@" else "%";
        try stream.print("{}{}", .{ prefix, info.index });
    }
};

const ParseContext = struct {
    allocator: *Allocator,
    i: usize,
    source: []const u8,
    errors: std.ArrayList(ErrorMsg),
    decls: std.ArrayList(*Inst),
    global_name_map: *std.StringHashMap(usize),
};

pub fn parse(allocator: *Allocator, source: []const u8) Allocator.Error!Tree {
    var global_name_map = std.StringHashMap(usize).init(allocator);
    defer global_name_map.deinit();

    var ctx: ParseContext = .{
        .allocator = allocator,
        .i = 0,
        .source = source,
        .decls = std.ArrayList(*Inst).init(allocator),
        .errors = std.ArrayList(ErrorMsg).init(allocator),
        .global_name_map = &global_name_map,
    };
    parseRoot(&ctx) catch |err| switch (err) {
        error.ParseFailure => {
            assert(ctx.errors.items.len != 0);
        },
        else => |e| return e,
    };
    return Tree{
        .decls = ctx.decls.toOwnedSlice(),
        .errors = ctx.errors.toOwnedSlice(),
    };
}

pub fn parseRoot(ctx: *ParseContext) !void {
    // The IR format is designed so that it can be tokenized and parsed at the same time.
    while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
        ';' => _ = try skipToAndOver(ctx, '\n'),
        '@' => {
            ctx.i += 1;
            const ident = try skipToAndOver(ctx, ' ');
            const opt_type = try parseOptionalType(ctx);
            const inst = try parseInstruction(ctx, opt_type, null);
            const ident_index = ctx.decls.items.len;
            if (try ctx.global_name_map.put(ident, ident_index)) |_| {
                return parseError(ctx, "redefinition of identifier '{}'", .{ident});
            }
            try ctx.decls.append(inst);
            continue;
        },
        ' ', '\n' => continue,
        else => |byte| return parseError(ctx, "unexpected byte: '{c}'", .{byte}),
    };
}

fn eatByte(ctx: *ParseContext, byte: u8) bool {
    if (ctx.i >= ctx.source.len) return false;
    if (ctx.source[ctx.i] != byte) return false;
    ctx.i += 1;
    return true;
}

fn skipSpace(ctx: *ParseContext) void {
    while (ctx.i < ctx.source.len and (ctx.source[ctx.i] == ' ' or ctx.source[ctx.i] == '\n')) {
        ctx.i += 1;
    }
}

fn requireEatBytes(ctx: *ParseContext, bytes: []const u8) !void {
    if (ctx.i + bytes.len > ctx.source.len)
        return parseError(ctx, "unexpected EOF", .{});
    if (!mem.eql(u8, ctx.source[ctx.i..][0..bytes.len], bytes))
        return parseError(ctx, "expected '{}'", .{bytes});
    ctx.i += bytes.len;
}

fn skipToAndOver(ctx: *ParseContext, byte: u8) ![]const u8 {
    const start_i = ctx.i;
    while (ctx.i < ctx.source.len) : (ctx.i += 1) {
        if (ctx.source[ctx.i] == byte) {
            const result = ctx.source[start_i..ctx.i];
            ctx.i += 1;
            return result;
        }
    }
    return parseError(ctx, "unexpected EOF", .{});
}

fn parseError(ctx: *ParseContext, comptime format: []const u8, args: var) error{ ParseFailure, OutOfMemory } {
    const msg = try std.fmt.allocPrint(ctx.allocator, format, args);
    (try ctx.errors.addOne()).* = .{
        .byte_offset = ctx.i,
        .msg = msg,
    };
    return error.ParseFailure;
}

/// Regardless of whether a `Type` is returned, it skips past the '='.
fn parseOptionalType(ctx: *ParseContext) !?Type {
    skipSpace(ctx);
    if (eatByte(ctx, ':')) {
        const type_text_untrimmed = try skipToAndOver(ctx, '=');
        skipSpace(ctx);
        const type_text = mem.trim(u8, type_text_untrimmed, " \n");
        if (mem.eql(u8, type_text, "usize")) {
            return Type.initTag(.int_usize);
        } else if (mem.eql(u8, type_text, "noreturn")) {
            return Type.initTag(.no_return);
        } else {
            return parseError(ctx, "TODO parse type '{}'", .{type_text});
        }
    } else {
        skipSpace(ctx);
        try requireEatBytes(ctx, "=");
        skipSpace(ctx);
        return null;
    }
}

fn parseInstruction(
    ctx: *ParseContext,
    opt_type: ?Type,
    body_ctx: ?*BodyContext,
) error{ OutOfMemory, ParseFailure }!*Inst {
    switch (ctx.source[ctx.i]) {
        '"' => return parseStringLiteralConst(ctx, opt_type),
        '0'...'9' => return parseIntegerLiteralConst(ctx, opt_type),
        else => {},
    }
    const fn_name = try skipToAndOver(ctx, '(');
    inline for (@typeInfo(Inst.Tag).Enum.fields) |field| {
        if (mem.eql(u8, field.name, fn_name)) {
            const tag = @field(Inst.Tag, field.name);
            return parseInstructionGeneric(ctx, field.name, Inst.TagToType(tag), opt_type, body_ctx);
        }
    }
    return parseError(ctx, "unknown instruction '{}'", .{fn_name});
}

fn parseInstructionGeneric(
    ctx: *ParseContext,
    comptime fn_name: []const u8,
    comptime InstType: type,
    opt_type: ?Type,
    body_ctx: ?*BodyContext,
) !*Inst {
    const inst_specific = try ctx.allocator.create(InstType);
    inst_specific.base = std.meta.fieldInfo(InstType, "base").default_value.?;

    if (@hasField(InstType, "ty")) {
        inst_specific.ty = opt_type orelse {
            return parseError(ctx, "instruction '" ++ fn_name ++ "' requires type", .{});
        };
    }

    const Positionals = @TypeOf(inst_specific.positionals);
    inline for (@typeInfo(Positionals).Struct.fields) |arg_field| {
        if (ctx.source[ctx.i] == ',') {
            ctx.i += 1;
            skipSpace(ctx);
        } else if (ctx.source[ctx.i] == ')') {
            return parseError(ctx, "expected positional parameter '{}'", .{arg_field.name});
        }
        @field(inst_specific.positionals, arg_field.name) = try parseParameterGeneric(
            ctx,
            arg_field.field_type,
            body_ctx,
        );
        skipSpace(ctx);
    }

    const KW_Args = @TypeOf(inst_specific.kw_args);
    inst_specific.kw_args = .{}; // assign defaults
    skipSpace(ctx);
    while (eatByte(ctx, ',')) {
        skipSpace(ctx);
        const name = try skipToAndOver(ctx, '=');
        inline for (@typeInfo(KW_Args).Struct.fields) |arg_field| {
            const field_name = arg_field.name;
            if (mem.eql(u8, name, field_name)) {
                const NonOptional = switch (@typeInfo(arg_field.field_type)) {
                    .Optional => |info| info.child,
                    else => arg_field.field_type,
                };
                @field(inst_specific.kw_args, field_name) = try parseParameterGeneric(ctx, NonOptional, body_ctx);
                break;
            }
        } else {
            return parseError(ctx, "unrecognized keyword parameter: '{}'", .{name});
        }
        skipSpace(ctx);
    }
    try requireEatBytes(ctx, ")");

    return &inst_specific.base;
}

fn parseParameterGeneric(ctx: *ParseContext, comptime T: type, body_ctx: ?*BodyContext) !T {
    if (@typeInfo(T) == .Enum) {
        const start = ctx.i;
        while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
            ' ', '\n', ',', ')' => {
                const enum_name = ctx.source[start..ctx.i];
                return std.meta.stringToEnum(T, enum_name) orelse {
                    return parseError(ctx, "tag '{}' not a member of enum '{}'", .{ enum_name, @typeName(T) });
                };
            },
            else => continue,
        };
        return parseError(ctx, "unexpected EOF in enum parameter", .{});
    }
    switch (T) {
        Inst.Fn.Body => return parseBody(ctx),
        bool => {
            const bool_value = switch (ctx.source[ctx.i]) {
                '0' => false,
                '1' => true,
                else => |byte| return parseError(ctx, "expected '0' or '1' for boolean value, found {c}", .{byte}),
            };
            ctx.i += 1;
            return bool_value;
        },
        []*Inst => {
            try requireEatBytes(ctx, "[");
            skipSpace(ctx);
            if (eatByte(ctx, ']')) return &[0]*Inst{};

            var instructions = std.ArrayList(*Inst).init(ctx.allocator);
            defer instructions.deinit();
            while (true) {
                skipSpace(ctx);
                try instructions.append(try parseParameterInst(ctx, body_ctx));
                skipSpace(ctx);
                if (!eatByte(ctx, ',')) break;
            }
            try requireEatBytes(ctx, "]");
            return instructions.toOwnedSlice();
        },
        *Inst => return parseParameterInst(ctx, body_ctx),
        Value => return parseError(ctx, "TODO implement parseParameterGeneric for type Value", .{}),
        else => @compileError("Unimplemented: ir parseParameterGeneric for type " ++ @typeName(T)),
    }
    return parseError(ctx, "TODO parse parameter {}", .{@typeName(T)});
}

fn parseParameterInst(ctx: *ParseContext, body_ctx: ?*BodyContext) !*Inst {
    const local_ref = switch (ctx.source[ctx.i]) {
        '@' => false,
        '%' => true,
        '"' => {
            const str_lit_inst = try parseStringLiteralConst(ctx, null);
            try ctx.decls.append(str_lit_inst);
            return str_lit_inst;
        },
        else => |byte| return parseError(ctx, "unexpected byte: '{c}'", .{byte}),
    };
    const map = if (local_ref)
        if (body_ctx) |bc|
            &bc.name_map
        else
            return parseError(ctx, "referencing a % instruction in global scope", .{})
    else
        ctx.global_name_map;

    ctx.i += 1;
    const name_start = ctx.i;
    while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
        ' ', '\n', ',', ')', ']' => break,
        else => continue,
    };
    const ident = ctx.source[name_start..ctx.i];
    const kv = map.get(ident) orelse {
        const bad_name = ctx.source[name_start - 1 .. ctx.i];
        ctx.i = name_start - 1;
        return parseError(ctx, "unrecognized identifier: {}", .{bad_name});
    };
    if (local_ref) {
        return body_ctx.?.instructions.items[kv.value];
    } else {
        return ctx.decls.items[kv.value];
    }
}

const BodyContext = struct {
    instructions: std.ArrayList(*Inst),
    name_map: std.StringHashMap(usize),
};

fn parseBody(ctx: *ParseContext) !Inst.Fn.Body {
    var body_context = BodyContext{
        .instructions = std.ArrayList(*Inst).init(ctx.allocator),
        .name_map = std.StringHashMap(usize).init(ctx.allocator),
    };
    defer body_context.instructions.deinit();
    defer body_context.name_map.deinit();

    try requireEatBytes(ctx, "{");
    skipSpace(ctx);

    while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
        ';' => _ = try skipToAndOver(ctx, '\n'),
        '%' => {
            ctx.i += 1;
            const ident = try skipToAndOver(ctx, ' ');
            const opt_type = try parseOptionalType(ctx);
            const inst = try parseInstruction(ctx, opt_type, &body_context);
            const ident_index = body_context.instructions.items.len;
            if (try body_context.name_map.put(ident, ident_index)) |_| {
                return parseError(ctx, "redefinition of identifier '{}'", .{ident});
            }
            try body_context.instructions.append(inst);
            continue;
        },
        ' ', '\n' => continue,
        '}' => {
            ctx.i += 1;
            break;
        },
        else => |byte| return parseError(ctx, "unexpected byte: '{c}'", .{byte}),
    };

    return Inst.Fn.Body{
        .instructions = body_context.instructions.toOwnedSlice(),
    };
}

fn parseStringLiteralConst(ctx: *ParseContext, opt_type: ?Type) !*Inst {
    const start = ctx.i;
    ctx.i += 1; // skip over '"'

    while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
        '"' => {
            ctx.i += 1;
            const span = ctx.source[start..ctx.i];
            var bad_index: usize = undefined;
            const parsed = std.zig.parseStringLiteral(ctx.allocator, span, &bad_index) catch |err| switch (err) {
                error.InvalidCharacter => {
                    ctx.i = start + bad_index;
                    const bad_byte = ctx.source[ctx.i];
                    return parseError(ctx, "invalid string literal character: '{c}'\n", .{bad_byte});
                },
                else => |e| return e,
            };
            const const_inst = try ctx.allocator.create(Inst.Constant);
            errdefer ctx.allocator.destroy(const_inst);

            const bytes_payload = try ctx.allocator.create(Value.Payload.Bytes);
            errdefer ctx.allocator.destroy(bytes_payload);
            bytes_payload.* = .{ .data = parsed };

            const ty = opt_type orelse blk: {
                const array_payload = try ctx.allocator.create(Type.Payload.Array_u8_Sentinel0);
                errdefer ctx.allocator.destroy(array_payload);
                array_payload.* = .{ .len = parsed.len };

                const ty_payload = try ctx.allocator.create(Type.Payload.SingleConstPointer);
                errdefer ctx.allocator.destroy(ty_payload);
                ty_payload.* = .{ .pointee_type = Type.initPayload(&array_payload.base) };

                break :blk Type.initPayload(&ty_payload.base);
            };

            const_inst.* = .{
                .ty = ty,
                .positionals = .{ .value = Value.initPayload(&bytes_payload.base) },
                .kw_args = .{},
            };
            return &const_inst.base;
        },
        '\\' => {
            ctx.i += 1;
            if (ctx.i >= ctx.source.len) break;
            continue;
        },
        else => continue,
    };
    return parseError(ctx, "unexpected EOF in string literal", .{});
}

fn parseIntegerLiteralConst(ctx: *ParseContext, opt_type: ?Type) !*Inst {
    const start = ctx.i;
    while (ctx.i < ctx.source.len) : (ctx.i += 1) switch (ctx.source[ctx.i]) {
        '0'...'9' => continue,
        else => break,
    };
    const number_text = ctx.source[start..ctx.i];
    const number = std.fmt.parseInt(u64, number_text, 10) catch |err| switch (err) {
        error.Overflow => return parseError(ctx, "TODO handle big integers", .{}),
        error.InvalidCharacter => return parseError(ctx, "invalid integer literal", .{}),
    };

    const int_payload = try ctx.allocator.create(Value.Payload.Int_u64);
    errdefer ctx.allocator.destroy(int_payload);
    int_payload.* = .{ .int = number };

    const const_inst = try ctx.allocator.create(Inst.Constant);
    errdefer ctx.allocator.destroy(const_inst);

    const_inst.* = .{
        .ty = opt_type orelse Type.initTag(.int_comptime),
        .positionals = .{ .value = Value.initPayload(&int_payload.base) },
        .kw_args = .{},
    };
    return &const_inst.base;
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    const src_path = args[1];
    const debug_error_trace = true;

    const source = try std.fs.cwd().readFileAlloc(allocator, src_path, std.math.maxInt(u32));

    var tree = try parse(allocator, source);
    defer tree.deinit();

    if (tree.errors.len != 0) {
        for (tree.errors) |err_msg| {
            const loc = findLineColumn(source, err_msg.byte_offset);
            std.debug.warn("{}:{}:{}: error: {}\n", .{ src_path, loc.line + 1, loc.column + 1, err_msg.msg });
        }
        if (debug_error_trace) return error.ParseFailure;
        std.process.exit(1);
    }

    tree.dump();

    //const new_tree = try semanticallyAnalyze(tree);
    //defer new_tree.deinit();
}

fn findLineColumn(source: []const u8, byte_offset: usize) struct { line: usize, column: usize } {
    var line: usize = 0;
    var column: usize = 0;
    for (source[0..byte_offset]) |byte| {
        switch (byte) {
            '\n' => {
                line += 1;
                column = 0;
            },
            else => {
                column += 1;
            },
        }
    }
    return .{ .line = line, .column = column };
}

// Performance optimization ideas:
// * make the source code sentinel-terminated, so that all the checks against the length can be skipped
