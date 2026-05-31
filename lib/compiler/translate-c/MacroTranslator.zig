const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

const aro = @import("aro");
const CToken = aro.Tokenizer.Token;

const ast = @import("ast.zig");
const builtins = @import("builtins.zig");
const ZigNode = ast.Node;
const ZigTag = ZigNode.Tag;
const Scope = @import("Scope.zig");
const Translator = @import("Translator.zig");

const Error = Translator.Error;
pub const ParseError = Error || error{ParseError};

const MacroTranslator = @This();

t: *Translator,
macro: aro.Preprocessor.Macro,
name: []const u8,

tokens: []const CToken,
source: []const u8,
i: usize = 0,
/// If an object macro references a global var it needs to be converted into
/// an inline function.
refs_var_decl: bool = false,

fn peek(mt: *MacroTranslator) CToken.Id {
    if (mt.i >= mt.tokens.len) return .eof;
    return mt.tokens[mt.i].id;
}

fn eat(mt: *MacroTranslator, expected_id: CToken.Id) bool {
    if (mt.peek() == expected_id) {
        mt.i += 1;
        return true;
    }
    return false;
}

fn expect(mt: *MacroTranslator, expected_id: CToken.Id) ParseError!void {
    const next_id = mt.peek();
    if (next_id != expected_id and !(expected_id == .identifier and next_id == .extended_identifier)) {
        try mt.fail(
            "unable to translate C expr: expected '{s}' instead got '{s}'",
            .{ expected_id.symbol(), next_id.symbol() },
        );
        return error.ParseError;
    }
    mt.i += 1;
}

fn fail(mt: *MacroTranslator, comptime fmt: []const u8, args: anytype) !void {
    return mt.t.failDeclExtra(&mt.t.global_scope.base, mt.macro.loc, mt.name, fmt, args);
}

fn tokSlice(mt: *const MacroTranslator) []const u8 {
    const tok = mt.tokens[mt.i];
    return mt.source[tok.start..tok.end];
}

pub fn transFnMacro(mt: *MacroTranslator) ParseError!void {
    var block_scope = try Scope.Block.init(mt.t, &mt.t.global_scope.base, false);
    defer block_scope.deinit();
    const scope = &block_scope.base;

    const fn_params = try mt.t.arena.alloc(ast.Payload.Param, mt.macro.params.len);
    for (fn_params, mt.macro.params) |*param, param_name| {
        const mangled_name = try block_scope.makeMangledName(param_name);
        param.* = .{
            .is_noalias = false,
            .name = mangled_name,
            .type = ZigTag.@"anytype".init(),
        };
        try block_scope.discardVariable(mangled_name);
    }

    // #define FOO(x)
    if (mt.peek() == .eof) {
        try block_scope.statements.append(mt.t.gpa, ZigTag.return_void.init());

        const fn_decl = try ZigTag.pub_inline_fn.create(mt.t.arena, .{
            .name = mt.name,
            .params = fn_params,
            .return_type = ZigTag.void_type.init(),
            .body = try block_scope.complete(),
        });
        try mt.t.addTopLevelDecl(mt.name, fn_decl);
        return;
    }

    const expr = try mt.parseCExpr(scope);
    const last = mt.peek();
    if (last != .eof)
        return mt.fail("unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const typeof_arg = if (expr.castTag(.block)) |some| blk: {
        const stmts = some.data.stmts;
        const blk_last = stmts[stmts.len - 1];
        const br = blk_last.castTag(.break_val).?;
        break :blk br.data.val;
    } else expr;

    const return_type = ret: {
        if (typeof_arg.castTag(.helper_call)) |some| {
            if (std.mem.eql(u8, some.data.name, "cast")) {
                break :ret some.data.args[0];
            }
        }
        if (typeof_arg.castTag(.std_mem_zeroinit)) |some| break :ret some.data.lhs;
        if (typeof_arg.castTag(.std_mem_zeroes)) |some| break :ret some.data;
        break :ret try ZigTag.typeof.create(mt.t.arena, typeof_arg);
    };

    const return_expr = try ZigTag.@"return".create(mt.t.arena, expr);
    try block_scope.statements.append(mt.t.gpa, return_expr);

    const fn_decl = try ZigTag.pub_inline_fn.create(mt.t.arena, .{
        .name = mt.name,
        .params = fn_params,
        .return_type = return_type,
        .body = try block_scope.complete(),
    });
    try mt.t.addTopLevelDecl(mt.name, fn_decl);
}

pub fn transMacro(mt: *MacroTranslator) ParseError!void {
    const scope = &mt.t.global_scope.base;

    // Check if the macro only uses other blank macros.
    while (true) {
        switch (mt.peek()) {
            .identifier, .extended_identifier => {
                if (mt.t.global_scope.blank_macros.contains(mt.tokSlice())) {
                    mt.i += 1;
                    continue;
                }
            },
            .eof, .nl => {
                try mt.t.global_scope.blank_macros.put(mt.t.gpa, mt.name, {});
                const init_node = try ZigTag.string_literal.create(mt.t.arena, "\"\"");
                const var_decl = try ZigTag.pub_var_simple.create(mt.t.arena, .{ .name = mt.name, .init = init_node });
                try mt.t.addTopLevelDecl(mt.name, var_decl);
                return;
            },
            else => {},
        }
        break;
    }

    const init_node = try mt.parseCExpr(scope);
    const last = mt.peek();
    if (last != .eof)
        return mt.fail("unable to translate C expr: unexpected token '{s}'", .{last.symbol()});

    const node = node: {
        const var_decl = try ZigTag.pub_var_simple.create(mt.t.arena, .{ .name = mt.name, .init = init_node });

        if (mt.t.getFnProto(var_decl)) |proto_node| {
            // If a macro aliases a global variable which is a function pointer, we conclude that
            // the macro is intended to represent a function that assumes the function pointer
            // variable is non-null and calls it.
            break :node try mt.createMacroFn(mt.name, var_decl, proto_node);
        } else if (mt.refs_var_decl) {
            const return_type = try ZigTag.typeof.create(mt.t.arena, init_node);
            const return_expr = try ZigTag.@"return".create(mt.t.arena, init_node);
            const block = try ZigTag.block_single.create(mt.t.arena, return_expr);

            const loc_str = try mt.t.locStr(mt.macro.loc);
            const value = try std.fmt.allocPrint(mt.t.arena, "\n// {s}: warning: macro '{s}' contains a runtime value, translated to function", .{ loc_str, mt.name });
            try scope.appendNode(try ZigTag.warning.create(mt.t.arena, value));

            break :node try ZigTag.pub_inline_fn.create(mt.t.arena, .{
                .name = mt.name,
                .params = &.{},
                .return_type = return_type,
                .body = block,
            });
        }

        break :node var_decl;
    };

    try mt.t.addTopLevelDecl(mt.name, node);
}

fn createMacroFn(mt: *MacroTranslator, name: []const u8, ref: ZigNode, proto_alias: *ast.Payload.Func) !ZigNode {
    const gpa = mt.t.gpa;
    const arena = mt.t.arena;
    var fn_params: std.ArrayList(ast.Payload.Param) = .empty;
    defer fn_params.deinit(gpa);

    var block_scope = try Scope.Block.init(mt.t, &mt.t.global_scope.base, false);
    defer block_scope.deinit();

    for (proto_alias.data.params) |param| {
        const param_name = try block_scope.makeMangledName(param.name orelse "arg");

        try fn_params.append(gpa, .{
            .name = param_name,
            .type = param.type,
            .is_noalias = param.is_noalias,
        });
    }

    const init = if (ref.castTag(.var_decl)) |v|
        v.data.init.?
    else if (ref.castTag(.var_simple) orelse ref.castTag(.pub_var_simple)) |v|
        v.data.init
    else
        unreachable;

    const unwrap_expr = try ZigTag.unwrap.create(arena, init);
    const args = try arena.alloc(ZigNode, fn_params.items.len);
    for (fn_params.items, 0..) |param, i| {
        args[i] = try ZigTag.identifier.create(arena, param.name.?);
    }
    const call_expr = try ZigTag.call.create(arena, .{
        .lhs = unwrap_expr,
        .args = args,
    });
    const return_expr = try ZigTag.@"return".create(arena, call_expr);
    const block = try ZigTag.block_single.create(arena, return_expr);

    return ZigTag.pub_inline_fn.create(arena, .{
        .name = name,
        .params = try arena.dupe(ast.Payload.Param, fn_params.items),
        .return_type = proto_alias.data.return_type,
        .body = block,
    });
}

fn parseCExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    const arena = mt.t.arena;
    // TODO parseCAssignExpr here
    var block_scope = try Scope.Block.init(mt.t, scope, true);
    defer block_scope.deinit();

    const node = try mt.parseCCondExpr(&block_scope.base);
    if (!mt.eat(.comma)) return node;

    var last = node;
    while (true) {
        // suppress result
        const ignore = try ZigTag.discard.create(arena, .{ .should_skip = false, .value = last });
        try block_scope.statements.append(mt.t.gpa, ignore);

        last = try mt.parseCCondExpr(&block_scope.base);
        if (!mt.eat(.comma)) break;
    }

    const break_node = try ZigTag.break_val.create(arena, .{
        .label = block_scope.label,
        .val = last,
    });
    try block_scope.statements.append(mt.t.gpa, break_node);
    return try block_scope.complete();
}

fn parseCNumLit(mt: *MacroTranslator) ParseError!ZigNode {
    const arena = mt.t.arena;
    const lit_bytes = mt.tokSlice();
    mt.i += 1;

    var bytes = try std.ArrayList(u8).initCapacity(arena, lit_bytes.len + 3);

    const prefix = aro.Tree.Token.NumberPrefix.fromString(lit_bytes);
    switch (prefix) {
        .binary => bytes.appendSliceAssumeCapacity("0b"),
        .octal => bytes.appendSliceAssumeCapacity("0o"),
        .hex => bytes.appendSliceAssumeCapacity("0x"),
        .decimal => {},
    }

    const after_prefix = lit_bytes[prefix.stringLen()..];
    const after_int = for (after_prefix, 0..) |c, i| switch (c) {
        '.' => {
            if (i == 0) {
                bytes.appendAssumeCapacity('0');
            }
            break after_prefix[i..];
        },
        'e', 'E' => {
            if (prefix != .hex) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        'p', 'P' => break after_prefix[i..],
        '0'...'9', 'a'...'d', 'A'...'D', 'f', 'F' => {
            if (!prefix.digitAllowed(c)) break after_prefix[i..];
            bytes.appendAssumeCapacity(c);
        },
        '\'' => {
            bytes.appendAssumeCapacity('_');
        },
        else => break after_prefix[i..],
    } else "";

    const after_frac = frac: {
        if (after_int.len == 0 or after_int[0] != '.') break :frac after_int;
        bytes.appendAssumeCapacity('.');
        for (after_int[1..], 1..) |c, i| {
            if (c == '\'') {
                bytes.appendAssumeCapacity('_');
                continue;
            }
            if (!prefix.digitAllowed(c)) break :frac after_int[i..];
            bytes.appendAssumeCapacity(c);
        }
        break :frac "";
    };

    const suffix_str = exponent: {
        if (after_frac.len == 0) break :exponent after_frac;
        switch (after_frac[0]) {
            'e', 'E' => {},
            'p', 'P' => if (prefix != .hex) break :exponent after_frac,
            else => break :exponent after_frac,
        }
        bytes.appendAssumeCapacity(after_frac[0]);
        for (after_frac[1..], 1..) |c, i| switch (c) {
            '+', '-', '0'...'9' => {
                bytes.appendAssumeCapacity(c);
            },
            '\'' => {
                bytes.appendAssumeCapacity('_');
            },
            else => break :exponent after_frac[i..],
        };
        break :exponent "";
    };

    const is_float = after_int.len != suffix_str.len;
    const suffix = aro.Tree.Token.NumberSuffix.fromString(suffix_str, if (is_float) .float else .int) orelse {
        try mt.fail("invalid number suffix: '{s}'", .{suffix_str});
        return error.ParseError;
    };
    if (suffix.isImaginary()) {
        try mt.fail("TODO: imaginary literals", .{});
        return error.ParseError;
    }
    if (suffix.isBitInt()) {
        try mt.fail("TODO: _BitInt literals", .{});
        return error.ParseError;
    }

    if (is_float) {
        const type_node = try ZigTag.type.create(arena, switch (suffix) {
            .F16 => "f16",
            .F => "f32",
            .None => "f64",
            .L => "c_longdouble",
            .W => "f80",
            .Q, .F128 => "f128",
            else => unreachable,
        });
        const rhs = try ZigTag.float_literal.create(arena, bytes.items);
        return ZigTag.as.create(arena, .{ .lhs = type_node, .rhs = rhs });
    } else {
        const type_node = try ZigTag.type.create(arena, switch (suffix) {
            .None => "c_int",
            .U => "c_uint",
            .L => "c_long",
            .UL => "c_ulong",
            .LL => "c_longlong",
            .ULL => "c_ulonglong",
            else => unreachable,
        });
        const value = std.fmt.parseInt(i128, bytes.items, 0) catch math.maxInt(i128);

        // make the output less noisy by skipping promoteIntLiteral where
        // it's guaranteed to not be required because of C standard type constraints
        const guaranteed_to_fit = switch (suffix) {
            .None => math.cast(i16, value) != null,
            .U => math.cast(u16, value) != null,
            .L => math.cast(i32, value) != null,
            .UL => math.cast(u32, value) != null,
            .LL => math.cast(i64, value) != null,
            .ULL => math.cast(u64, value) != null,
            else => unreachable,
        };

        const literal_node = try ZigTag.integer_literal.create(arena, bytes.items);
        if (guaranteed_to_fit) {
            return ZigTag.as.create(arena, .{ .lhs = type_node, .rhs = literal_node });
        } else {
            return mt.t.createHelperCallNode(.promoteIntLiteral, &.{ type_node, literal_node, try ZigTag.enum_literal.create(arena, @tagName(prefix)) });
        }
    }
}

fn zigifyEscapeSequences(mt: *MacroTranslator, slice: []const u8) ![]const u8 {
    var source = slice;
    for (source, 0..) |c, i| {
        if (c == '\"' or c == '\'') {
            source = source[i..];
            break;
        }
    }
    for (source) |c| {
        if (c == '\\' or c == '\t') {
            break;
        }
    } else return source;
    const bytes = try mt.t.arena.alloc(u8, source.len * 2);
    var state: enum {
        start,
        escape,
        hex,
        octal,
    } = .start;
    var i: usize = 0;
    var count: u8 = 0;
    var num: u8 = 0;
    for (source) |c| {
        switch (state) {
            .escape => {
                switch (c) {
                    'n', 'r', 't', '\\', '\'', '\"' => {
                        bytes[i] = c;
                    },
                    '0'...'7' => {
                        count += 1;
                        num += c - '0';
                        state = .octal;
                        bytes[i] = 'x';
                    },
                    'x' => {
                        state = .hex;
                        bytes[i] = 'x';
                    },
                    'a' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '7';
                    },
                    'b' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = '8';
                    },
                    'f' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'C';
                    },
                    'v' => {
                        bytes[i] = 'x';
                        i += 1;
                        bytes[i] = '0';
                        i += 1;
                        bytes[i] = 'B';
                    },
                    '?' => {
                        i -= 1;
                        bytes[i] = '?';
                    },
                    'u', 'U' => {
                        try mt.fail("macro tokenizing failed: TODO unicode escape sequences", .{});
                        return error.ParseError;
                    },
                    else => {
                        try mt.fail("macro tokenizing failed: unknown escape sequence", .{});
                        return error.ParseError;
                    },
                }
                i += 1;
                if (state == .escape)
                    state = .start;
            },
            .start => {
                if (c == '\t') {
                    bytes[i] = '\\';
                    i += 1;
                    bytes[i] = 't';
                    i += 1;
                    continue;
                }
                if (c == '\\') {
                    state = .escape;
                }
                bytes[i] = c;
                i += 1;
            },
            .hex => {
                switch (c) {
                    '0'...'9' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - '0';
                    },
                    'a'...'f' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'a' + 10;
                    },
                    'A'...'F' => {
                        num = std.math.mul(u8, num, 16) catch {
                            try mt.fail("macro tokenizing failed: hex literal overflowed", .{});
                            return error.ParseError;
                        };
                        num += c - 'A' + 10;
                    },
                    else => {
                        i += std.fmt.printInt(bytes[i..], num, 16, .lower, .{ .fill = '0', .width = 2 });
                        num = 0;
                        if (c == '\\')
                            state = .escape
                        else
                            state = .start;
                        bytes[i] = c;
                        i += 1;
                    },
                }
            },
            .octal => {
                const accept_digit = switch (c) {
                    // The maximum length of a octal literal is 3 digits
                    '0'...'7' => count < 3,
                    else => false,
                };

                if (accept_digit) {
                    count += 1;
                    num = std.math.mul(u8, num, 8) catch {
                        try mt.fail("macro tokenizing failed: octal literal overflowed", .{});
                        return error.ParseError;
                    };
                    num += c - '0';
                } else {
                    i += std.fmt.printInt(bytes[i..], num, 16, .lower, .{ .fill = '0', .width = 2 });
                    num = 0;
                    count = 0;
                    if (c == '\\')
                        state = .escape
                    else
                        state = .start;
                    bytes[i] = c;
                    i += 1;
                }
            },
        }
    }
    if (state == .hex or state == .octal) {
        i += std.fmt.printInt(bytes[i..], num, 16, .lower, .{ .fill = '0', .width = 2 });
    }

    return bytes[0..i];
}

/// non-ASCII characters (mt > 127) are also treated as non-printable by fmtSliceEscapeLower.
/// If a C string literal or char literal in a macro is not valid UTF-8, we need to escape
/// non-ASCII characters so that the Zig source we output will itself be UTF-8.
fn escapeUnprintables(mt: *MacroTranslator) ![]const u8 {
    const slice = mt.tokSlice();
    mt.i += 1;

    const zigified = try mt.zigifyEscapeSequences(slice);
    if (std.unicode.utf8ValidateSlice(zigified)) return zigified;

    const formatter = std.ascii.hexEscape(zigified, .lower);
    const encoded_size = @as(usize, @intCast(std.fmt.count("{f}", .{formatter})));
    const output = try mt.t.arena.alloc(u8, encoded_size);
    return std.fmt.bufPrint(output, "{f}", .{formatter}) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
        else => |e| return e,
    };
}

fn parseCPrimaryExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    const arena = mt.t.arena;
    const tok = mt.peek();
    switch (tok) {
        .char_literal,
        .char_literal_utf_8,
        .char_literal_utf_16,
        .char_literal_utf_32,
        .char_literal_wide,
        => {
            const slice = mt.tokSlice();
            if (slice[0] != '\'' or slice[1] == '\\' or slice.len == 3) {
                return ZigTag.char_literal.create(arena, try mt.escapeUnprintables());
            } else {
                mt.i += 1;

                const str = try std.fmt.allocPrint(arena, "0x{x}", .{slice[1 .. slice.len - 1]});
                return ZigTag.integer_literal.create(arena, str);
            }
        },
        .string_literal,
        .string_literal_utf_16,
        .string_literal_utf_8,
        .string_literal_utf_32,
        .string_literal_wide,
        => return ZigTag.string_literal.create(arena, try mt.escapeUnprintables()),
        .pp_num => return mt.parseCNumLit(),
        .l_paren => {
            mt.i += 1;
            const inner_node = try mt.parseCExpr(scope);

            try mt.expect(.r_paren);
            return inner_node;
        },
        .macro_param, .macro_param_no_expand => {
            const param = mt.macro.params[mt.tokens[mt.i].end];
            mt.i += 1;

            const mangled_name = scope.getAlias(param) orelse param;
            return try ZigTag.identifier.create(arena, mangled_name);
        },
        .identifier, .extended_identifier => {
            const slice = mt.tokSlice();
            mt.i += 1;

            const mangled_name = scope.getAlias(slice) orelse slice;
            if (Translator.builtin_typedef_map.get(mangled_name)) |ty| {
                return ZigTag.type.create(arena, ty);
            }
            if (builtins.map.get(mangled_name)) |builtin| {
                const builtin_identifier = try ZigTag.identifier.create(arena, "__builtin");
                return ZigTag.field_access.create(arena, .{
                    .lhs = builtin_identifier,
                    .field_name = builtin.name,
                });
            }

            const identifier = try ZigTag.identifier.create(arena, mangled_name);
            scope.skipVariableDiscard(mangled_name);
            refs_var: {
                const ident_node = mt.t.global_scope.sym_table.get(slice) orelse break :refs_var;
                const var_decl_node = ident_node.castTag(.var_decl) orelse break :refs_var;
                if (!var_decl_node.data.is_const) mt.refs_var_decl = true;
            }
            return identifier;
        },
        else => {},
    }

    // for handling type macros (EVIL)
    // TODO maybe detect and treat type macros as typedefs in parseCSpecifierQualifierList?
    if (try mt.parseCTypeName(scope)) |type_name| {
        return type_name;
    }

    try mt.fail("unable to translate C expr: unexpected token '{s}'", .{tok.symbol()});
    return error.ParseError;
}

fn macroIntFromBool(mt: *MacroTranslator, node: ZigNode) !ZigNode {
    if (!node.isBoolRes()) return node;

    return ZigTag.int_from_bool.create(mt.t.arena, node);
}

fn macroIntToBool(mt: *MacroTranslator, node: ZigNode) !ZigNode {
    if (node.isBoolRes()) return node;

    if (node.tag() == .string_literal) {
        // @intFromPtr(node) != 0
        const int_from_ptr = try ZigTag.int_from_ptr.create(mt.t.arena, node);
        return ZigTag.not_equal.create(mt.t.arena, .{ .lhs = int_from_ptr, .rhs = ZigTag.zero_literal.init() });
    }
    // node != 0
    return ZigTag.not_equal.create(mt.t.arena, .{ .lhs = node, .rhs = ZigTag.zero_literal.init() });
}

fn parseCCondExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    const node = try mt.parseCOrExpr(scope);
    if (!mt.eat(.question_mark)) return node;

    const then_body = try mt.parseCOrExpr(scope);
    try mt.expect(.colon);
    const else_body = try mt.parseCCondExpr(scope);
    return ZigTag.@"if".create(mt.t.arena, .{ .cond = node, .then = then_body, .@"else" = else_body });
}

fn parseCOrExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCAndExpr(scope);
    while (mt.eat(.pipe_pipe)) {
        const lhs = try mt.macroIntToBool(node);
        const rhs = try mt.macroIntToBool(try mt.parseCAndExpr(scope));
        node = try ZigTag.@"or".create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    return node;
}

fn parseCAndExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitOrExpr(scope);
    while (mt.eat(.ampersand_ampersand)) {
        const lhs = try mt.macroIntToBool(node);
        const rhs = try mt.macroIntToBool(try mt.parseCBitOrExpr(scope));
        node = try ZigTag.@"and".create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    return node;
}

fn parseCBitOrExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitXorExpr(scope);
    while (mt.eat(.pipe)) {
        const lhs = try mt.macroIntFromBool(node);
        const rhs = try mt.macroIntFromBool(try mt.parseCBitXorExpr(scope));
        node = try ZigTag.bit_or.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    return node;
}

fn parseCBitXorExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCBitAndExpr(scope);
    while (mt.eat(.caret)) {
        const lhs = try mt.macroIntFromBool(node);
        const rhs = try mt.macroIntFromBool(try mt.parseCBitAndExpr(scope));
        node = try ZigTag.bit_xor.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    return node;
}

fn parseCBitAndExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCEqExpr(scope);
    while (mt.eat(.ampersand)) {
        const lhs = try mt.macroIntFromBool(node);
        const rhs = try mt.macroIntFromBool(try mt.parseCEqExpr(scope));
        node = try ZigTag.bit_and.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
    }
    return node;
}

fn parseCEqExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCRelExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .bang_equal => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCRelExpr(scope));
                node = try ZigTag.not_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .equal_equal => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCRelExpr(scope));
                node = try ZigTag.equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCRelExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCShiftExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .angle_bracket_right => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCShiftExpr(scope));
                node = try ZigTag.greater_than.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_right_equal => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCShiftExpr(scope));
                node = try ZigTag.greater_than_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCShiftExpr(scope));
                node = try ZigTag.less_than.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_left_equal => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCShiftExpr(scope));
                node = try ZigTag.less_than_equal.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCShiftExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCAddSubExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .angle_bracket_angle_bracket_left => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCAddSubExpr(scope));
                node = try ZigTag.shl.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .angle_bracket_angle_bracket_right => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCAddSubExpr(scope));
                node = try ZigTag.shr.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCAddSubExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCMulExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .plus => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCMulExpr(scope));
                node = try ZigTag.add.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .minus => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCMulExpr(scope));
                node = try ZigTag.sub.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            else => return node,
        }
    }
}

fn parseCMulExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    var node = try mt.parseCCastExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .asterisk => {
                mt.i += 1;
                switch (mt.peek()) {
                    .comma, .r_paren, .eof => {
                        // This is probably a pointer type
                        return ZigTag.c_pointer.create(mt.t.arena, .{
                            .is_const = false,
                            .is_volatile = false,
                            .is_allowzero = false,
                            .elem_type = node,
                        });
                    },
                    else => {},
                }
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCCastExpr(scope));
                node = try ZigTag.mul.create(mt.t.arena, .{ .lhs = lhs, .rhs = rhs });
            },
            .slash => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCCastExpr(scope));
                node = try mt.t.createHelperCallNode(.div, &.{ lhs, rhs });
            },
            .percent => {
                mt.i += 1;
                const lhs = try mt.macroIntFromBool(node);
                const rhs = try mt.macroIntFromBool(try mt.parseCCastExpr(scope));
                node = try mt.t.createHelperCallNode(.rem, &.{ lhs, rhs });
            },
            else => return node,
        }
    }
}

fn parseCCastExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    if (mt.eat(.l_paren)) {
        if (try mt.parseCTypeName(scope)) |type_name| {
            while (true) {
                const next_tok = mt.peek();
                if (next_tok == .r_paren) {
                    mt.i += 1;
                    break;
                }
                // Skip trailing blank defined before the RParen.
                if ((next_tok == .identifier or next_tok == .extended_identifier) and
                    mt.t.global_scope.blank_macros.contains(mt.tokSlice()))
                {
                    mt.i += 1;
                    continue;
                }

                try mt.fail(
                    "unable to translate C expr: expected ')' instead got '{s}'",
                    .{next_tok.symbol()},
                );
                return error.ParseError;
            }
            if (mt.peek() == .l_brace) {
                // initializer list
                return mt.parseCPostfixExpr(scope, type_name);
            }
            const node_to_cast = try mt.parseCCastExpr(scope);
            return mt.t.createHelperCallNode(.cast, &.{ type_name, node_to_cast });
        }
        mt.i -= 1; // l_paren
    }
    return mt.parseCUnaryExpr(scope);
}

// allow_fail is set when unsure if we are parsing a type-name
fn parseCTypeName(mt: *MacroTranslator, scope: *Scope) ParseError!?ZigNode {
    if (try mt.parseCSpecifierQualifierList(scope)) |node| {
        return try mt.parseCAbstractDeclarator(node);
    }
    return null;
}

fn parseCSpecifierQualifierList(mt: *MacroTranslator, scope: *Scope) ParseError!?ZigNode {
    const tok = mt.peek();
    switch (tok) {
        .macro_param, .macro_param_no_expand => {
            const param = mt.macro.params[mt.tokens[mt.i].end];

            // Assume that this is only a cast if the next token is ')'
            // e.g. param)identifier
            if (mt.macro.tokens.len < mt.i + 3 or
                mt.macro.tokens[mt.i + 1].id != .r_paren or
                mt.macro.tokens[mt.i + 2].id != .identifier)
                return null;

            mt.i += 1;
            const mangled_name = scope.getAlias(param) orelse param;
            return try ZigTag.identifier.create(mt.t.arena, mangled_name);
        },
        .identifier, .extended_identifier => {
            const slice = mt.tokSlice();
            const mangled_name = scope.getAlias(slice) orelse slice;

            if (mt.t.global_scope.blank_macros.contains(slice)) {
                mt.i += 1;
                return try mt.parseCSpecifierQualifierList(scope);
            }

            if (mt.t.typedefs.contains(mangled_name)) {
                mt.i += 1;
                if (Translator.builtin_typedef_map.get(mangled_name)) |ty| {
                    return try ZigTag.type.create(mt.t.arena, ty);
                }
                if (builtins.map.get(mangled_name)) |builtin| {
                    const builtin_identifier = try ZigTag.identifier.create(mt.t.arena, "__builtin");
                    return try ZigTag.field_access.create(mt.t.arena, .{
                        .lhs = builtin_identifier,
                        .field_name = builtin.name,
                    });
                }

                return try ZigTag.identifier.create(mt.t.arena, mangled_name);
            }
        },
        .keyword_void => {
            mt.i += 1;
            return try ZigTag.type.create(mt.t.arena, "anyopaque");
        },
        .keyword_bool => {
            mt.i += 1;
            return try ZigTag.type.create(mt.t.arena, "bool");
        },
        .keyword_char,
        .keyword_int,
        .keyword_short,
        .keyword_long,
        .keyword_float,
        .keyword_double,
        .keyword_signed,
        .keyword_unsigned,
        .keyword_complex,
        => return try mt.parseCNumericType(),
        .keyword_enum, .keyword_struct, .keyword_union => {
            const tag_name = mt.tokSlice();
            mt.i += 1;
            if (mt.peek() != .identifier) {
                mt.i -= 1;
                return null;
            }

            // struct Foo will be declared as struct_Foo by transRecordDecl
            const identifier = mt.tokSlice();
            try mt.expect(.identifier);

            const name = try std.fmt.allocPrint(mt.t.arena, "{s}_{s}", .{ tag_name, identifier });
            if (!mt.t.global_scope.contains(name)) {
                try mt.fail("unable to translate C expr: '{s}' not found", .{name});
                return error.ParseError;
            }

            return try ZigTag.identifier.create(mt.t.arena, name);
        },
        else => {},
    }

    return null;
}

fn parseCNumericType(mt: *MacroTranslator) ParseError!ZigNode {
    const KwCounter = struct {
        double: u8 = 0,
        long: u8 = 0,
        int: u8 = 0,
        float: u8 = 0,
        short: u8 = 0,
        char: u8 = 0,
        unsigned: u8 = 0,
        signed: u8 = 0,
        complex: u8 = 0,

        fn eql(self: @This(), other: @This()) bool {
            return std.meta.eql(self, other);
        }
    };

    // Yes, these can be in *any* order
    // This still doesn't cover cases where for example volatile is intermixed

    var kw = KwCounter{};
    // prevent overflow
    var i: u8 = 0;
    while (i < math.maxInt(u8)) : (i += 1) {
        switch (mt.peek()) {
            .keyword_double => kw.double += 1,
            .keyword_long => kw.long += 1,
            .keyword_int => kw.int += 1,
            .keyword_float => kw.float += 1,
            .keyword_short => kw.short += 1,
            .keyword_char => kw.char += 1,
            .keyword_unsigned => kw.unsigned += 1,
            .keyword_signed => kw.signed += 1,
            .keyword_complex => kw.complex += 1,
            else => break,
        }
        mt.i += 1;
    }

    if (kw.eql(.{ .int = 1 }) or kw.eql(.{ .signed = 1 }) or kw.eql(.{ .signed = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_int");

    if (kw.eql(.{ .unsigned = 1 }) or kw.eql(.{ .unsigned = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_uint");

    if (kw.eql(.{ .long = 1 }) or kw.eql(.{ .signed = 1, .long = 1 }) or kw.eql(.{ .long = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_long");

    if (kw.eql(.{ .unsigned = 1, .long = 1 }) or kw.eql(.{ .unsigned = 1, .long = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ulong");

    if (kw.eql(.{ .long = 2 }) or kw.eql(.{ .signed = 1, .long = 2 }) or kw.eql(.{ .long = 2, .int = 1 }) or kw.eql(.{ .signed = 1, .long = 2, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_longlong");

    if (kw.eql(.{ .unsigned = 1, .long = 2 }) or kw.eql(.{ .unsigned = 1, .long = 2, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ulonglong");

    if (kw.eql(.{ .signed = 1, .char = 1 }))
        return ZigTag.type.create(mt.t.arena, "i8");

    if (kw.eql(.{ .char = 1 }) or kw.eql(.{ .unsigned = 1, .char = 1 }))
        return ZigTag.type.create(mt.t.arena, "u8");

    if (kw.eql(.{ .short = 1 }) or kw.eql(.{ .signed = 1, .short = 1 }) or kw.eql(.{ .short = 1, .int = 1 }) or kw.eql(.{ .signed = 1, .short = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_short");

    if (kw.eql(.{ .unsigned = 1, .short = 1 }) or kw.eql(.{ .unsigned = 1, .short = 1, .int = 1 }))
        return ZigTag.type.create(mt.t.arena, "c_ushort");

    if (kw.eql(.{ .float = 1 }))
        return ZigTag.type.create(mt.t.arena, "f32");

    if (kw.eql(.{ .double = 1 }))
        return ZigTag.type.create(mt.t.arena, "f64");

    if (kw.eql(.{ .long = 1, .double = 1 })) {
        try mt.fail("unable to translate: TODO long double", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .float = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .double = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    if (kw.eql(.{ .long = 1, .double = 1, .complex = 1 })) {
        try mt.fail("unable to translate: TODO _Complex", .{});
        return error.ParseError;
    }

    try mt.fail("unable to translate: invalid numeric type", .{});
    return error.ParseError;
}

fn parseCAbstractDeclarator(mt: *MacroTranslator, node: ZigNode) ParseError!ZigNode {
    if (mt.eat(.asterisk)) {
        if (node.castTag(.type)) |some| {
            if (std.mem.eql(u8, some.data, "anyopaque")) {
                const ptr = try ZigTag.single_pointer.create(mt.t.arena, .{
                    .is_const = false,
                    .is_volatile = false,
                    .is_allowzero = false,
                    .elem_type = node,
                });
                return ZigTag.optional_type.create(mt.t.arena, ptr);
            }
        }
        return ZigTag.c_pointer.create(mt.t.arena, .{
            .is_const = false,
            .is_volatile = false,
            .is_allowzero = false,
            .elem_type = node,
        });
    }
    return node;
}

fn parseCPostfixExpr(mt: *MacroTranslator, scope: *Scope, type_name: ?ZigNode) ParseError!ZigNode {
    var node = try mt.parseCPostfixExprInner(scope, type_name);
    // In C the preprocessor would handle concatting strings while expanding macros.
    // This should do approximately the same by concatting any strings and identifiers
    // after a primary or postfix expression.
    while (true) {
        switch (mt.peek()) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => {},
            .identifier, .extended_identifier => {
                if (mt.t.global_scope.blank_macros.contains(mt.tokSlice())) {
                    mt.i += 1;
                    continue;
                }
            },
            else => break,
        }
        const rhs = try mt.parseCPostfixExprInner(scope, type_name);
        node = try ZigTag.array_cat.create(mt.t.arena, .{ .lhs = node, .rhs = rhs });
    }
    return node;
}

fn parseCPostfixExprInner(mt: *MacroTranslator, scope: *Scope, type_name: ?ZigNode) ParseError!ZigNode {
    const gpa = mt.t.gpa;
    const arena = mt.t.arena;
    var node = type_name orelse try mt.parseCPrimaryExpr(scope);
    while (true) {
        switch (mt.peek()) {
            .period => {
                mt.i += 1;
                const tok = mt.tokens[mt.i];
                if (tok.id == .macro_param or tok.id == .macro_param_no_expand) {
                    try mt.fail("unable to translate C expr: field access using macro parameter", .{});
                    return error.ParseError;
                }
                const field_name = mt.tokSlice();
                try mt.expect(.identifier);

                node = try ZigTag.field_access.create(arena, .{ .lhs = node, .field_name = field_name });
            },
            .arrow => {
                mt.i += 1;
                const tok = mt.tokens[mt.i];
                if (tok.id == .macro_param or tok.id == .macro_param_no_expand) {
                    try mt.fail("unable to translate C expr: field access using macro parameter", .{});
                    return error.ParseError;
                }
                const field_name = mt.tokSlice();
                try mt.expect(.identifier);

                const deref = try ZigTag.deref.create(arena, node);
                node = try ZigTag.field_access.create(arena, .{ .lhs = deref, .field_name = field_name });
            },
            .l_bracket => {
                mt.i += 1;

                const index_val = try mt.macroIntFromBool(try mt.parseCExpr(scope));
                const index = try ZigTag.as.create(arena, .{
                    .lhs = try ZigTag.type.create(arena, "usize"),
                    .rhs = try ZigTag.int_cast.create(arena, index_val),
                });
                node = try ZigTag.array_access.create(arena, .{ .lhs = node, .rhs = index });
                try mt.expect(.r_bracket);
            },
            .l_paren => {
                mt.i += 1;

                if (mt.eat(.r_paren)) {
                    node = try ZigTag.call.create(arena, .{ .lhs = node, .args = &.{} });
                } else {
                    var args: std.ArrayList(ZigNode) = .empty;
                    defer args.deinit(gpa);

                    while (true) {
                        const arg = try mt.parseCCondExpr(scope);
                        try args.append(gpa, arg);

                        const next_id = mt.peek();
                        switch (next_id) {
                            .comma => {
                                mt.i += 1;
                            },
                            .r_paren => {
                                mt.i += 1;
                                break;
                            },
                            else => {
                                try mt.fail("unable to translate C expr: expected ',' or ')' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    node = try ZigTag.call.create(arena, .{ .lhs = node, .args = try arena.dupe(ZigNode, args.items) });
                }
            },
            .l_brace => {
                mt.i += 1;

                // Check for designated field initializers
                if (mt.peek() == .period) {
                    var init_vals: std.ArrayList(ast.Payload.ContainerInitDot.Initializer) = .empty;
                    defer init_vals.deinit(gpa);

                    while (true) {
                        try mt.expect(.period);
                        const name = mt.tokSlice();
                        try mt.expect(.identifier);
                        try mt.expect(.equal);

                        const val = try mt.parseCCondExpr(scope);
                        try init_vals.append(gpa, .{ .name = name, .value = val });

                        const next_id = mt.peek();
                        switch (next_id) {
                            .comma => {
                                mt.i += 1;
                            },
                            .r_brace => {
                                mt.i += 1;
                                break;
                            },
                            else => {
                                try mt.fail("unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                                return error.ParseError;
                            },
                        }
                    }
                    const tuple_node = try ZigTag.container_init_dot.create(arena, try arena.dupe(ast.Payload.ContainerInitDot.Initializer, init_vals.items));
                    node = try ZigTag.std_mem_zeroinit.create(arena, .{ .lhs = node, .rhs = tuple_node });
                    continue;
                }

                var init_vals: std.ArrayList(ZigNode) = .empty;
                defer init_vals.deinit(gpa);

                while (true) {
                    const val = try mt.parseCCondExpr(scope);
                    try init_vals.append(gpa, val);

                    const next_id = mt.peek();
                    switch (next_id) {
                        .comma => {
                            mt.i += 1;
                        },
                        .r_brace => {
                            mt.i += 1;
                            break;
                        },
                        else => {
                            try mt.fail("unable to translate C expr: expected ',' or '}}' instead got '{s}'", .{next_id.symbol()});
                            return error.ParseError;
                        },
                    }
                }
                const tuple_node = try ZigTag.tuple.create(arena, try arena.dupe(ZigNode, init_vals.items));
                node = try ZigTag.std_mem_zeroinit.create(arena, .{ .lhs = node, .rhs = tuple_node });
            },
            .plus_plus, .minus_minus => {
                try mt.fail("TODO postfix inc/dec expr", .{});
                return error.ParseError;
            },
            else => return node,
        }
    }
}

fn parseCUnaryExpr(mt: *MacroTranslator, scope: *Scope) ParseError!ZigNode {
    switch (mt.peek()) {
        .bang => {
            mt.i += 1;
            const operand = try mt.macroIntToBool(try mt.parseCCastExpr(scope));
            return ZigTag.not.create(mt.t.arena, operand);
        },
        .minus => {
            mt.i += 1;
            const operand = try mt.macroIntFromBool(try mt.parseCCastExpr(scope));
            return ZigTag.negate.create(mt.t.arena, operand);
        },
        .plus => {
            mt.i += 1;
            return try mt.parseCCastExpr(scope);
        },
        .tilde => {
            mt.i += 1;
            const operand = try mt.macroIntFromBool(try mt.parseCCastExpr(scope));
            return ZigTag.bit_not.create(mt.t.arena, operand);
        },
        .asterisk => {
            mt.i += 1;
            const operand = try mt.parseCCastExpr(scope);
            return ZigTag.deref.create(mt.t.arena, operand);
        },
        .ampersand => {
            mt.i += 1;
            const operand = try mt.parseCCastExpr(scope);
            return ZigTag.address_of.create(mt.t.arena, operand);
        },
        .keyword_sizeof => {
            mt.i += 1;
            const operand = if (mt.eat(.l_paren)) blk: {
                const inner = (try mt.parseCTypeName(scope)) orelse try mt.parseCUnaryExpr(scope);
                try mt.expect(.r_paren);
                break :blk inner;
            } else try mt.parseCUnaryExpr(scope);

            return mt.t.createHelperCallNode(.sizeof, &.{operand});
        },
        .keyword_alignof => {
            mt.i += 1;
            // TODO this won't work if using <stdalign.h>'s
            // #define alignof _Alignof
            try mt.expect(.l_paren);
            const operand = (try mt.parseCTypeName(scope)) orelse try mt.parseCUnaryExpr(scope);
            try mt.expect(.r_paren);

            return ZigTag.alignof.create(mt.t.arena, operand);
        },
        .plus_plus, .minus_minus => {
            try mt.fail("TODO unary inc/dec expr", .{});
            return error.ParseError;
        },
        else => {},
    }

    return try mt.parseCPostfixExpr(scope, null);
}
