source: [*:0]const u8,
operands: std.StringHashMapUnmanaged(Operand),

pub const Operand = union(enum) {
    register: aarch64.encoding.Register,
};

pub fn nextInstruction(as: *Assemble) !?Instruction {
    @setEvalBranchQuota(37_000);
    comptime var ct_token_buf: [token_buf_len]u8 = undefined;
    var token_buf: [token_buf_len]u8 = undefined;
    const original_source = while (true) {
        const original_source = as.source;
        const source_token = try as.nextToken(&token_buf, .{});
        if (source_token.len == 0) return null;
        if (source_token[0] != '\n') break original_source;
    };
    log.debug(
        \\.
        \\=========================
        \\= Assembling "{f}"
        \\=========================
        \\
    , .{std.zig.fmtString(std.mem.span(original_source))});
    inline for (instructions) |instruction| {
        next_pattern: {
            as.source = original_source;
            var symbols: Symbols: {
                const symbols = @typeInfo(@TypeOf(instruction.symbols)).@"struct".fields;
                var symbol_fields: [symbols.len]std.builtin.Type.StructField = undefined;
                for (&symbol_fields, symbols) |*symbol_field, symbol| symbol_field.* = .{
                    .name = symbol.name,
                    .type = zonCast(SymbolSpec, @field(instruction.symbols, symbol.name), .{}).Storage(),
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = 0,
                };
                break :Symbols @Type(.{ .@"struct" = .{
                    .layout = .auto,
                    .fields = &symbol_fields,
                    .decls = &.{},
                    .is_tuple = false,
                } });
            } = undefined;
            comptime var pattern_as: Assemble = .{ .source = instruction.pattern, .operands = undefined };
            inline while (true) {
                const pattern_token = comptime pattern_as.nextToken(&ct_token_buf, .{ .placeholders = true }) catch |err|
                    @compileError(@errorName(err) ++ " while parsing '" ++ instruction.pattern ++ "'");
                const source_token = try as.nextToken(&token_buf, .{ .operands = true });
                log.debug("\"{f}\" -> \"{f}\"", .{
                    std.zig.fmtString(pattern_token),
                    std.zig.fmtString(source_token),
                });
                if (pattern_token.len == 0) {
                    if (source_token.len > 0 and source_token[0] != '\n') break :next_pattern;
                    const encode = @field(Instruction, @tagName(instruction.encode[0]));
                    const Encode = @TypeOf(encode);
                    var args: std.meta.ArgsTuple(Encode) = undefined;
                    inline for (&args, @typeInfo(Encode).@"fn".params, 1..instruction.encode.len) |*arg, param, encode_index|
                        arg.* = zonCast(param.type.?, instruction.encode[encode_index], symbols);
                    return @call(.auto, encode, args);
                } else if (pattern_token[0] == '<') {
                    const symbol_name = comptime pattern_token[1 .. std.mem.indexOfScalarPos(u8, pattern_token, 1, '|') orelse
                        pattern_token.len - 1];
                    const symbol = &@field(symbols, symbol_name);
                    symbol.* = zonCast(SymbolSpec, @field(instruction.symbols, symbol_name), .{}).parse(source_token) orelse break :next_pattern;
                    log.debug("{s} = {any}", .{ symbol_name, symbol.* });
                } else if (!std.ascii.eqlIgnoreCase(pattern_token, source_token)) break :next_pattern;
            }
        }
        log.debug("'{s}' not matched...", .{instruction.pattern});
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
                    .int => |symbol_int| {
                        var buf: [
                            std.fmt.count("{d}", .{switch (symbol_int.signedness) {
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
        } else return if (@hasDecl(Result, @tagName(zon_value))) @field(Result, @tagName(zon_value)) else zon_value,
        else => @compileError(std.fmt.comptimePrint("unsupported zon type: {} <- {any}", .{ Result, zon_value })),
    }
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
        '\n', '!', '#', ',', '[', ']' => {
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
        '-', '0'...'9', 'A'...'Z', '_', 'a'...'z' => {
            var index: usize = 1;
            while (switch (as.source[index]) {
                '0'...'9', 'A'...'Z', '_', 'a'...'z' => true,
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
    reg: struct { format: aarch64.encoding.Register.Format, allow_sp: bool = false },
    imm: struct {
        type: std.builtin.Type.Int,
        multiple_of: comptime_int = 1,
        max_valid: ?comptime_int = null,
    },
    extend: struct { size: aarch64.encoding.Register.IntegerSize },
    shift: struct { allow_ror: bool = true },
    barrier: struct { only_sy: bool = false },

    fn Storage(comptime spec: SymbolSpec) type {
        return switch (spec) {
            .reg => aarch64.encoding.Register,
            .imm => |imm| @Type(.{ .int = imm.type }),
            .extend => Instruction.DataProcessingRegister.AddSubtractExtendedRegister.Option,
            .shift => Instruction.DataProcessingRegister.Shift.Op,
            .barrier => Instruction.BranchExceptionGeneratingSystem.Barriers.Option,
        };
    }

    fn parse(comptime spec: SymbolSpec, token: []const u8) ?Storage(spec) {
        const Result = Storage(spec);
        switch (spec) {
            .reg => |reg_spec| {
                var buf: [token_buf_len]u8 = undefined;
                const reg = Result.parse(std.ascii.lowerString(&buf, token[0..@min(token.len, buf.len)])) orelse {
                    log.debug("invalid register: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (reg.format.integer != reg_spec.format.integer) {
                    log.debug("invalid register size: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                if (reg.alias == if (reg_spec.allow_sp) .zr else .sp) {
                    log.debug("invalid register usage: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return reg;
            },
            .imm => |imm_spec| {
                const imm = std.fmt.parseInt(Result, token, 0) catch {
                    log.debug("invalid immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (@rem(imm, imm_spec.multiple_of) != 0) {
                    log.debug("invalid immediate usage: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                if (imm_spec.max_valid) |max_valid| if (imm > max_valid) {
                    log.debug("out of range immediate: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                return imm;
            },
            .extend => |extend_spec| {
                const Option = Instruction.DataProcessingRegister.AddSubtractExtendedRegister.Option;
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Option).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const extend = std.meta.stringToEnum(Option, std.ascii.lowerString(
                    &buf,
                    token[0..@min(token.len, buf.len)],
                )) orelse {
                    log.debug("invalid extend: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                };
                if (extend.sf() != extend_spec.size) {
                    log.debug("invalid extend: \"{f}\"", .{std.zig.fmtString(token)});
                    return null;
                }
                return extend;
            },
            .shift => |shift_spec| {
                const ShiftOp = Instruction.DataProcessingRegister.Shift.Op;
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(ShiftOp).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const shift = std.meta.stringToEnum(ShiftOp, std.ascii.lowerString(
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
                const Option = Instruction.BranchExceptionGeneratingSystem.Barriers.Option;
                var buf: [
                    max_len: {
                        var max_len = 0;
                        for (@typeInfo(Option).@"enum".fields) |field| max_len = @max(max_len, field.name.len);
                        break :max_len max_len;
                    } + 1
                ]u8 = undefined;
                const barrier = std.meta.stringToEnum(Option, std.ascii.lowerString(
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
        \\ add w7, wsp, w8, uxtw #0
        \\ add wsp, wsp, w9, uxtw #2
        \\ add w10, w10, wzr, uxtw #3
        \\ add w11, w12, wzr, sxtb #4
        \\ add wsp, w13, wzr, sxth #0
        \\ add w14, wsp, wzr, sxtw #1
        \\ add wsp, wsp, wzr, sxtw #2
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
        \\ sub w7, wsp, w8, uxtw #0
        \\ sub wsp, wsp, w9, uxtw #2
        \\ sub w10, w10, wzr, uxtw #3
        \\ sub w11, w12, wzr, sxtb #4
        \\ sub wsp, w13, wzr, sxth #0
        \\ sub w14, wsp, wzr, sxtw #1
        \\ sub wsp, wsp, wzr, sxtw #2
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
        ,
        .operands = .empty,
    };

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
    try std.testing.expectFmt("add w2, w3, w4, uxtb #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, w9, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w10, w10, wzr, uxtw #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, w13, wzr, sxth #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add wsp, wsp, wzr, sxtw #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("add x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x2, x3, w4, uxtb #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("add sp, x13, wzr, sxth #0", "{f}", .{(try as.nextInstruction()).?});
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
    try std.testing.expectFmt("sub w2, w3, w4, uxtb #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w7, wsp, w8", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, w9, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w10, w10, wzr, uxtw #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w11, w12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, w13, wzr, sxth #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub w14, wsp, wzr, sxtw #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub wsp, wsp, wzr, sxtw #2", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sub x0, x0, x1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x2, x3, w4, uxtb #0", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x5, w6, uxth #1", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x7, sp, w8, uxtw #2", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, sp, x9", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x10, x10, xzr, uxtx #3", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub x11, x12, wzr, sxtb #4", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sub sp, x13, wzr, sxth #0", "{f}", .{(try as.nextInstruction()).?});
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

    try std.testing.expect(null == try as.nextInstruction());
}
test "bitfield" {
    var as: Assemble = .{
        .source =
        \\sbfm w0, w0, #0, #31
        \\sbfm w0, w0, #31, #0
        \\
        \\sbfm x0, x0, #0, #63
        \\sbfm x0, x0, #63, #0
        \\
        \\bfm w0, w0, #0, #31
        \\bfm w0, w0, #31, #0
        \\
        \\bfm x0, x0, #0, #63
        \\bfm x0, x0, #63, #0
        \\
        \\ubfm w0, w0, #0, #31
        \\ubfm w0, w0, #31, #0
        \\
        \\ubfm x0, x0, #0, #63
        \\ubfm x0, x0, #63, #0
        ,
        .operands = .empty,
    };

    try std.testing.expectFmt("sbfm w0, w0, #0, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbfm w0, w0, #31, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("sbfm x0, x0, #0, #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("sbfm x0, x0, #63, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("bfm w0, w0, #0, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfm w0, w0, #31, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("bfm x0, x0, #0, #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("bfm x0, x0, #63, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ubfm w0, w0, #0, #31", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ubfm w0, w0, #31, #0", "{f}", .{(try as.nextInstruction()).?});

    try std.testing.expectFmt("ubfm x0, x0, #0, #63", "{f}", .{(try as.nextInstruction()).?});
    try std.testing.expectFmt("ubfm x0, x0, #63, #0", "{f}", .{(try as.nextInstruction()).?});

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

const aarch64 = @import("../aarch64.zig");
const Assemble = @This();
const assert = std.debug.assert;
const Instruction = aarch64.encoding.Instruction;
const instructions = @import("instructions.zon");
const std = @import("std");
const log = std.log.scoped(.@"asm");
