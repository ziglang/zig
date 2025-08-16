source: [*:0]const u8,
operands: std.StringHashMapUnmanaged(Operand),

pub const Operand = union(enum) {
    register: aarch64.encoding.Register,
};

pub fn nextInstruction(as: *Assemble) !?Instruction {
    const original_source = while (true) {
        const original_source = as.source;
        var token_buf: [token_buf_len]u8 = undefined;
        const source_token = try as.nextToken(&token_buf, .{});
        switch (source_token.len) {
            0 => return null,
            else => switch (source_token[0]) {
                else => break original_source,
                '\n', ';' => {},
            },
        }
    };
    log.debug(
        \\.
        \\=========================
        \\= Assembling "{f}"
        \\=========================
        \\
    , .{std.zig.fmtString(std.mem.span(original_source))});
    for (matchers) |matcher| {
        as.source = original_source;
        if (try matcher(as)) |result| return result;
    }
    as.source = original_source;
    log.debug("Nothing matched!\n", .{});
    return error.InvalidSyntax;
}

fn zonCast(comptime Result: type, zon_value: anytype, symbols: anytype) Result {
    const ZonValue = @TypeOf(zon_value);
    const Symbols = @TypeOf(symbols);
    switch (@typeInfo(ZonValue)) {
        .void, .bool, .int, .float, .pointer, .comptime_float, .comptime_int, .@"enum" => return zon_value,
        .@"struct" => |zon_struct| switch (@typeInfo(Result)) {
            .pointer => |result_pointer| {
                comptime assert(result_pointer.size == .slice and result_pointer.is_const);
                var elems: [zon_value.len]result_pointer.child = undefined;
                inline for (&elems, zon_value) |*elem, zon_elem| elem.* = zonCast(result_pointer.child, zon_elem, symbols);
                return &elems;
            },
            .@"struct" => |result_struct| {
                comptime var used_zon_fields = 0;
                var result: Result = undefined;
                inline for (result_struct.fields) |result_field| @field(result, result_field.name) = if (@hasField(ZonValue, result_field.name)) result: {
                    used_zon_fields += 1;
                    break :result zonCast(@FieldType(Result, result_field.name), @field(zon_value, result_field.name), symbols);
                } else result_field.defaultValue() orelse @compileError(std.fmt.comptimePrint("missing zon field '{s}': {} <- {any}", .{ result_field.name, Result, zon_value }));
                if (used_zon_fields != zon_struct.fields.len) @compileError(std.fmt.comptimePrint("unused zon field: {} <- {any}", .{ Result, zon_value }));
                return result;
            },
            .@"union" => {
                if (zon_struct.fields.len != 1) @compileError(std.fmt.comptimePrint("{} <- {any}", .{ Result, zon_value }));
                const field_name = zon_struct.fields[0].name;
                return @unionInit(
                    Result,
                    field_name,
                    zonCast(@FieldType(Result, field_name), @field(zon_value, field_name), symbols),
                );
            },
            else => @compileError(std.fmt.comptimePrint("unsupported zon type: {} <- {any}", .{ Result, zon_value })),
        },
        .enum_literal => if (@hasField(Symbols, @tagName(zon_value))) {
            const symbol = @field(symbols, @tagName(zon_value));
            const Symbol = @TypeOf(symbol);
            switch (@typeInfo(Result)) {
                .@"enum" => switch (@typeInfo(Symbol)) {
                    .int => |info| {
                        var buf: [
                            std.fmt.count("{d}", .{switch (info.signedness) {
                                .signed => std.math.minInt(Symbol),
                                .unsigned => std.math.maxInt(Symbol),
                            }})
                        ]u8 = undefined;
                        return std.meta.stringToEnum(Result, std.fmt.bufPrint(&buf, "{d}", .{symbol}) catch unreachable).?;
                    },
                    else => return symbol,
                },
                else => return symbol,
            }
        } else {
            const Container = switch (@typeInfo(Result)) {
                else => struct {},
                .@"struct", .@"enum", .@"union", .@"opaque" => Result,
                .optional => |info| info.child,
                .error_union => |info| info.payload,
            };
            return if (@hasDecl(Container, @tagName(zon_value))) @field(Container, @tagName(zon_value)) else zon_value;
        },
        else => @compileError(std.fmt.comptimePrint("unsupported zon type: {} <- {any}", .{ Result, zon_value })),
    }
}

const matchers = matchers: {
    const instructions = @import("instructions.zon");
    var mut_matchers: [instructions.len]*const fn (as: *Assemble) error{InvalidSyntax}!?Instruction = undefined;
    for (instructions, &mut_matchers) |instruction, *matcher| matcher.* = struct {
        fn match(as: *Assemble) !?Instruction {
            comptime for (@typeInfo(@TypeOf(instruction)).@"struct".fields) |field| {
                if (std.mem.eql(u8, field.name, "requires")) continue;
                if (std.mem.eql(u8, field.name, "pattern")) continue;
                if (std.mem.eql(u8, field.name, "symbols")) continue;
                if (std.mem.eql(u8, field.name, "encode")) continue;
                @compileError("unexpected field '" ++ field.name ++ "'");
            };
            if (@hasField(@TypeOf(instruction), "requires")) _ = zonCast(
                []const std.Target.aarch64.Feature,
                instruction.requires,
                .{},
            );
            var symbols: Symbols: {
                const symbols = @typeInfo(@TypeOf(instruction.symbols)).@"struct".fields;
                var symbol_fields: [symbols.len]std.builtin.Type.StructField = undefined;
                for (&symbol_fields, symbols) |*symbol_field, symbol| {
                    const Storage = zonCast(SymbolSpec, @field(instruction.symbols, symbol.name), .{}).Storage();
                    symbol_field.* = .{
                        .name = symbol.name,
                        .type = Storage,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf(Storage),
                    };
                }
                break :Symbols @Type(.{ .@"struct" = .{
                    .layout = .auto,
                    .fields = &symbol_fields,
                    .decls = &.{},
                    .is_tuple = false,
                } });
            } = undefined;
            const Symbol = std.meta.FieldEnum(@TypeOf(instruction.symbols));
            comptime var unused_symbols: std.enums.EnumSet(Symbol) = .initFull();
            comptime var pattern_as: Assemble = .{ .source = instruction.pattern, .operands = undefined };
            inline while (true) {
                comptime var ct_token_buf: [token_buf_len]u8 = undefined;
                var token_buf: [token_buf_len]u8 = undefined;
                const pattern_token = comptime pattern_as.nextToken(&ct_token_buf, .{ .placeholders = true }) catch |err|
                    @compileError(@errorName(err) ++ " while parsing '" ++ instruction.pattern ++ "'");
                const source_token = try as.nextToken(&token_buf, .{ .operands = true });
                log.debug("\"{f}\" -> \"{f}\"", .{
                    std.zig.fmtString(pattern_token),
                    std.zig.fmtString(source_token),
                });
                if (pattern_token.len == 0) {
                    comptime var unused_symbol_it = unused_symbols.iterator();
                    inline while (comptime unused_symbol_it.next()) |unused_symbol|
                        @compileError(@tagName(unused_symbol) ++ " unused while parsing '" ++ instruction.pattern ++ "'");
                    switch (source_token.len) {
                        0 => {},
                        else => switch (source_token[0]) {
                            else => {
                                log.debug("'{s}' not matched...", .{instruction.pattern});
                                return null;
                            },
                            '\n', ';' => {},
                        },
                    }
                    const encode = @field(Instruction, @tagName(instruction.encode[0]));
                    const Encode = @TypeOf(encode);
                    var args: std.meta.ArgsTuple(Encode) = undefined;
                    inline for (&args, @typeInfo(Encode).@"fn".params, 1..instruction.encode.len) |*arg, param, encode_index|
                        arg.* = zonCast(param.type.?, instruction.encode[encode_index], symbols);
                    return @call(.auto, encode, args);
                } else if (pattern_token[0] == '<') {
                    const symbol_name = comptime pattern_token[1 .. std.mem.indexOfScalarPos(u8, pattern_token, 1, '|') orelse
                        pattern_token.len - 1];
                    const symbol = @field(Symbol, symbol_name);
                    const symbol_ptr = &@field(symbols, symbol_name);
                    const symbol_value = zonCast(SymbolSpec, @field(instruction.symbols, symbol_name), .{}).parse(source_token) orelse {
                        log.debug("'{s}' not matched...", .{instruction.pattern});
                        return null;
                    };
                    if (comptime unused_symbols.contains(symbol)) {
                        log.debug("{s} = {any}", .{ symbol_name, symbol_value });
                        symbol_ptr.* = symbol_value;
                        comptime unused_symbols.remove(symbol);
                    } else if (symbol_ptr.* != symbol_value) {
                        log.debug("'{s}' not matched...", .{instruction.pattern});
                        return null;
                    }
                } else if (!toUpperEqlAssertUpper(source_token, pattern_token)) {
                    log.debug("'{s}' not matched...", .{instruction.pattern});
                    return null;
                }
            }
        }
    }.match;
    break :matchers mut_matchers;
};

fn toUpperEqlAssertUpper(lhs: []const u8, rhs: []const u8) bool {
    if (lhs.len != rhs.len) return false;
    for (lhs, rhs) |l, r| {
        assert(!std.ascii.isLower(r));
        if (std.ascii.toUpper(l) != r) return false;
    }
    return true;
}

const token_buf_len = "v31.b[15]".len;
fn nextToken(as: *Assemble, buf: *[token_buf_len]u8, comptime opts: struct {
    operands: bool = false,
    placeholders: bool = false,
}) ![]const u8 {
    const invalid_syntax: u8 = 1;
    while (true) c: switch (as.source[0]) {
        0 => return as.source[0..0],
        '\t', '\n' + 1...'\r', ' ' => as.source = as.source[1..],
        '\n', '!', '#', ',', ';', '[', ']' => {
            defer as.source = as.source[1..];
            return as.source[0..1];
        },
        '%' => if (opts.operands) {
            if (as.source[1] != '[') continue :c invalid_syntax;
            const name_start: usize = 2;
            var index = name_start;
            while (switch (as.source[index]) {
                else => true,
                ':', ']' => false,
            }) index += 1;
            const operand = as.operands.get(as.source[name_start..index]) orelse continue :c invalid_syntax;
            const modifier = modifier: switch (as.source[index]) {
                else => unreachable,
                ':' => {
                    index += 1;
                    const modifier_start = index;
                    while (switch (as.source[index]) {
                        else => true,
                        ']' => false,
                    }) index += 1;
                    break :modifier as.source[modifier_start..index];
                },
                ']' => "",
            };
            assert(as.source[index] == ']');
            const modified_operand: Operand = if (std.mem.eql(u8, modifier, ""))
                operand
            else if (std.mem.eql(u8, modifier, "w")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.w() },
            } else if (std.mem.eql(u8, modifier, "x")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.x() },
            } else if (std.mem.eql(u8, modifier, "b")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.b() },
            } else if (std.mem.eql(u8, modifier, "h")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.h() },
            } else if (std.mem.eql(u8, modifier, "s")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.s() },
            } else if (std.mem.eql(u8, modifier, "d")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.d() },
            } else if (std.mem.eql(u8, modifier, "q")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.q() },
            } else if (std.mem.eql(u8, modifier, "Z")) switch (operand) {
                .register => |reg| .{ .register = reg.alias.z() },
            } else continue :c invalid_syntax;
            switch (modified_operand) {
                .register => |reg| {
                    as.source = as.source[index + 1 ..];
                    return std.fmt.bufPrint(buf, "{f}", .{reg.fmt()}) catch unreachable;
                },
            }
        } else continue :c invalid_syntax,
        '+', '-', '.', '0'...'9', 'A'...'Z', '_', 'a'...'z' => {
            var index: usize = 1;
            while (more: switch (as.source[index]) {
                '0'...'9' => true,
                'A'...'Z', '_', 'a'...'z' => switch (as.source[0]) {
                    else => true,
                    '.' => {
                        index = 1;
                        break :more false;
                    },
                },
                '.' => switch (as.source[0]) {
                    else => unreachable,
                    '+', '-', '.', '0'...'9' => true,
                    'A'...'Z', '_', 'a'...'z' => false,
                },
                else => false,
            }) index += 1;
            defer as.source = as.source[index..];
            return as.source[0..index];
        },
        '<' => if (opts.placeholders) {
            var index: usize = 1;
            while (switch (as.source[index]) {
                0 => return error.UnterminatedPlaceholder,
                '>' => false,
                else => true,
            }) index += 1;
            defer as.source = as.source[index + 1 ..];
            return as.source[0 .. index + 1];
        } else continue :c invalid_syntax,
        else => {
            if (!@inComptime()) log.debug("invalid token \"{f}\"", .{std.zig.fmtString(std.mem.span(as.source))});
            return error.InvalidSyntax;
        },
    };
}

const SymbolSpec = union(enum) {
    reg_alias: aarch64.encoding.Register.Format.Alias,
    reg: struct { format: aarch64.encoding.Register.Format, allow_sp: bool = false },
    arrangement: struct {
        elem_size: ?Instruction.DataProcessingVector.Size = null,
        allow_double: bool = true,
        min_valid_len: comptime_int = 0,
    },
    systemreg,
    imm: struct {
        type: std.builtin.Type.Int,
        multiple_of: ?comptime_int = null,
        min_valid: ?comptime_int = null,
        max_valid: ?comptime_int = null,
        adjust: enum { none, neg_wrap, dec } = .none,
    },
    fimm: struct { only_valid: ?f16 = null },
    extend: struct { size: ?aarch64.encoding.Register.GeneralSize = null },
    shift: struct { allow_ror: bool = true },
    barrier: struct { only_sy: bool = false },

    fn Storage(comptime spec: SymbolSpec) type {
        return switch (spec) {
            .reg_alias => aarch64.encoding.Register.Alias,
            .reg => aarch64.encoding.Register,
            .arrangement => aarch64.encoding.Register.Arrangement,
            .systemreg => aarch64.encoding.Register.System,
            .imm => |imm_spec| @Type(.{ .int = imm_spec.type }),
            .fimm => f16,
            .extend => Instruction.DataProcessingRegister.AddSubtractExtendedRegister.Option,
            .shift => Instruction.DataProcessingRegister.Shift.Op,
            .barrier => Instruction.BranchExceptionGeneratingSystem.Barriers.Option,
        };
    }

    fn parse(comptime spec: SymbolSpec, token: []const u8) ?Storage(spec) {
        const Result = Storage(spec);
        switch (spec) {
            .reg_alias => |reg_alias_spec| {
                const reg = aarch64.encoding.Register.parse(token) orelse {
                    log.debug("invalid register: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (reg.format != .alias or reg.format.alias != reg_alias_spec) {
                    log.debug("invalid register size: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return reg.alias;
            },
            .reg => |reg_spec| {
                const reg = Result.parse(token) orelse {
                    log.debug("invalid register: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (switch (reg_spec.format) {
                    .alias, .vector, .element, .scalable => comptime unreachable,
                    .general => |general_spec| reg.format != .general or reg.format.general != general_spec,
                    .scalar => |scalar_spec| reg.format != .scalar or reg.format.scalar != scalar_spec,
                }) {
                    log.debug("invalid register size: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                if (reg.alias == if (reg_spec.allow_sp) .zr else .sp) {
                    log.debug("invalid register usage: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return reg;
            },
            .arrangement => |arrangement_spec| {
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Result).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const arrangement = std.meta.stringToEnum(Result, std.ascii.lowerString(
                    &buf,
                    token[0..@min(token.len, buf.len)],
                )) orelse {
                    log.debug("invalid arrangement: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (arrangement_spec.elem_size) |elem_size| if (arrangement.elemSize() != elem_size) {
                    log.debug("invalid arrangement: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (!arrangement_spec.allow_double and arrangement.elemSize() == .double) {
                    log.debug("invalid arrangement: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                if (arrangement.len() < arrangement_spec.min_valid_len) {
                    log.debug("invalid arrangement: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return arrangement;
            },
            .systemreg => {
                const systemreg = Result.parse(token) orelse {
                    log.debug("invalid system register: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                assert(systemreg.op0 >= 2);
                return systemreg;
            },
            .imm => |imm_spec| {
                const imm = std.fmt.parseInt(@Type(.{ .int = .{
                    .signedness = imm_spec.type.signedness,
                    .bits = switch (imm_spec.adjust) {
                        .none, .neg_wrap => imm_spec.type.bits,
                        .dec => imm_spec.type.bits + 1,
                    },
                } }), token, 0) catch {
                    log.debug("invalid immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (imm_spec.multiple_of) |multiple_of| if (@rem(imm, multiple_of) != 0) {
                    log.debug("invalid immediate usage: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (imm_spec.min_valid) |min_valid| if (imm < min_valid) {
                    log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (imm_spec.max_valid) |max_valid| if (imm > max_valid) {
                    log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                return switch (imm_spec.adjust) {
                    .none => imm,
                    .neg_wrap => -%imm,
                    .dec => std.math.cast(Result, imm - 1) orelse {
                        log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                        return null;
                    },
                };
            },
            .fimm => |fimm_spec| {
                const full_fimm = std.fmt.parseFloat(f128, token) catch {
                    log.debug("invalid immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                const fimm: f16 = @floatCast(full_fimm);
                if (fimm != full_fimm) {
                    log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                if (fimm_spec.only_valid) |only_valid| {
                    if (@as(u16, @bitCast(fimm)) != @as(u16, @bitCast(only_valid))) {
                        log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                        return null;
                    }
                } else {
                    const Repr = std.math.FloatRepr(f16);
                    const repr: Repr = @bitCast(fimm);
                    if (repr.mantissa & std.math.maxInt(Repr.Mantissa) >> 5 != 0 or switch (repr.exponent) {
                        .denormal, .infinite => true,
                        else => std.math.cast(i3, repr.exponent.unbias() - 1) == null,
                    }) {
                        log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                        return null;
                    }
                }
                return fimm;
            },
            .extend => |extend_spec| {
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Result).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const extend = std.meta.stringToEnum(Result, std.ascii.lowerString(
                    &buf,
                    token[0..@min(token.len, buf.len)],
                )) orelse {
                    log.debug("invalid extend: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (extend_spec.size) |size| if (extend.sf() != size) {
                    log.debug("invalid extend: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                return extend;
            },
            .shift => |shift_spec| {
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Result).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const shift = std.meta.stringToEnum(Result, std.ascii.lowerString(
                    &buf,
                    token[0..@min(token.len, buf.len)],
                )) orelse {
                    log.debug("invalid shift: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (!shift_spec.allow_ror and shift == .ror) {
                    log.debug("invalid shift usage: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return shift;
            },
            .barrier => |barrier_spec| {
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Result).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const barrier = std.meta.stringToEnum(Result, std.ascii.lowerString(
                    &buf,
                    token[0..@min(token.len, buf.len)],
                )) orelse {
                    log.debug("invalid barrier: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (barrier_spec.only_sy and barrier != .sy) {
                    log.debug("invalid barrier: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return barrier;
            },
        }
    }
};

test "add sub" {
    var as: Assemble = .{
        .source =
        \\ adc w0, w0, w1
        \\ adc w2, w3, w4
        \\ adc w5, w5, wzr
        \\ adc w6, w7, wzr
        \\
        \\ adcs w0, w0, w1
        \\ adcs w2, w3, w4
        \\ adcs w5, w5, wzr
        \\ adcs w6, w7, wzr
        \\
        \\ add w0, w0, w1
        \\ add w2, w3, w4
        \\ add wsp, w5, w6
        \\ add w7, wsp, w8
        \\ add wsp, wsp, w9
        \\ add w10, w10, wzr
        \\ add w11, w12, wzr
        \\ add wsp, w13, wzr
        \\ add w14, wsp, wzr
        \\ add wsp, wsp, wzr
        \\
        \\ add x0, x0, x1
        \\ add x2, x3, x4
        \\ add sp, x5, x6
        \\ add x7, sp, x8
        \\ add sp, sp, x9
        \\ add x10, x10, xzr
        \\ add x11, x12, xzr
        \\ add sp, x13, xzr
        \\ add x14, sp, xzr
        \\ add sp, sp, xzr
        \\
        \\ add w0, w0, w1
        \\ add w2, w3, w4, uxtb #0
        \\ add wsp, w5, w6, uxth #1
        \\ add w7, wsp, w8, uxtw #2
        \\ add wsp, wsp, w9, uxtx #0
        \\ add w10, w10, wzr, uxtx #3
        \\ add w11, w12, wzr, sxtb #4
        \\ add wsp, w13, wzr, sxth #0
        \\ add w14, wsp, wzr, sxtw #1
        \\ add wsp, wsp, wzr, sxtx #2
        \\
        \\ add x0, x0, x1
        \\ add x2, x3, w4, uxtb #0
        \\ add sp, x5, w6, uxth #1
        \\ add x7, sp, w8, uxtw #2
        \\ add sp, sp, x9, uxtx #0
        \\ add x10, x10, xzr, uxtx #3
        \\ add x11, x12, wzr, sxtb #4
        \\ add sp, x13, wzr, sxth #0
        \\ add x14, sp, wzr, sxtw #1
        \\ add sp, sp, xzr, sxtx #2
        \\
        \\ add w0, w0, #0
        \\ add w0, w1, #1, lsl #0
        \\ add wsp, w2, #2, lsl #12
        \\ add w3, wsp, #3, lsl #0
        \\ add wsp, wsp, #4095, lsl #12
        \\ add w0, w1, #0
        \\ add w2, w3, #0, lsl #0
        \\ add w4, wsp, #0
        \\ add w5, wsp, #0, lsl #0
        \\ add wsp, w6, #0
        \\ add wsp, w7, #0, lsl #0
        \\ add wsp, wsp, #0
        \\ add wsp, wsp, #0, lsl #0
        \\
        \\ add x0, x0, #0
        \\ add x0, x1, #1, lsl #0
        \\ add sp, x2, #2, lsl #12
        \\ add x3, sp, #3, lsl #0
        \\ add sp, sp, #4095, lsl #12
        \\ add x0, x1, #0
        \\ add x2, x3, #0, lsl #0
        \\ add x4, sp, #0
        \\ add x5, sp, #0, lsl #0
        \\ add sp, x6, #0
        \\ add sp, x7, #0, lsl #0
        \\ add sp, sp, #0
        \\ add sp, sp, #0, lsl #0
        \\
        \\ add w0, w0, w0
        \\ add w1, w1, w2, lsl #0
        \\ add w3, w4, w5, lsl #1
        \\ add w6, w6, wzr, lsl #31
        \\ add w7, wzr, w8, lsr #0
        \\ add w9, wzr, wzr, lsr #30
        \\ add wzr, w10, w11, lsr #31
        \\ add wzr, w12, wzr, asr #0x0
        \\ add wzr, wzr, w13, asr #0x10
        \\ add wzr, wzr, wzr, asr #0x1f
        \\
        \\ add x0, x0, x0
        \\ add x1, x1, x2, lsl #0
        \\ add x3, x4, x5, lsl #1
        \\ add x6, x6, xzr, lsl #63
        \\ add x7, xzr, x8, lsr #0
        \\ add x9, xzr, xzr, lsr #62
        \\ add xzr, x10, x11, lsr #63
        \\ add xzr, x12, xzr, asr #0x0
        \\ add xzr, xzr, x13, asr #0x1F
        \\ add xzr, xzr, xzr, asr #0x3f
        \\
        \\ addg x0, sp, #0, #0xf
        \\ addg sp, x1, #0x3f0, #0
        \\
        \\ adds w0, w0, w1
        \\ adds w2, w3, w4
        \\ adds w5, w5, w6
        \\ adds w7, wsp, w8
        \\ adds w9, wsp, w9
        \\ adds w10, w10, wzr
        \\ adds w11, w12, wzr
        \\ adds wzr, w13, wzr
        \\ adds w14, wsp, wzr
        \\ adds wzr, wsp, wzr
        \\
        \\ adds x0, x0, x1
        \\ adds x2, x3, x4
        \\ adds x5, x5, x6
        \\ adds x7, sp, x8
        \\ adds x9, sp, x9
        \\ adds x10, x10, xzr
        \\ adds x11, x12, xzr
        \\ adds xzr, x13, xzr
        \\ adds x14, sp, xzr
        \\ adds xzr, sp, xzr
        \\
        \\ adds w0, w0, w1
        \\ adds w2, w3, w4, uxtb #0
        \\ adds wzr, w5, w6, uxth #1
        \\ adds w7, wsp, w8, uxtw #2
        \\ adds w9, wsp, w9, uxtx #0
        \\ adds w10, w10, wzr, uxtx #3
        \\ adds w11, w12, wzr, sxtb #4
        \\ adds wzr, w13, wzr, sxth #0
        \\ adds w14, wsp, wzr, sxtw #1
        \\ adds wzr, wsp, wzr, sxtx #2
        \\
        \\ adds x0, x0, x1
        \\ adds x2, x3, w4, uxtb #0
        \\ adds xzr, x5, w6, uxth #1
        \\ adds x7, sp, w8, uxtw #2
        \\ adds xzr, sp, x9, uxtx #0
        \\ adds x10, x10, xzr, uxtx #3
        \\ adds x11, x12, wzr, sxtb #4
        \\ adds xzr, x13, wzr, sxth #0
        \\ adds x14, sp, wzr, sxtw #1
        \\ adds xzr, sp, xzr, sxtx #2
        \\
        \\ adds w0, w0, #0
        \\ adds w0, w1, #1, lsl #0
        \\ adds wzr, w2, #2, lsl #12
        \\ adds w3, wsp, #3, lsl #0
        \\ adds wzr, wsp, #4095, lsl #12
        \\ adds w0, w1, #0
        \\ adds w2, w3, #0, lsl #0
        \\ adds w4, wsp, #0
        \\ adds w5, wsp, #0, lsl #0
        \\ adds wzr, w6, #0
        \\ adds wzr, w7, #0, lsl #0
        \\ adds wzr, wsp, #0
        \\ adds wzr, wsp, #0, lsl #0
        \\
        \\ adds x0, x0, #0
        \\ adds x0, x1, #1, lsl #0
        \\ adds xzr, x2, #2, lsl #12
        \\ adds x3, sp, #3, lsl #0
        \\ adds xzr, sp, #4095, lsl #12
        \\ adds x0, x1, #0
        \\ adds x2, x3, #0, lsl #0
        \\ adds x4, sp, #0
        \\ adds x5, sp, #0, lsl #0
        \\ adds xzr, x6, #0
        \\ adds xzr, x7, #0, lsl #0
        \\ adds xzr, sp, #0
        \\ adds xzr, sp, #0, lsl #0
        \\
        \\ adds w0, w0, w0
        \\ adds w1, w1, w2, lsl #0
        \\ adds w3, w4, w5, lsl #1
        \\ adds w6, w6, wzr, lsl #31
        \\ adds w7, wzr, w8, lsr #0
        \\ adds w9, wzr, wzr, lsr #30
        \\ adds wzr, w10, w11, lsr #31
        \\ adds wzr, w12, wzr, asr #0x0
        \\ adds wzr, wzr, w13, asr #0x10
        \\ adds wzr, wzr, wzr, asr #0x1f
        \\
        \\ adds x0, x0, x0
        \\ adds x1, x1, x2, lsl #0
        \\ adds x3, x4, x5, lsl #1
        \\ adds x6, x6, xzr, lsl #63
        \\ adds x7, xzr, x8, lsr #0
        \\ adds x9, xzr, xzr, lsr #62
        \\ adds xzr, x10, x11, lsr #63
        \\ adds xzr, x12, xzr, asr #0x0
        \\ adds xzr, xzr, x13, asr #0x1F
        \\ adds xzr, xzr, xzr, asr #0x3f
        \\
        \\ neg w0, w0
        \\ neg w1, w2, lsl #0
        \\ neg w3, wzr, lsl #7
        \\ neg wzr, w4, lsr #14
        \\ neg wzr, wzr, asr #21
        \\
        \\ neg x0, x0
        \\ neg x1, x2, lsl #0
        \\ neg x3, xzr, lsl #11
        \\ neg xzr, x4, lsr #22
        \\ neg xzr, xzr, asr #33
        \\
        \\ sbc w0, w0, w1
        \\ sbc w2, w3, w4
        \\ sbc w5, w5, wzr
        \\ sbc w6, w7, wzr
        \\
        \\ sbcs w0, w0, w1
        \\ sbcs w2, w3, w4
        \\ sbcs w5, w5, wzr
        \\ sbcs w6, w7, wzr
        \\
        \\ sub w0, w0, w1
        \\ sub w2, w3, w4
        \\ sub wsp, w5, w6
        \\ sub w7, wsp, w8
        \\ sub wsp, wsp, w9
        \\ sub w10, w10, wzr
        \\ sub w11, w12, wzr
        \\ sub wsp, w13, wzr
        \\ sub w14, wsp, wzr
        \\ sub wsp, wsp, wzr
        \\
        \\ sub x0, x0, x1
        \\ sub x2, x3, x4
        \\ sub sp, x5, x6
        \\ sub x7, sp, x8
        \\ sub sp, sp, x9
        \\ sub x10, x10, xzr
        \\ sub x11, x12, xzr
        \\ sub sp, x13, xzr
        \\ sub x14, sp, xzr
        \\ sub sp, sp, xzr
        \\
        \\ sub w0, w0, w1
        \\ sub w2, w3, w4, uxtb #0
        \\ sub wsp, w5, w6, uxth #1
        \\ sub w7, wsp, w8, uxtw #2
        \\ sub wsp, wsp, w9, uxtx #0
        \\ sub w10, w10, wzr, uxtx #3
        \\ sub w11, w12, wzr, sxtb #4
        \\ sub wsp, w13, wzr, sxth #0
        \\ sub w14, wsp, wzr, sxtw #1
        \\ sub wsp, wsp, wzr, sxtx #2
        \\
        \\ sub x0, x0, x1
        \\ sub x2, x3, w4, uxtb #0
        \\ sub sp, x5, w6, uxth #1
        \\ sub x7, sp, w8, uxtw #2
        \\ sub sp, sp, x9, uxtx #0
        \\ sub x10, x10, xzr, uxtx #3
        \\ sub x11, x12, wzr, sxtb #4
        \\ sub sp, x13, wzr, sxth #0
        \\ sub x14, sp, wzr, sxtw #1
        \\ sub sp, sp, xzr, sxtx #2
        \\
        \\ sub w0, w0, #0
        \\ sub w0, w1, #1, lsl #0
        \\ sub wsp, w2, #2, lsl #12
        \\ sub w3, wsp, #3, lsl #0
        \\ sub wsp, wsp, #4095, lsl #12
        \\ sub w0, w1, #0
        \\ sub w2, w3, #0, lsl #0
        \\ sub w4, wsp, #0
        \\ sub w5, wsp, #0, lsl #0
        \\ sub wsp, w6, #0
        \\ sub wsp, w7, #0, lsl #0
        \\ sub wsp, wsp, #0
        \\ sub wsp, wsp, #0, lsl #0
        \\
        \\ sub x0, x0, #0
        \\ sub x0, x1, #1, lsl #0
        \\ sub sp, x2, #2, lsl #12
        \\ sub x3, sp, #3, lsl #0
        \\ sub sp, sp, #4095, lsl #12
        \\ sub x0, x1, #0
        \\ sub x2, x3, #0, lsl #0
        \\ sub x4, sp, #0
        \\ sub x5, sp, #0, lsl #0
        \\ sub sp, x6, #0
        \\ sub sp, x7, #0, lsl #0
        \\ sub sp, sp, #0
        \\ sub sp, sp, #0, lsl #0
        \\
        \\ sub w0, w0, w0
        \\ sub w1, w1, w2, lsl #0
        \\ sub w3, w4, w5, lsl #1
        \\ sub w6, w6, wzr, lsl #31
        \\ sub w7, wzr, w8, lsr #0
        \\ sub w9, wzr, wzr, lsr #30
        \\ sub wzr, w10, w11, lsr #31
        \\ sub wzr, w12, wzr, asr #0x0
        \\ sub wzr, wzr, w13, asr #0x10
        \\ sub wzr, wzr, wzr, asr #0x1f
        \\
        \\ sub x0, x0, x0
        \\ sub x1, x1, x2, lsl #0
        \\ sub x3, x4, x5, lsl #1
        \\ sub x6, x6, xzr, lsl #63
        \\ sub x7, xzr, x8, lsr #0
        \\ sub x9, xzr, xzr, lsr #62
        \\ sub xzr, x10, x11, lsr #63
        \\ sub xzr, x12, xzr, asr #0x0
        \\ sub xzr, xzr, x13, asr #0x1F
        \\ sub xzr, xzr, xzr, asr #0x3f
        \\
        \\ subg x0, sp, #0, #0xf
        \\ subg sp, x1, #0x3f0, #0
        \\
        \\ subs w0, w0, w1
        \\ subs w2, w3, w4
        \\ subs w5, w5, w6
        \\ subs w7, wsp, w8
        \\ subs w9, wsp, w9
        \\ subs w10, w10, wzr
        \\ subs w11, w12, wzr
        \\ subs wzr, w13, wzr
        \\ subs w14, wsp, wzr
        \\ subs wzr, wsp, wzr
        \\
        \\ subs x0, x0, x1
        \\ subs x2, x3, x4
        \\ subs x5, x5, x6
        \\ subs x7, sp, x8
        \\ subs x9, sp, x9
        \\ subs x10, x10, xzr
        \\ subs x11, x12, xzr
        \\ subs xzr, x13, xzr
        \\ subs x14, sp, xzr
        \\ subs xzr, sp, xzr
        \\
        \\ subs w0, w0, w1
        \\ subs w2, w3, w4, uxtb #0
        \\ subs wzr, w5, w6, uxth #1
        \\ subs w7, wsp, w8, uxtw #2
        \\ subs w9, wsp, w9, uxtx #0
        \\ subs w10, w10, wzr, uxtx #3
        \\ subs w11, w12, wzr, sxtb #4
        \\ subs wzr, w13, wzr, sxth #0
        \\ subs w14, wsp, wzr, sxtw #1
        \\ subs wzr, wsp, wzr, sxtx #2
        \\
        \\ subs x0, x0, x1
        \\ subs x2, x3, w4, uxtb #0
        \\ subs xzr, x5, w6, uxth #1
        \\ subs x7, sp, w8, uxtw #2
        \\ subs xzr, sp, x9, uxtx #0
        \\ subs x10, x10, xzr, uxtx #3
        \\ subs x11, x12, wzr, sxtb #4
        \\ subs xzr, x13, wzr, sxth #0
        \\ subs x14, sp, wzr, sxtw #1
        \\ subs xzr, sp, xzr, sxtx #2
        \\
        \\ subs w0, w0, #0
        \\ subs w0, w1, #1, lsl #0
        \\ subs wzr, w2, #2, lsl #12
        \\ subs w3, wsp, #3, lsl #0
        \\ subs wzr, wsp, #4095, lsl #12
        \\ subs w0, w1, #0
        \\ subs w2, w3, #0, lsl #0
        \\ subs w4, wsp, #0
        \\ subs w5, wsp, #0, lsl #0
        \\ subs wzr, w6, #0
        \\ subs wzr, w7, #0, lsl #0
        \\ subs wzr, wsp, #0
        \\ subs wzr, wsp, #0, lsl #0
        \\
        \\ subs x0, x0, #0
        \\ subs x0, x1, #1, lsl #0
        \\ subs xzr, x2, #2, lsl #12
        \\ subs x3, sp, #3, lsl #0
        \\ subs xzr, sp, #4095, lsl #12
        \\ subs x0, x1, #0
        \\ subs x2, x3, #0, lsl #0
        \\ subs x4, sp, #0
        \\ subs x5, sp, #0, lsl #0
        \\ subs xzr, x6, #0
        \\ subs xzr, x7, #0, lsl #0
        \\ subs xzr, sp, #0
        \\ subs xzr, sp, #0, lsl #0
        \\
        \\ subs w0, w0, w0
        \\ subs w1, w1, w2, lsl #0
        \\ subs w3, w4, w5, lsl #1
        \\ subs w6, w6, wzr, lsl #31
        \\ subs w7, wzr, w8, lsr #0
        \\ subs w9, wzr, wzr, lsr #30
        \\ subs wzr, w10, w11, lsr #31
        \\ subs wzr, w12, wzr, asr #0x0
        \\ subs wzr, wzr, w13, asr #0x10
        \\ subs wzr, wzr, wzr, asr #0x1f
        \\
        \\ subs x0, x0, x0
        \\ subs x1, x1, x2, lsl #0
        \\ subs x3, x4, x5, lsl #1
        \\ subs x6, x6, xzr, lsl #63
        \\ subs x7, xzr, x8, lsr #0
        \\ subs x9, xzr, xzr, lsr #62
        \\ subs xzr, x10, x11, lsr #63
        \\ subs xzr, x12, xzr, asr #0x0
        \\ subs xzr, xzr, x13, asr #0x1F
        \\ subs xzr, xzr, xzr, asr #0x3f
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("adc w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adc w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adc w5, w5, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adc w6, w7, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adcs w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adcs w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adcs w5, w5, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adcs w6, w7, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w10, w10, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w11, w12, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w13, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w14, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x2, x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x5, x6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x7, sp, x8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x10, x10, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x11, x12, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x13, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x14, sp, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w2, w3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w7, wsp, w8, lsl #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, w9, uxtx", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w10, w10, wzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, wzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x2, x3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x14, sp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, xzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add w0, w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w0, w1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w3, wsp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w0, w1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w2, w3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w4, wsp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w5, wsp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, w7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, wsp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, wsp", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add x0, x0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x0, x1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x3, sp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x0, x1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x2, x3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x4, sp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x5, sp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, x6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, x7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, sp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, sp", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wzr, w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wzr, w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wzr, wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wzr, wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add xzr, x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add xzr, x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add xzr, xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add xzr, xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("addg x0, sp, #0x0, #0xf", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("addg sp, x1, #0x3f0, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w5, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w9, wsp, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w10, w10, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w11, w12, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn w13, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w14, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn wsp, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x2, x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x5, x5, x6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x7, sp, x8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x9, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x10, x10, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x11, x12, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn x13, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x14, sp, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn sp, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w2, w3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w7, wsp, w8, lsl #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w9, wsp, w9, uxtx", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w10, w10, wzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn w13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn wsp, wzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x2, x3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn x13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x14, sp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn sp, xzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds w0, w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w0, w1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, w2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w3, wsp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, wsp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w0, w1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w2, w3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w4, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w5, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, w6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, w7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds wzr, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds x0, x0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x0, x1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, x2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x3, sp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, sp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x0, x1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x2, x3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x4, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x5, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, x6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, x7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds xzr, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("adds x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("adds x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmn xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("neg w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg w3, wzr, lsl #7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg wzr, w4, lsr #14", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg wzr, wzr, asr #21", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("neg x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg x3, xzr, lsl #11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg xzr, x4, lsr #22", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg xzr, xzr, asr #33", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sbc w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbc w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbc w5, w5, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbc w6, w7, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sbcs w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbcs w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbcs w5, w5, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbcs w6, w7, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w10, w10, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w11, w12, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w13, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w14, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x2, x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x5, x6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x7, sp, x8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x10, x10, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x11, x12, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x13, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x14, sp, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w2, w3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w7, wsp, w8, lsl #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, w9, uxtx", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w10, w10, wzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, wzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x2, x3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x14, sp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, xzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub w0, w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w0, w1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w3, wsp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w0, w1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w2, w3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w4, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w5, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub x0, x0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x0, x1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x3, sp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x0, x1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x2, x3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x4, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x5, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg w7, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg w9, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wzr, w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wzr, w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg x7, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg x9, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub xzr, x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub xzr, x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subg x0, sp, #0x0, #0xf", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subg sp, x1, #0x3f0, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w2, w3, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w5, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w9, wsp, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w10, w10, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w11, w12, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp w13, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w14, wsp, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp wsp, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x2, x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x5, x5, x6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x7, sp, x8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x9, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x10, x10, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x11, x12, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp x13, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x14, sp, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp sp, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs w0, w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w2, w3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w7, wsp, w8, lsl #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w9, wsp, w9, uxtx", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w10, w10, wzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp w13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp wsp, wzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x2, x3, w4, uxtb", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp x13, wzr, sxth", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x14, sp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp sp, xzr, sxtx #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs w0, w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w0, w1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, w2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w3, wsp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, wsp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w0, w1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w2, w3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w4, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w5, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, w6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, w7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs wzr, wsp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs x0, x0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x0, x1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, x2, #0x2, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x3, sp, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, sp, #0xfff, lsl #12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x0, x1, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x2, x3, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x4, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x5, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, x6, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, x7, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs xzr, sp, #0x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("negs w7, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("negs w9, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("subs x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("subs x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("negs x7, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("negs x9, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmp xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "bit manipulation" {
    var as: Assemble = .{
        .source =
        \\rbit w0, w1
        \\rbit w2, wzr
        \\rbit x3, x4
        \\rbit xzr, x5
        \\
        \\rev16 w0, w1
        \\rev16 w2, wzr
        \\rev16 x3, x4
        \\rev16 xzr, x5
        \\
        \\rev32 x3, x4
        \\rev32 xzr, x5
        \\
        \\rev w0, w1
        \\rev w2, wzr
        \\rev x3, x4
        \\rev xzr, x5
        \\
        \\rev64 x3, x4
        \\rev64 xzr, x5
        \\
        \\clz w0, w1
        \\clz w2, wzr
        \\clz x3, x4
        \\clz xzr, x5
        \\
        \\cls w0, w1
        \\cls w2, wzr
        \\cls x3, x4
        \\cls xzr, x5
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("rbit w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rbit w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rbit x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rbit xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("rev16 w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev16 w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev16 x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev16 xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("rev32 x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev32 xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("rev w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("rev x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("rev xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("clz w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("clz w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("clz x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("clz xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cls w0, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cls w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cls x3, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cls xzr, x5", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "bitfield" {
    var as: Assemble = .{
        .source =
        \\bfc w0, #1, #31
        \\bfc w1, #31, #1
        \\bfc x2, #1, #63
        \\bfc x3, #63, #1
        \\
        \\bfi w0, w1, #1, #31
        \\bfi w2, wzr, #31, #1
        \\bfi x3, xzr, #1, #63
        \\bfi x4, x5, #63, #1
        \\
        \\bfm w0, wzr, #25, #5
        \\bfm w1, w2, #31, #1
        \\bfm w3, w4, #1, #31
        \\bfm x5, xzr, #57, #7
        \\bfm x6, x7, #63, #1
        \\bfm x8, x9, #1, #63
        \\
        \\sbfm w0, w1, #31, #1
        \\sbfm w2, w3, #1, #31
        \\sbfm x4, x5, #63, #1
        \\sbfm x6, x7, #1, #63
        \\
        \\ubfm w0, w1, #31, #1
        \\ubfm w2, w3, #1, #31
        \\ubfm x4, x5, #63, #1
        \\ubfm x6, x7, #1, #63
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("bfc w0, #1, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc w1, #31, #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc x2, #1, #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc x3, #63, #1", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("bfi w0, w1, #1, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc w2, #31, #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc x3, #1, #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfi x4, x5, #63, #1", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("bfc w0, #7, #6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfi w1, w2, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfxil w3, w4, #1, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfc x5, #7, #8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfi x6, x7, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfxil x8, x9, #1, #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sbfiz w0, w1, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbfx w2, w3, #1, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbfiz x4, x5, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbfx x6, x7, #1, #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ubfiz w0, w1, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ubfx w2, w3, #1, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ubfiz x4, x5, #1, #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ubfx x6, x7, #1, #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "branch register" {
    var as: Assemble = .{
        .source =
        \\ret
        \\br x30
        \\blr x30
        \\ret x30
        \\br x29
        \\blr x29
        \\ret x29
        \\br x2
        \\blr x1
        \\ret x0
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("ret", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("br x30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("blr x30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ret", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("br x29", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("blr x29", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ret x29", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("br x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("blr x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ret x0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "division" {
    var as: Assemble = .{
        .source =
        \\udiv w0, w1, w2
        \\udiv x3, x4, xzr
        \\sdiv w5, wzr, w6
        \\sdiv x7, x8, x9
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("udiv w0, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("udiv x3, x4, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sdiv w5, wzr, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sdiv x7, x8, x9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "exception generating" {
    var as: Assemble = .{
        .source =
        \\SVC #0
        \\HVC #0x1
        \\SMC #0o15
        \\BRK #42
        \\HLT #0x42
        \\TCANCEL #123
        \\DCPS1 #1234
        \\DCPS2 #12345
        \\DCPS3 #65535
        \\DCPS3 #0x0
        \\DCPS2 #0
        \\DCPS1
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("svc #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("hvc #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smc #0xd", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("brk #0x2a", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("hlt #0x42", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tcancel #0x7b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps1 #0x4d2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps2 #0x3039", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps3 #0xffff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dcps1", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "extract" {
    var as: Assemble = .{
        .source =
        \\extr W0, W1, W2, #0
        \\extr W3, W3, W4, #1
        \\extr W5, W5, W5, #31
        \\
        \\extr X0, X1, X2, #0
        \\extr X3, X3, X4, #1
        \\extr X5, X5, X5, #63
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("extr w0, w1, w2, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("extr w3, w3, w4, #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("extr w5, w5, w5, #31", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("extr x0, x1, x2, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("extr x3, x3, x4, #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("extr x5, x5, x5, #63", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "flags" {
    var as: Assemble = .{
        .source =
        \\AXFLAG
        \\CFINV
        \\XAFLAG
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("axflag", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cfinv", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("xaflag", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "hints" {
    var as: Assemble = .{
        .source =
        \\NOP
        \\hint #0
        \\YiElD
        \\Hint #0x1
        \\WfE
        \\hInt #02
        \\wFi
        \\hiNt #0b11
        \\sEv
        \\hinT #4
        \\sevl
        \\HINT #0b101
        \\hint #0x7F
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("nop", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("nop", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("yield", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("yield", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("wfe", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("wfe", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("wfi", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("wfi", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sev", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sev", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sevl", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sevl", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("hint #0x7f", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "load store" {
    var as: Assemble = .{
        .source =
        \\ LDP w0, w1, [x2], #-256
        \\ LDP w3, w4, [x5], #0
        \\ LDP w6, w7, [sp], #252
        \\ LDP w0, w1, [x2, #-0x100]!
        \\ LDP w3, w4, [x5, #0]!
        \\ LDP w6, w7, [sp, #0xfc]!
        \\ LDP w0, w1, [x2, #-256]
        \\ LDP w3, w4, [x5]
        \\ LDP w6, w7, [x8, #0]
        \\ LDP w9, w10, [sp, #252]
        \\
        \\ LDP x0, x1, [x2], #-512
        \\ LDP x3, x4, [x5], #0
        \\ LDP x6, x7, [sp], #504
        \\ LDP x0, x1, [x2, #-0x200]!
        \\ LDP x3, x4, [x5, #0]!
        \\ LDP x6, x7, [sp, #0x1f8]!
        \\ LDP x0, x1, [x2, #-512]
        \\ LDP x3, x4, [x5]
        \\ LDP x6, x7, [x8, #0]
        \\ LDP x9, x10, [sp, #504]
        \\
        \\ LDR w0, [x1], #-256
        \\ LDR w2, [x3], #0
        \\ LDR w4, [sp], #255
        \\ LDR w0, [x1, #-0x100]!
        \\ LDR w2, [x3, #0]!
        \\ LDR w4, [sp, #0xff]!
        \\ LDR w0, [x1, #0]
        \\ LDR w2, [x3]
        \\ LDR w4, [sp, #16380]
        \\
        \\ LDR x0, [x1], #-256
        \\ LDR x2, [x3], #0
        \\ LDR x4, [sp], #255
        \\ LDR x0, [x1, #-0x100]!
        \\ LDR x2, [x3, #0]!
        \\ LDR x4, [sp, #0xff]!
        \\ LDR x0, [x1, #0]
        \\ LDR x2, [x3]
        \\ LDR x4, [sp, #32760]
        \\
        \\ STP w0, w1, [x2], #-256
        \\ STP w3, w4, [x5], #0
        \\ STP w6, w7, [sp], #252
        \\ STP w0, w1, [x2, #-0x100]!
        \\ STP w3, w4, [x5, #0]!
        \\ STP w6, w7, [sp, #0xfc]!
        \\ STP w0, w1, [x2, #-256]
        \\ STP w3, w4, [x5]
        \\ STP w6, w7, [x8, #0]
        \\ STP w9, w10, [sp, #252]
        \\
        \\ STP x0, x1, [x2], #-512
        \\ STP x3, x4, [x5], #0
        \\ STP x6, x7, [sp], #504
        \\ STP x0, x1, [x2, #-0x200]!
        \\ STP x3, x4, [x5, #0]!
        \\ STP x6, x7, [sp, #0x1f8]!
        \\ STP x0, x1, [x2, #-512]
        \\ STP x3, x4, [x5]
        \\ STP x6, x7, [x8, #0]
        \\ STP x9, x10, [sp, #504]
        \\
        \\ STR w0, [x1], #-256
        \\ STR w2, [x3], #0
        \\ STR w4, [sp], #255
        \\ STR w0, [x1, #-0x100]!
        \\ STR w2, [x3, #0]!
        \\ STR w4, [sp, #0xff]!
        \\ STR w0, [x1, #0]
        \\ STR w2, [x3]
        \\ STR w4, [sp, #16380]
        \\
        \\ STR x0, [x1], #-256
        \\ STR x2, [x3], #0
        \\ STR x4, [sp], #255
        \\ STR x0, [x1, #-0x100]!
        \\ STR x2, [x3, #0]!
        \\ STR x4, [sp, #0xff]!
        \\ STR x0, [x1, #0]
        \\ STR x2, [x3]
        \\ STR x4, [sp, #32760]
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("ldp w0, w1, [x2], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w3, w4, [x5], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w6, w7, [sp], #0xfc", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w0, w1, [x2, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w3, w4, [x5, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w6, w7, [sp, #0xfc]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w0, w1, [x2, #-0x100]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w3, w4, [x5]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w6, w7, [x8]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp w9, w10, [sp, #0xfc]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ldp x0, x1, [x2], #-0x200", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x3, x4, [x5], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x6, x7, [sp], #0x1f8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x0, x1, [x2, #-0x200]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x3, x4, [x5, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x6, x7, [sp, #0x1f8]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x0, x1, [x2, #-0x200]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x3, x4, [x5]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x6, x7, [x8]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldp x9, x10, [sp, #0x1f8]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ldr w0, [x1], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w2, [x3], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w4, [sp], #0xff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w0, [x1, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w2, [x3, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w4, [sp, #0xff]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w0, [x1]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w2, [x3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr w4, [sp, #0x3ffc]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ldr x0, [x1], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x2, [x3], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x4, [sp], #0xff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x0, [x1, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x2, [x3, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x4, [sp, #0xff]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x0, [x1]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x2, [x3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ldr x4, [sp, #0x7ff8]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("stp w0, w1, [x2], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w3, w4, [x5], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w6, w7, [sp], #0xfc", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w0, w1, [x2, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w3, w4, [x5, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w6, w7, [sp, #0xfc]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w0, w1, [x2, #-0x100]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w3, w4, [x5]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w6, w7, [x8]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp w9, w10, [sp, #0xfc]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("stp x0, x1, [x2], #-0x200", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x3, x4, [x5], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x6, x7, [sp], #0x1f8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x0, x1, [x2, #-0x200]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x3, x4, [x5, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x6, x7, [sp, #0x1f8]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x0, x1, [x2, #-0x200]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x3, x4, [x5]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x6, x7, [x8]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("stp x9, x10, [sp, #0x1f8]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("str w0, [x1], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w2, [x3], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w4, [sp], #0xff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w0, [x1, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w2, [x3, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w4, [sp, #0xff]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w0, [x1]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w2, [x3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str w4, [sp, #0x3ffc]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("str x0, [x1], #-0x100", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x2, [x3], #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x4, [sp], #0xff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x0, [x1, #-0x100]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x2, [x3, #0x0]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x4, [sp, #0xff]!", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x0, [x1]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x2, [x3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("str x4, [sp, #0x7ff8]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "logical" {
    var as: Assemble = .{
        .source =
        \\ and w0, w0, w0
        \\ and w1, w1, w2, lsl #0
        \\ and w3, w4, w5, lsl #1
        \\ and w6, w6, wzr, lsl #31
        \\ and w7, wzr, w8, lsr #0
        \\ and w9, wzr, wzr, lsr #30
        \\ and wzr, w10, w11, lsr #31
        \\ and wzr, w12, wzr, asr #0x0
        \\ and wzr, wzr, w13, asr #0x10
        \\ and wzr, wzr, wzr, asr #0x1f
        \\ and w0, w0, wzr
        \\ and w1, w2, wzr, lsl #0
        \\ and w3, wzr, w3
        \\ and w4, wzr, w5, lsl #0
        \\ and w6, wzr, wzr
        \\ and w7, wzr, wzr, lsl #0
        \\ and wzr, w8, wzr
        \\ and wzr, w9, wzr, lsl #0
        \\ and wzr, wzr, w10
        \\ and wzr, wzr, w11, lsl #0
        \\ and wzr, wzr, wzr
        \\ and wzr, wzr, wzr, lsl #0
        \\
        \\ and x0, x0, x0
        \\ and x1, x1, x2, lsl #0
        \\ and x3, x4, x5, lsl #1
        \\ and x6, x6, xzr, lsl #63
        \\ and x7, xzr, x8, lsr #0
        \\ and x9, xzr, xzr, lsr #62
        \\ and xzr, x10, x11, lsr #63
        \\ and xzr, x12, xzr, asr #0x0
        \\ and xzr, xzr, x13, asr #0x1F
        \\ and xzr, xzr, xzr, asr #0x3f
        \\ and x0, x0, xzr
        \\ and x1, x2, xzr, lsl #0
        \\ and x3, xzr, x3
        \\ and x4, xzr, x5, lsl #0
        \\ and x6, xzr, xzr
        \\ and x7, xzr, xzr, lsl #0
        \\ and xzr, x8, xzr
        \\ and xzr, x9, xzr, lsl #0
        \\ and xzr, xzr, x10
        \\ and xzr, xzr, x11, lsl #0
        \\ and xzr, xzr, xzr
        \\ and xzr, xzr, xzr, lsl #0
        \\
        \\ orr w0, w0, w0
        \\ orr w1, w1, w2, lsl #0
        \\ orr w3, w4, w5, lsl #1
        \\ orr w6, w6, wzr, lsl #31
        \\ orr w7, wzr, w8, lsr #0
        \\ orr w9, wzr, wzr, lsr #30
        \\ orr wzr, w10, w11, lsr #31
        \\ orr wzr, w12, wzr, asr #0x0
        \\ orr wzr, wzr, w13, asr #0x10
        \\ orr wzr, wzr, wzr, asr #0x1f
        \\ orr w0, w0, wzr
        \\ orr w1, w2, wzr, lsl #0
        \\ orr w3, wzr, w3
        \\ orr w4, wzr, w5, lsl #0
        \\ orr w6, wzr, wzr
        \\ orr w7, wzr, wzr, lsl #0
        \\ orr wzr, w8, wzr
        \\ orr wzr, w9, wzr, lsl #0
        \\ orr wzr, wzr, w10
        \\ orr wzr, wzr, w11, lsl #0
        \\ orr wzr, wzr, wzr
        \\ orr wzr, wzr, wzr, lsl #0
        \\
        \\ orr x0, x0, x0
        \\ orr x1, x1, x2, lsl #0
        \\ orr x3, x4, x5, lsl #1
        \\ orr x6, x6, xzr, lsl #63
        \\ orr x7, xzr, x8, lsr #0
        \\ orr x9, xzr, xzr, lsr #62
        \\ orr xzr, x10, x11, lsr #63
        \\ orr xzr, x12, xzr, asr #0x0
        \\ orr xzr, xzr, x13, asr #0x1F
        \\ orr xzr, xzr, xzr, asr #0x3f
        \\ orr x0, x0, xzr
        \\ orr x1, x2, xzr, lsl #0
        \\ orr x3, xzr, x3
        \\ orr x4, xzr, x5, lsl #0
        \\ orr x6, xzr, xzr
        \\ orr x7, xzr, xzr, lsl #0
        \\ orr xzr, x8, xzr
        \\ orr xzr, x9, xzr, lsl #0
        \\ orr xzr, xzr, x10
        \\ orr xzr, xzr, x11, lsl #0
        \\ orr xzr, xzr, xzr
        \\ orr xzr, xzr, xzr, lsl #0
        \\
        \\ eor w0, w0, w0
        \\ eor w1, w1, w2, lsl #0
        \\ eor w3, w4, w5, lsl #1
        \\ eor w6, w6, wzr, lsl #31
        \\ eor w7, wzr, w8, lsr #0
        \\ eor w9, wzr, wzr, lsr #30
        \\ eor wzr, w10, w11, lsr #31
        \\ eor wzr, w12, wzr, asr #0x0
        \\ eor wzr, wzr, w13, asr #0x10
        \\ eor wzr, wzr, wzr, asr #0x1f
        \\ eor w0, w0, wzr
        \\ eor w1, w2, wzr, lsl #0
        \\ eor w3, wzr, w3
        \\ eor w4, wzr, w5, lsl #0
        \\ eor w6, wzr, wzr
        \\ eor w7, wzr, wzr, lsl #0
        \\ eor wzr, w8, wzr
        \\ eor wzr, w9, wzr, lsl #0
        \\ eor wzr, wzr, w10
        \\ eor wzr, wzr, w11, lsl #0
        \\ eor wzr, wzr, wzr
        \\ eor wzr, wzr, wzr, lsl #0
        \\
        \\ eor x0, x0, x0
        \\ eor x1, x1, x2, lsl #0
        \\ eor x3, x4, x5, lsl #1
        \\ eor x6, x6, xzr, lsl #63
        \\ eor x7, xzr, x8, lsr #0
        \\ eor x9, xzr, xzr, lsr #62
        \\ eor xzr, x10, x11, lsr #63
        \\ eor xzr, x12, xzr, asr #0x0
        \\ eor xzr, xzr, x13, asr #0x1F
        \\ eor xzr, xzr, xzr, asr #0x3f
        \\ eor x0, x0, xzr
        \\ eor x1, x2, xzr, lsl #0
        \\ eor x3, xzr, x3
        \\ eor x4, xzr, x5, lsl #0
        \\ eor x6, xzr, xzr
        \\ eor x7, xzr, xzr, lsl #0
        \\ eor xzr, x8, xzr
        \\ eor xzr, x9, xzr, lsl #0
        \\ eor xzr, xzr, x10
        \\ eor xzr, xzr, x11, lsl #0
        \\ eor xzr, xzr, xzr
        \\ eor xzr, xzr, xzr, lsl #0
        \\
        \\ ands w0, w0, w0
        \\ ands w1, w1, w2, lsl #0
        \\ ands w3, w4, w5, lsl #1
        \\ ands w6, w6, wzr, lsl #31
        \\ ands w7, wzr, w8, lsr #0
        \\ ands w9, wzr, wzr, lsr #30
        \\ ands wzr, w10, w11, lsr #31
        \\ ands wzr, w12, wzr, asr #0x0
        \\ ands wzr, wzr, w13, asr #0x10
        \\ ands wzr, wzr, wzr, asr #0x1f
        \\ ands w0, w0, wzr
        \\ ands w1, w2, wzr, lsl #0
        \\ ands w3, wzr, w3
        \\ ands w4, wzr, w5, lsl #0
        \\ ands w6, wzr, wzr
        \\ ands w7, wzr, wzr, lsl #0
        \\ ands wzr, w8, wzr
        \\ ands wzr, w9, wzr, lsl #0
        \\ ands wzr, wzr, w10
        \\ ands wzr, wzr, w11, lsl #0
        \\ ands wzr, wzr, wzr
        \\ ands wzr, wzr, wzr, lsl #0
        \\
        \\ ands x0, x0, x0
        \\ ands x1, x1, x2, lsl #0
        \\ ands x3, x4, x5, lsl #1
        \\ ands x6, x6, xzr, lsl #63
        \\ ands x7, xzr, x8, lsr #0
        \\ ands x9, xzr, xzr, lsr #62
        \\ ands xzr, x10, x11, lsr #63
        \\ ands xzr, x12, xzr, asr #0x0
        \\ ands xzr, xzr, x13, asr #0x1F
        \\ ands xzr, xzr, xzr, asr #0x3f
        \\ ands x0, x0, xzr
        \\ ands x1, x2, xzr, lsl #0
        \\ ands x3, xzr, x3
        \\ ands x4, xzr, x5, lsl #0
        \\ ands x6, xzr, xzr
        \\ ands x7, xzr, xzr, lsl #0
        \\ ands xzr, x8, xzr
        \\ ands xzr, x9, xzr, lsl #0
        \\ ands xzr, xzr, x10
        \\ ands xzr, xzr, x11, lsl #0
        \\ ands xzr, xzr, xzr
        \\ ands xzr, xzr, xzr, lsl #0
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("and w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w0, w0, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w1, w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w3, wzr, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w4, wzr, w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w6, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and w7, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, w8, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, w9, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, w10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, w11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and wzr, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("and x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x0, x0, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x1, x2, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x3, xzr, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x4, xzr, x5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x6, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and x7, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, x8, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, x9, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, x10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, x11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("and xzr, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("orr w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w0, w0, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr w1, w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w3, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w4, w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w6, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w7, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, w8, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr wzr, w9, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, w10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, w11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("orr x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x0, x0, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr x1, x2, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x3, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x4, x5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x6, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x7, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, x8, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("orr xzr, x9, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, x10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, x11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("eor w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w0, w0, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w1, w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w3, wzr, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w4, wzr, w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w6, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor w7, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, w8, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, w9, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, w10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, w11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor wzr, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("eor x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x0, x0, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x1, x2, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x3, xzr, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x4, xzr, x5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x6, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor x7, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, x8, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, x9, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, x10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, x11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("eor xzr, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ands w0, w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w1, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w3, w4, w5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w6, w6, wzr, lsl #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w7, wzr, w8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w9, wzr, wzr, lsr #30", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst w10, w11, lsr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst w12, wzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, w13, asr #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, wzr, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w0, w0, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w1, w2, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w3, wzr, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w4, wzr, w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w6, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands w7, wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst w8, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst w9, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, w10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, w11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst wzr, wzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ands x0, x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x1, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x3, x4, x5, lsl #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x6, x6, xzr, lsl #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x7, xzr, x8, lsr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x9, xzr, xzr, lsr #62", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst x10, x11, lsr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst x12, xzr, asr #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, x13, asr #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, xzr, asr #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x0, x0, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x1, x2, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x3, xzr, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x4, xzr, x5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x6, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ands x7, xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst x8, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst x9, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, x10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, x11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("tst xzr, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "mov" {
    var as: Assemble = .{
        .source =
        \\MOV W0, #0
        \\MOV WZR, #0xffff
        \\
        \\MOV X0, #0
        \\MOV XZR, #0xffff
        \\
        \\MOV W0, WSP
        \\MOV WSP, W1
        \\MOV WSP, WSP
        \\MOV X0, SP
        \\MOV SP, X1
        \\MOV SP, SP
        \\
        \\MOV W0, W0
        \\MOV W1, W2
        \\MOV W3, WZR
        \\MOV WZR, W4
        \\MOV WZR, WZR
        \\MOV X0, X0
        \\MOV X1, X2
        \\MOV X3, XZR
        \\MOV XZR, X4
        \\MOV XZR, XZR
        \\
        \\MOVK W0, #0
        \\MOVK W1, #1, lsl #0
        \\MOVK W2, #2, lsl #16
        \\MOVK X3, #3
        \\MOVK X4, #4, lsl #0x00
        \\MOVK X5, #5, lsl #0x10
        \\MOVK X6, #6, lsl #0x20
        \\MOVK X7, #7, lsl #0x30
        \\
        \\MOVN W0, #8
        \\MOVN W1, #9, lsl #0
        \\MOVN W2, #10, lsl #16
        \\MOVN X3, #11
        \\MOVN X4, #12, lsl #0x00
        \\MOVN X5, #13, lsl #0x10
        \\MOVN X6, #14, lsl #0x20
        \\MOVN X7, #15, lsl #0x30
        \\
        \\MOVN WZR, #0, lsl #0
        \\MOVN WZR, #0, lsl #16
        \\MOVN XZR, #0, lsl #0
        \\MOVN XZR, #0, lsl #16
        \\MOVN XZR, #0, lsl #32
        \\MOVN XZR, #0, lsl #48
        \\
        \\MOVN WZR, #0xffff, lsl #0
        \\MOVN WZR, #0xffff, lsl #16
        \\MOVN XZR, #0xffff, lsl #0
        \\MOVN XZR, #0xffff, lsl #16
        \\MOVN XZR, #0xffff, lsl #32
        \\MOVN XZR, #0xffff, lsl #48
        \\
        \\MOVZ W0, #16
        \\MOVZ W1, #17, lsl #0
        \\MOVZ W2, #18, lsl #16
        \\MOVZ X3, #19
        \\MOVZ X4, #20, lsl #0x00
        \\MOVZ X5, #21, lsl #0x10
        \\MOVZ X6, #22, lsl #0x20
        \\MOVZ X7, #23, lsl #0x30
        \\
        \\MOVZ WZR, #0, lsl #0
        \\MOVZ WZR, #0, lsl #16
        \\MOVZ XZR, #0, lsl #0
        \\MOVZ XZR, #0, lsl #16
        \\MOVZ XZR, #0, lsl #32
        \\MOVZ XZR, #0, lsl #48
        \\
        \\MOVZ WZR, #0xffff, lsl #0
        \\MOVZ WZR, #0xffff, lsl #16
        \\MOVZ XZR, #0xffff, lsl #0
        \\MOVZ XZR, #0xffff, lsl #16
        \\MOVZ XZR, #0xffff, lsl #32
        \\MOVZ XZR, #0xffff, lsl #48
        \\
        \\DUP B0, V1.B[15]
        \\DUP H2, V3.H[7]
        \\DUP S4, V5.S[3]
        \\DUP D6, V7.D[1]
        \\
        \\DUP V0.8B, V1.B[0]
        \\DUP V2.16B, V3.B[15]
        \\DUP V4.4H, V5.H[0]
        \\DUP V6.8H, V7.H[7]
        \\DUP V8.2S, V9.S[0]
        \\DUP V10.4S, V11.S[3]
        \\DUP V12.2D, V13.D[1]
        \\
        \\DUP V0.8B, W1
        \\DUP V2.16B, W3
        \\DUP V4.4H, W5
        \\DUP V6.8H, W7
        \\DUP V8.2S, W9
        \\DUP V10.4S, W11
        \\DUP V12.2D, X13
        \\
        \\FMOV V0.4H, #-31
        \\FMOV V1.8H, #-2.625
        \\FMOV V2.2S, #-1
        \\FMOV V3.4S, #-.2421875
        \\FMOV V4.2D, #.2421875
        \\FMOV H5, H6
        \\FMOV S7, S8
        \\FMOV D9, D10
        \\FMOV W11, H12
        \\FMOV X13, H14
        \\FMOV H15, W16
        \\FMOV S17, W18
        \\FMOV W19, S20
        \\FMOV H21, X22
        \\FMOV D23, X24
        \\FMOV V25.D[0x1], X26
        \\FMOV X27, D28
        \\FMOV X29, V30 . D [ 0X1 ]
        \\FMOV H31, #1
        \\FMOV S30, #2.625
        \\FMOV D29, #31
        \\
        \\INS V0.B[0], V1.B[15]
        \\INS V2.H[0], V3.H[7]
        \\INS V4.S[0], V5.S[3]
        \\INS V6.D[0], V7.D[1]
        \\
        \\INS V0.B[15], W1
        \\INS V2.H[7], W3
        \\INS V4.S[3], W5
        \\INS V6.D[1], X7
        \\
        \\MOV B0, V1.B [ 0xf]
        \\MOV H2, V3.H [ 0x7]
        \\MOV S4, V5.S [ 0x3]
        \\MOV D6, V7.D [ 0x1]
        \\
        \\MOV V0.B[0], V1.B[15]
        \\MOV V2.H[0], V3.H[7]
        \\MOV V4.S[0], V5.S[3]
        \\MOV V6.D[0], V7.D[1]
        \\
        \\MOV V0.B[15], W1
        \\MOV V2.H[7], W3
        \\MOV V4.S[3], W5
        \\MOV V6.D[1], X7
        \\
        \\MOV V0.8B, V1.8B
        \\MOV V2.16B, V3.16B
        \\
        \\MOV W0, V1.S[0x3]
        \\MOV X2, V3.D[0x1]
        \\
        \\SMOV W0, V1.B[0xF]
        \\SMOV W2, V3.H[0x7]
        \\SMOV X4, V5.B[0xF]
        \\SMOV X6, V7.H[0x7]
        \\SMOV X8, V9.S[0x3]
        \\
        \\UMOV W0, V1.B[0xF]
        \\UMOV W2, V3.H[0x7]
        \\UMOV W4, V5.S[0x3]
        \\UMOV X6, V7.D[0x1]
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("mov w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, #0xffff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0xffff", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov w0, wsp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wsp, wsp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x0, sp", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov sp, sp", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov w0, w0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w3, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, w4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x0, x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x3, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("movk w0, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk w1, #0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk w2, #0x2, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk x3, #0x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk x4, #0x4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk x5, #0x5, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk x6, #0x6, lsl #32", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movk x7, #0x7, lsl #48", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov w0, #-0x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w1, #-0xa", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w2, #-0xa0001", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x3, #-0xc", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x4, #-0xd", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x5, #-0xd0001", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x6, #-0xe00000001", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x7, #-0xf000000000001", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov wzr, #-0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movn wzr, #0x0, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #-0x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movn xzr, #0x0, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movn xzr, #0x0, lsl #32", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movn xzr, #0x0, lsl #48", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("movn wzr, #0xffff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movn wzr, #0xffff, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #-0x10000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #-0xffff0001", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #-0xffff00000001", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0xffffffffffff", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov w0, #0x10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w1, #0x11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w2, #0x120000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x3, #0x13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x4, #0x14", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x5, #0x150000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x6, #0x1600000000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x7, #0x17000000000000", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov wzr, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movz wzr, #0x0, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movz xzr, #0x0, lsl #16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movz xzr, #0x0, lsl #32", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("movz xzr, #0x0, lsl #48", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov wzr, #0xffff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov wzr, #-0x10000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0xffff", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0xffff0000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #0xffff00000000", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov xzr, #-0x1000000000000", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov b0, v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov h2, v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov s4, v5.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov d6, v7.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("dup v0.8b, v1.b[0]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v2.16b, v3.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v4.4h, v5.h[0]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v6.8h, v7.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v8.2s, v9.s[0]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v10.4s, v11.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v12.2d, v13.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("dup v0.8b, w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v2.16b, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v4.4h, w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v6.8h, w7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v8.2s, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v10.4s, w11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("dup v12.2d, x13", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fmov v0.4h, #-31.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov v1.8h, #-2.625", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov v2.2s, #-1.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov v3.4s, #-0.2421875", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov v4.2d, #0.2421875", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov h5, h6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov s7, s8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov d9, d10", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov w11, h12", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov x13, h14", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov h15, w16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov s17, w18", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov w19, s20", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov h21, x22", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov d23, x24", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov v25.d[1], x26", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov x27, d28", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov x29, v30.d[1]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov h31, #1.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov s30, #2.625", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fmov d29, #31.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov v0.b[0], v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v2.h[0], v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v4.s[0], v5.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v6.d[0], v7.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov v0.b[15], w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v2.h[7], w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v4.s[3], w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v6.d[1], x7", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov b0, v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov h2, v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov s4, v5.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov d6, v7.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov v0.b[0], v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v2.h[0], v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v4.s[0], v5.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v6.d[0], v7.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov v0.b[15], w1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v2.h[7], w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v4.s[3], w5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v6.d[1], x7", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov v0.8b, v1.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov v2.16b, v3.16b", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("mov w0, v1.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x2, v3.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("smov w0, v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smov w2, v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smov x4, v5.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smov x6, v7.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smov x8, v9.s[3]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("umov w0, v1.b[15]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umov w2, v3.h[7]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov w4, v5.s[3]", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mov x6, v7.d[1]", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "multiply" {
    var as: Assemble = .{
        .source =
        \\madd w0, w1, w2, w3
        \\madd w4, w5, w6, wzr
        \\mul w7, w8, w9
        \\madd x10, x11, x12, x13
        \\madd x14, x15, x16, xzr
        \\mul x17, x18, x19
        \\
        \\msub w0, w1, w2, w3
        \\msub w4, w5, w6, wzr
        \\mneg w7, w8, w9
        \\msub x10, x11, x12, x13
        \\msub x14, x15, x16, xzr
        \\mneg x17, x18, x19
        \\
        \\smaddl x0, w1, w2, x3
        \\smaddl x4, w5, w6, xzr
        \\smull x7, w8, w9
        \\
        \\smsubl x0, w1, w2, x3
        \\smsubl x4, w5, w6, xzr
        \\smnegl x7, w8, w9
        \\
        \\smulh x0, x1, x2
        \\smulh x3, x4, xzr
        \\
        \\umaddl x0, w1, w2, x3
        \\umaddl x4, w5, w6, xzr
        \\umull x7, w8, w9
        \\
        \\umsubl x0, w1, w2, x3
        \\umsubl x4, w5, w6, xzr
        \\umnegl x7, w8, w9
        \\
        \\umulh x0, x1, x2
        \\umulh x3, x4, xzr
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("madd w0, w1, w2, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mul w4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mul w7, w8, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("madd x10, x11, x12, x13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mul x14, x15, x16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mul x17, x18, x19", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("msub w0, w1, w2, w3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mneg w4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mneg w7, w8, w9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("msub x10, x11, x12, x13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mneg x14, x15, x16", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("mneg x17, x18, x19", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("smaddl x0, w1, w2, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smull x4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smull x7, w8, w9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("smsubl x0, w1, w2, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smnegl x4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smnegl x7, w8, w9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("smulh x0, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("smulh x3, x4, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("umaddl x0, w1, w2, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umull x4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umull x7, w8, w9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("umsubl x0, w1, w2, x3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umnegl x4, w5, w6", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umnegl x7, w8, w9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("umulh x0, x1, x2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("umulh x3, x4, xzr", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "reserved" {
    var as: Assemble = .{
        .source = "\n\nudf #0x0\n\t\n\tudf\t#01234\n    \nudf#65535",
        .operands = .empty,
    };

    try std.testing.expectFmt("udf #0x0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("udf #0x4d2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("udf #0xffff", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "shift" {
    var as: Assemble = .{
        .source =
        \\lsl w0, w1, w2
        \\lslv w3, w4, wzr
        \\lsl x5, x6, xzr
        \\lslv x7, x8, x9
        \\
        \\lsr w0, w1, w2
        \\lsrv w3, w4, wzr
        \\lsr x5, x6, xzr
        \\lsrv x7, x8, x9
        \\
        \\asr w0, w1, w2
        \\asrv w3, w4, wzr
        \\asr x5, x6, xzr
        \\asrv x7, x8, x9
        \\
        \\ror w0, w1, w2
        \\rorv w3, w4, wzr
        \\ror x5, x6, xzr
        \\rorv x7, x8, x9
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("lsl w0, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsl w3, w4, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsl x5, x6, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsl x7, x8, x9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("lsr w0, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsr w3, w4, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsr x5, x6, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("lsr x7, x8, x9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("asr w0, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("asr w3, w4, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("asr x5, x6, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("asr x7, x8, x9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ror w0, w1, w2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ror w3, w4, wzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ror x5, x6, xzr", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ror x7, x8, x9", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}
test "unary vector" {
    var as: Assemble = .{
        .source =
        \\SUQADD B0, B1
        \\SUQADD H2, H3
        \\SUQADD S4, S5
        \\SUQADD D6, D7
        \\SUQADD V8.8B, V9.8B
        \\SUQADD V10.16B, V11.16B
        \\SUQADD V12.4H, V13.4H
        \\SUQADD V14.8H, V15.8H
        \\SUQADD V16.2S, V17.2S
        \\SUQADD V18.4S, V19.4S
        \\SUQADD V20.2D, V21.2D
        \\
        \\CNT V0.8B, V1.8B
        \\CNT V2.16B, V3.16B
        \\
        \\SQABS B0, B1
        \\SQABS H2, H3
        \\SQABS S4, S5
        \\SQABS D6, D7
        \\SQABS V8.8B, V9.8B
        \\SQABS V10.16B, V11.16B
        \\SQABS V12.4H, V13.4H
        \\SQABS V14.8H, V15.8H
        \\SQABS V16.2S, V17.2S
        \\SQABS V18.4S, V19.4S
        \\SQABS V20.2D, V21.2D
        \\
        \\CMGT D0, D1, #00
        \\CMGT V2.8B, V3.8B, #0
        \\CMGT V4.16B, V5.16B, #0
        \\CMGT V6.4H, V7.4H, #0
        \\CMGT V8.8H, V9.8H, #0
        \\CMGT V10.2S, V11.2S, #0
        \\CMGT V12.4S, V13.4S, #0
        \\CMGT V14.2D, V15.2D, #0
        \\
        \\CMEQ D0, D1, #00
        \\CMEQ V2.8B, V3.8B, #0
        \\CMEQ V4.16B, V5.16B, #0
        \\CMEQ V6.4H, V7.4H, #0
        \\CMEQ V8.8H, V9.8H, #0
        \\CMEQ V10.2S, V11.2S, #0
        \\CMEQ V12.4S, V13.4S, #0
        \\CMEQ V14.2D, V15.2D, #0
        \\
        \\CMLT D0, D1, #00
        \\CMLT V2.8B, V3.8B, #0
        \\CMLT V4.16B, V5.16B, #0
        \\CMLT V6.4H, V7.4H, #0
        \\CMLT V8.8H, V9.8H, #0
        \\CMLT V10.2S, V11.2S, #0
        \\CMLT V12.4S, V13.4S, #0
        \\CMLT V14.2D, V15.2D, #0
        \\
        \\ABS D0, D1
        \\ABS V2.8B, V3.8B
        \\ABS V4.16B, V5.16B
        \\ABS V6.4H, V7.4H
        \\ABS V8.8H, V9.8H
        \\ABS V10.2S, V11.2S
        \\ABS V12.4S, V13.4S
        \\ABS V14.2D, V15.2D
        \\
        \\SQXTN B0, H1
        \\SQXTN H2, S3
        \\SQXTN S4, D5
        \\SQXTN V6.8B, V7.8H
        \\SQXTN2 V8.16B, V9.8H
        \\SQXTN V10.4H, V11.4S
        \\SQXTN2 V12.8H, V13.4S
        \\SQXTN V14.2S, V15.2D
        \\SQXTN2 V16.4S, V17.2D
        \\
        \\FRINTN V0.4H, V1.4H
        \\FRINTN V2.8H, V3.8H
        \\FRINTN V4.2S, V5.2S
        \\FRINTN V6.4S, V7.4S
        \\FRINTN V8.2D, V9.2D
        \\FRINTN H10, H11
        \\FRINTN S12, S13
        \\FRINTN D14, D15
        \\
        \\FRINTM V0.4H, V1.4H
        \\FRINTM V2.8H, V3.8H
        \\FRINTM V4.2S, V5.2S
        \\FRINTM V6.4S, V7.4S
        \\FRINTM V8.2D, V9.2D
        \\FRINTM H10, H11
        \\FRINTM S12, S13
        \\FRINTM D14, D15
        \\
        \\FCVTNS H0, H1
        \\FCVTNS S2, S3
        \\FCVTNS D4, D5
        \\FCVTNS V6.4H, V7.4H
        \\FCVTNS V8.8H, V9.8H
        \\FCVTNS V10.2S, V11.2S
        \\FCVTNS V12.4S, V13.4S
        \\FCVTNS V14.2D, V15.2D
        \\FCVTNS W16, H17
        \\FCVTNS X18, H19
        \\FCVTNS W20, S21
        \\FCVTNS X22, S23
        \\FCVTNS W24, D25
        \\FCVTNS X26, D27
        \\
        \\FCVTMS H0, H1
        \\FCVTMS S2, S3
        \\FCVTMS D4, D5
        \\FCVTMS V6.4H, V7.4H
        \\FCVTMS V8.8H, V9.8H
        \\FCVTMS V10.2S, V11.2S
        \\FCVTMS V12.4S, V13.4S
        \\FCVTMS V14.2D, V15.2D
        \\FCVTMS W16, H17
        \\FCVTMS X18, H19
        \\FCVTMS W20, S21
        \\FCVTMS X22, S23
        \\FCVTMS W24, D25
        \\FCVTMS X26, D27
        \\
        \\FCVTAS H0, H1
        \\FCVTAS S2, S3
        \\FCVTAS D4, D5
        \\FCVTAS V6.4H, V7.4H
        \\FCVTAS V8.8H, V9.8H
        \\FCVTAS V10.2S, V11.2S
        \\FCVTAS V12.4S, V13.4S
        \\FCVTAS V14.2D, V15.2D
        \\FCVTAS W16, H17
        \\FCVTAS X18, H19
        \\FCVTAS W20, S21
        \\FCVTAS X22, S23
        \\FCVTAS W24, D25
        \\FCVTAS X26, D27
        \\
        \\SCVTF H0, H1
        \\SCVTF S2, S3
        \\SCVTF D4, D5
        \\SCVTF V6.4H, V7.4H
        \\SCVTF V8.8H, V9.8H
        \\SCVTF V10.2S, V11.2S
        \\SCVTF V12.4S, V13.4S
        \\SCVTF V14.2D, V15.2D
        \\SCVTF H16, W17
        \\SCVTF H18, X19
        \\SCVTF S20, W21
        \\SCVTF S22, X23
        \\SCVTF D24, W25
        \\SCVTF D26, X27
        \\
        \\FCMGT H0, H1, #0.0
        \\FCMGT S2, S3, # 0.0
        \\FCMGT D4, D5, #+0.0
        \\FCMGT V6.4H, V7.4H, # +0.0
        \\FCMGT V8.8H, V9.8H, #0
        \\FCMGT V10.2S, V11.2S, # 0
        \\FCMGT V12.4S, V13.4S, #+0
        \\FCMGT V14.2D, V15.2D, # +0
        \\
        \\FCMEQ H0, H1, #0.0
        \\FCMEQ S2, S3, # 0.0
        \\FCMEQ D4, D5, #+0.0
        \\FCMEQ V6.4H, V7.4H, # +0.0
        \\FCMEQ V8.8H, V9.8H, #0
        \\FCMEQ V10.2S, V11.2S, # 0
        \\FCMEQ V12.4S, V13.4S, #+0
        \\FCMEQ V14.2D, V15.2D, # +0
        \\
        \\FCMLT H0, H1, #0.0
        \\FCMLT S2, S3, # 0.0
        \\FCMLT D4, D5, #+0.0
        \\FCMLT V6.4H, V7.4H, # +0.0
        \\FCMLT V8.8H, V9.8H, #0
        \\FCMLT V10.2S, V11.2S, # 0
        \\FCMLT V12.4S, V13.4S, #+0
        \\FCMLT V14.2D, V15.2D, # +0
        \\
        \\FRINTP V0.4H, V1.4H
        \\FRINTP V2.8H, V3.8H
        \\FRINTP V4.2S, V5.2S
        \\FRINTP V6.4S, V7.4S
        \\FRINTP V8.2D, V9.2D
        \\FRINTP H10, H11
        \\FRINTP S12, S13
        \\FRINTP D14, D15
        \\
        \\FRINTZ V0.4H, V1.4H
        \\FRINTZ V2.8H, V3.8H
        \\FRINTZ V4.2S, V5.2S
        \\FRINTZ V6.4S, V7.4S
        \\FRINTZ V8.2D, V9.2D
        \\FRINTZ H10, H11
        \\FRINTZ S12, S13
        \\FRINTZ D14, D15
        \\
        \\FCVTPS H0, H1
        \\FCVTPS S2, S3
        \\FCVTPS D4, D5
        \\FCVTPS V6.4H, V7.4H
        \\FCVTPS V8.8H, V9.8H
        \\FCVTPS V10.2S, V11.2S
        \\FCVTPS V12.4S, V13.4S
        \\FCVTPS V14.2D, V15.2D
        \\FCVTPS W16, H17
        \\FCVTPS X18, H19
        \\FCVTPS W20, S21
        \\FCVTPS X22, S23
        \\FCVTPS W24, D25
        \\FCVTPS X26, D27
        \\
        \\FCVTZS H0, H1
        \\FCVTZS S2, S3
        \\FCVTZS D4, D5
        \\FCVTZS V6.4H, V7.4H
        \\FCVTZS V8.8H, V9.8H
        \\FCVTZS V10.2S, V11.2S
        \\FCVTZS V12.4S, V13.4S
        \\FCVTZS V14.2D, V15.2D
        \\FCVTZS W16, H17
        \\FCVTZS X18, H19
        \\FCVTZS W20, S21
        \\FCVTZS X22, S23
        \\FCVTZS W24, D25
        \\FCVTZS X26, D27
        \\
        \\CMGE D0, D1, #00
        \\CMGE V2.8B, V3.8B, #0
        \\CMGE V4.16B, V5.16B, #0
        \\CMGE V6.4H, V7.4H, #0
        \\CMGE V8.8H, V9.8H, #0
        \\CMGE V10.2S, V11.2S, #0
        \\CMGE V12.4S, V13.4S, #0
        \\CMGE V14.2D, V15.2D, #0
        \\
        \\CMLE D0, D1, #00
        \\CMLE V2.8B, V3.8B, #0
        \\CMLE V4.16B, V5.16B, #0
        \\CMLE V6.4H, V7.4H, #0
        \\CMLE V8.8H, V9.8H, #0
        \\CMLE V10.2S, V11.2S, #0
        \\CMLE V12.4S, V13.4S, #0
        \\CMLE V14.2D, V15.2D, #0
        \\
        \\NEG D0, D1
        \\NEG V2.8B, V3.8B
        \\NEG V4.16B, V5.16B
        \\NEG V6.4H, V7.4H
        \\NEG V8.8H, V9.8H
        \\NEG V10.2S, V11.2S
        \\NEG V12.4S, V13.4S
        \\NEG V14.2D, V15.2D
        \\
        \\FCVTNU H0, H1
        \\FCVTNU S2, S3
        \\FCVTNU D4, D5
        \\FCVTNU V6.4H, V7.4H
        \\FCVTNU V8.8H, V9.8H
        \\FCVTNU V10.2S, V11.2S
        \\FCVTNU V12.4S, V13.4S
        \\FCVTNU V14.2D, V15.2D
        \\FCVTNU W16, H17
        \\FCVTNU X18, H19
        \\FCVTNU W20, S21
        \\FCVTNU X22, S23
        \\FCVTNU W24, D25
        \\FCVTNU X26, D27
        \\
        \\FCVTMU H0, H1
        \\FCVTMU S2, S3
        \\FCVTMU D4, D5
        \\FCVTMU V6.4H, V7.4H
        \\FCVTMU V8.8H, V9.8H
        \\FCVTMU V10.2S, V11.2S
        \\FCVTMU V12.4S, V13.4S
        \\FCVTMU V14.2D, V15.2D
        \\FCVTMU W16, H17
        \\FCVTMU X18, H19
        \\FCVTMU W20, S21
        \\FCVTMU X22, S23
        \\FCVTMU W24, D25
        \\FCVTMU X26, D27
        \\
        \\FCVTAU H0, H1
        \\FCVTAU S2, S3
        \\FCVTAU D4, D5
        \\FCVTAU V6.4H, V7.4H
        \\FCVTAU V8.8H, V9.8H
        \\FCVTAU V10.2S, V11.2S
        \\FCVTAU V12.4S, V13.4S
        \\FCVTAU V14.2D, V15.2D
        \\FCVTAU W16, H17
        \\FCVTAU X18, H19
        \\FCVTAU W20, S21
        \\FCVTAU X22, S23
        \\FCVTAU W24, D25
        \\FCVTAU X26, D27
        \\
        \\UCVTF H0, H1
        \\UCVTF S2, S3
        \\UCVTF D4, D5
        \\UCVTF V6.4H, V7.4H
        \\UCVTF V8.8H, V9.8H
        \\UCVTF V10.2S, V11.2S
        \\UCVTF V12.4S, V13.4S
        \\UCVTF V14.2D, V15.2D
        \\UCVTF H16, W17
        \\UCVTF H18, X19
        \\UCVTF S20, W21
        \\UCVTF S22, X23
        \\UCVTF D24, W25
        \\UCVTF D26, X27
        \\
        \\NOT V0.8B, V1.8B
        \\NOT V2.16B, V3.16B
        \\
        \\FCMGE H0, H1, #0.0
        \\FCMGE S2, S3, # 0.0
        \\FCMGE D4, D5, #+0.0
        \\FCMGE V6.4H, V7.4H, # +0.0
        \\FCMGE V8.8H, V9.8H, #0
        \\FCMGE V10.2S, V11.2S, # 0
        \\FCMGE V12.4S, V13.4S, #+0
        \\FCMGE V14.2D, V15.2D, # +0
        \\
        \\FCMLE H0, H1, #0.0
        \\FCMLE S2, S3, # 0.0
        \\FCMLE D4, D5, #+0.0
        \\FCMLE V6.4H, V7.4H, # +0.0
        \\FCMLE V8.8H, V9.8H, #0
        \\FCMLE V10.2S, V11.2S, # 0
        \\FCMLE V12.4S, V13.4S, #+0
        \\FCMLE V14.2D, V15.2D, # +0
        \\
        \\FRINTI V0.4H, V1.4H
        \\FRINTI V2.8H, V3.8H
        \\FRINTI V4.2S, V5.2S
        \\FRINTI V6.4S, V7.4S
        \\FRINTI V8.2D, V9.2D
        \\FRINTI H10, H11
        \\FRINTI S12, S13
        \\FRINTI D14, D15
        \\
        \\FCVTPU H0, H1
        \\FCVTPU S2, S3
        \\FCVTPU D4, D5
        \\FCVTPU V6.4H, V7.4H
        \\FCVTPU V8.8H, V9.8H
        \\FCVTPU V10.2S, V11.2S
        \\FCVTPU V12.4S, V13.4S
        \\FCVTPU V14.2D, V15.2D
        \\FCVTPU W16, H17
        \\FCVTPU X18, H19
        \\FCVTPU W20, S21
        \\FCVTPU X22, S23
        \\FCVTPU W24, D25
        \\FCVTPU X26, D27
        \\
        \\FCVTZU H0, H1
        \\FCVTZU S2, S3
        \\FCVTZU D4, D5
        \\FCVTZU V6.4H, V7.4H
        \\FCVTZU V8.8H, V9.8H
        \\FCVTZU V10.2S, V11.2S
        \\FCVTZU V12.4S, V13.4S
        \\FCVTZU V14.2D, V15.2D
        \\FCVTZU W16, H17
        \\FCVTZU X18, H19
        \\FCVTZU W20, S21
        \\FCVTZU X22, S23
        \\FCVTZU W24, D25
        \\FCVTZU X26, D27
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("suqadd b0, b1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd h2, h3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd s4, s5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd d6, d7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v8.8b, v9.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v10.16b, v11.16b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v12.4h, v13.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v14.8h, v15.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v16.2s, v17.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v18.4s, v19.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("suqadd v20.2d, v21.2d", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cnt v0.8b, v1.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cnt v2.16b, v3.16b", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sqabs b0, b1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs h2, h3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs s4, s5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs d6, d7", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v8.8b, v9.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v10.16b, v11.16b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v12.4h, v13.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v14.8h, v15.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v16.2s, v17.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v18.4s, v19.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqabs v20.2d, v21.2d", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cmgt d0, d1, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v2.8b, v3.8b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v4.16b, v5.16b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v6.4h, v7.4h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v8.8h, v9.8h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v10.2s, v11.2s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v12.4s, v13.4s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmgt v14.2d, v15.2d, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cmeq d0, d1, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v2.8b, v3.8b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v4.16b, v5.16b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v6.4h, v7.4h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v8.8h, v9.8h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v10.2s, v11.2s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v12.4s, v13.4s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmeq v14.2d, v15.2d, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cmlt d0, d1, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v2.8b, v3.8b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v4.16b, v5.16b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v6.4h, v7.4h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v8.8h, v9.8h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v10.2s, v11.2s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v12.4s, v13.4s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmlt v14.2d, v15.2d, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("abs d0, d1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v2.8b, v3.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v4.16b, v5.16b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("abs v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sqxtn b0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn h2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn s4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn v6.8b, v7.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn2 v8.16b, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn v10.4h, v11.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn2 v12.8h, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn v14.2s, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sqxtn2 v16.4s, v17.2d", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("frintn v0.4h, v1.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn v2.8h, v3.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn v4.2s, v5.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn v6.4s, v7.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn v8.2d, v9.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn h10, h11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn s12, s13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintn d14, d15", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("frintm v0.4h, v1.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm v2.8h, v3.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm v4.2s, v5.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm v6.4s, v7.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm v8.2d, v9.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm h10, h11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm s12, s13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintm d14, d15", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtns h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtns x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtms h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtms x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtas h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtas x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("scvtf h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf h16, w17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf h18, x19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf s20, w21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf s22, x23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf d24, w25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("scvtf d26, x27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcmgt h0, h1, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt s2, s3, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt d4, d5, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt v6.4h, v7.4h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt v8.8h, v9.8h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt v10.2s, v11.2s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt v12.4s, v13.4s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmgt v14.2d, v15.2d, #0.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcmeq h0, h1, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq s2, s3, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq d4, d5, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq v6.4h, v7.4h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq v8.8h, v9.8h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq v10.2s, v11.2s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq v12.4s, v13.4s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmeq v14.2d, v15.2d, #0.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcmlt h0, h1, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt s2, s3, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt d4, d5, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt v6.4h, v7.4h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt v8.8h, v9.8h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt v10.2s, v11.2s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt v12.4s, v13.4s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmlt v14.2d, v15.2d, #0.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("frintp v0.4h, v1.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp v2.8h, v3.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp v4.2s, v5.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp v6.4s, v7.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp v8.2d, v9.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp h10, h11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp s12, s13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintp d14, d15", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("frintz v0.4h, v1.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz v2.8h, v3.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz v4.2s, v5.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz v6.4s, v7.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz v8.2d, v9.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz h10, h11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz s12, s13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frintz d14, d15", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtps h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtps x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtzs h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzs x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cmge d0, d1, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v2.8b, v3.8b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v4.16b, v5.16b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v6.4h, v7.4h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v8.8h, v9.8h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v10.2s, v11.2s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v12.4s, v13.4s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmge v14.2d, v15.2d, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("cmle d0, d1, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v2.8b, v3.8b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v4.16b, v5.16b, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v6.4h, v7.4h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v8.8h, v9.8h, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v10.2s, v11.2s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v12.4s, v13.4s, #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("cmle v14.2d, v15.2d, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("neg d0, d1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v2.8b, v3.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v4.16b, v5.16b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("neg v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtnu h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtnu x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtmu h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtmu x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtau h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtau x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ucvtf h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf h16, w17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf h18, x19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf s20, w21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf s22, x23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf d24, w25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ucvtf d26, x27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("not v0.8b, v1.8b", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("not v2.16b, v3.16b", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcmge h0, h1, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge s2, s3, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge d4, d5, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge v6.4h, v7.4h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge v8.8h, v9.8h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge v10.2s, v11.2s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge v12.4s, v13.4s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmge v14.2d, v15.2d, #0.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcmle h0, h1, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle s2, s3, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle d4, d5, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle v6.4h, v7.4h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle v8.8h, v9.8h, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle v10.2s, v11.2s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle v12.4s, v13.4s, #0.0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcmle v14.2d, v15.2d, #0.0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("frinti v0.4h, v1.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti v2.8h, v3.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti v4.2s, v5.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti v6.4s, v7.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti v8.2d, v9.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti h10, h11", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti s12, s13", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("frinti d14, d15", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtpu h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtpu x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("fcvtzu h0, h1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu s2, s3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu d4, d5", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu v6.4h, v7.4h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu v8.8h, v9.8h", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu v10.2s, v11.2s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu v12.4s, v13.4s", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu v14.2d, v15.2d", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu w16, h17", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu x18, h19", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu w20, s21", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu x22, s23", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu w24, d25", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("fcvtzu x26, d27", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expect(null == try as.nextInstruction());
}

const aarch64 = @import("../aarch64.zig");
const Assemble = @This();
const assert = std.debug.assert;
const Instruction = aarch64.encoding.Instruction;
const std = @import("std");
const log = std.log.scoped(.@"asm");
