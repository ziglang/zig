const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Compilation = @import("Compilation.zig");
const Source = @import("Source.zig");
const Tokenizer = @import("Tokenizer.zig");
const Preprocessor = @import("Preprocessor.zig");
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const TokenIndex = Tree.TokenIndex;
const NodeIndex = Tree.NodeIndex;
const Type = @import("Type.zig");
const Diagnostics = @import("Diagnostics.zig");
const NodeList = std.ArrayList(NodeIndex);
const InitList = @import("InitList.zig");
const Attribute = @import("Attribute.zig");
const CharInfo = @import("CharInfo.zig");
const Value = @import("Value.zig");

const Parser = @This();

const Scope = union(enum) {
    typedef: Symbol,
    @"struct": Symbol,
    @"union": Symbol,
    @"enum": Symbol,
    decl: Symbol,
    def: Symbol,
    param: Symbol,
    enumeration: Enumeration,
    loop,
    @"switch": *Switch,
    block,

    const Symbol = struct {
        name: []const u8,
        ty: Type,
        name_tok: TokenIndex,
    };

    const Enumeration = struct {
        name: []const u8,
        value: Result,
        name_tok: TokenIndex,
    };

    const Switch = struct {
        cases: CaseMap,
        default: ?Case = null,

        const ResultContext = struct {
            ty: Type,
            comp: *Compilation,

            pub fn eql(ctx: ResultContext, a: Result, b: Result) bool {
                return a.val.compare(.eq, b.val, ctx.ty, ctx.comp);
            }
            pub fn hash(_: ResultContext, a: Result) u64 {
                return a.val.hash();
            }
        };
        const CaseMap = std.HashMap(Result, Case, ResultContext, std.hash_map.default_max_load_percentage);
        const Case = struct {
            node: NodeIndex,
            tok: TokenIndex,
        };
    };
};

const Label = union(enum) {
    unresolved_goto: TokenIndex,
    label: TokenIndex,
};

pub const Error = Compilation.Error || error{ParsingFailed};

/// An attribute that has been parsed but not yet validated in its context
const TentativeAttribute = struct {
    attr: Attribute,
    tok: TokenIndex,
};

// values from preprocessor
pp: *Preprocessor,
tok_ids: []const Token.Id,
tok_i: TokenIndex = 0,

// values of the incomplete Tree
arena: Allocator,
nodes: Tree.Node.List = .{},
data: NodeList,
strings: std.ArrayList(u8),
value_map: Tree.ValueMap,

// buffers used during compilation
scopes: std.ArrayList(Scope),
labels: std.ArrayList(Label),
list_buf: NodeList,
decl_buf: NodeList,
param_buf: std.ArrayList(Type.Func.Param),
enum_buf: std.ArrayList(Type.Enum.Field),
record_buf: std.ArrayList(Type.Record.Field),
attr_buf: std.MultiArrayList(TentativeAttribute) = .{},

// configuration and miscellaneous info
no_eval: bool = false,
in_macro: bool = false,
extension_suppressed: bool = false,
contains_address_of_label: bool = false,
label_count: u32 = 0,
/// location of first computed goto in function currently being parsed
/// if a computed goto is used, the function must contain an
/// address-of-label expression (tracked with contains_address_of_label)
computed_goto_tok: ?TokenIndex = null,

/// Various variables that are different for each function.
func: struct {
    /// null if not in function, will always be plain func, var_args_func or old_style_func
    ty: ?Type = null,
    name: TokenIndex = 0,
    ident: ?Result = null,
    pretty_ident: ?Result = null,
} = .{},
/// Various variables that are different for each record.
record: struct {
    // invalid means we're not parsing a record
    kind: Token.Id = .invalid,
    flexible_field: ?TokenIndex = null,
    scopes_top: usize = undefined,

    fn addField(r: @This(), p: *Parser, name_tok: TokenIndex) Error!void {
        const name = p.tokSlice(name_tok);
        var i = p.scopes.items.len;
        while (i > r.scopes_top) {
            i -= 1;
            switch (p.scopes.items[i]) {
                .def => |d| if (mem.eql(u8, d.name, name)) {
                    try p.errStr(.duplicate_member, name_tok, name);
                    try p.errTok(.previous_definition, d.name_tok);
                    break;
                },
                else => {},
            }
        }
        try p.scopes.append(.{
            .def = .{
                .name = name,
                .name_tok = name_tok,
                .ty = undefined, // unused
            },
        });
    }

    fn addFieldsFromAnonymous(r: @This(), p: *Parser, ty: Type) Error!void {
        for (ty.data.record.fields) |f| {
            if (f.isAnonymousRecord()) {
                try r.addFieldsFromAnonymous(p, f.ty.canonicalize(.standard));
            } else if (f.name_tok != 0) {
                try r.addField(p, f.name_tok);
            }
        }
    }
} = .{},

fn checkIdentifierCodepoint(comp: *Compilation, codepoint: u21, loc: Source.Location) Compilation.Error!bool {
    if (codepoint <= 0x7F) return false;
    var diagnosed = false;
    if (!CharInfo.isC99IdChar(codepoint)) {
        try comp.diag.add(.{
            .tag = .c99_compat,
            .loc = loc,
        }, &.{});
        diagnosed = true;
    }
    if (CharInfo.isInvisible(codepoint)) {
        try comp.diag.add(.{
            .tag = .unicode_zero_width,
            .loc = loc,
            .extra = .{ .actual_codepoint = codepoint },
        }, &.{});
        diagnosed = true;
    }
    if (CharInfo.homoglyph(codepoint)) |resembles| {
        try comp.diag.add(.{
            .tag = .unicode_homoglyph,
            .loc = loc,
            .extra = .{ .codepoints = .{ .actual = codepoint, .resembles = resembles } },
        }, &.{});
        diagnosed = true;
    }
    return diagnosed;
}

fn eatIdentifier(p: *Parser) !?TokenIndex {
    switch (p.tok_ids[p.tok_i]) {
        .identifier => {},
        .extended_identifier => {
            const slice = p.tokSlice(p.tok_i);
            var it = std.unicode.Utf8View.initUnchecked(slice).iterator();
            var loc = p.pp.tokens.items(.loc)[p.tok_i];

            if (mem.indexOfScalar(u8, slice, '$')) |i| {
                loc.byte_offset += @intCast(u32, i);
                try p.pp.comp.diag.add(.{
                    .tag = .dollar_in_identifier_extension,
                    .loc = loc,
                }, &.{});
                loc = p.pp.tokens.items(.loc)[p.tok_i];
            }

            while (it.nextCodepoint()) |c| {
                if (try checkIdentifierCodepoint(p.pp.comp, c, loc)) break;
                loc.byte_offset += std.unicode.utf8CodepointSequenceLength(c) catch unreachable;
            }
        },
        else => return null,
    }
    p.tok_i += 1;

    // Handle illegal '$' characters in identifiers
    if (!p.pp.comp.langopts.dollars_in_identifiers) {
        if (p.tok_ids[p.tok_i] == .invalid and p.tokSlice(p.tok_i)[0] == '$') {
            try p.err(.dollars_in_identifiers);
            p.tok_i += 1;
            return error.ParsingFailed;
        }
    }

    return p.tok_i - 1;
}

fn expectIdentifier(p: *Parser) Error!TokenIndex {
    const actual = p.tok_ids[p.tok_i];
    if (actual != .identifier and actual != .extended_identifier) {
        return p.errExpectedToken(.identifier, actual);
    }

    return (try p.eatIdentifier()) orelse unreachable;
}

fn eatToken(p: *Parser, id: Token.Id) ?TokenIndex {
    assert(id != .identifier and id != .extended_identifier); // use eatIdentifier
    if (p.tok_ids[p.tok_i] == id) {
        defer p.tok_i += 1;
        return p.tok_i;
    } else return null;
}

fn expectToken(p: *Parser, expected: Token.Id) Error!TokenIndex {
    assert(expected != .identifier and expected != .extended_identifier); // use expectIdentifier
    const actual = p.tok_ids[p.tok_i];
    if (actual != expected) return p.errExpectedToken(expected, actual);
    defer p.tok_i += 1;
    return p.tok_i;
}

fn tokSlice(p: *Parser, tok: TokenIndex) []const u8 {
    if (p.tok_ids[tok].lexeme()) |some| return some;
    const loc = p.pp.tokens.items(.loc)[tok];
    var tmp_tokenizer = Tokenizer{
        .buf = p.pp.comp.getSource(loc.id).buf,
        .comp = p.pp.comp,
        .index = loc.byte_offset,
        .source = .generated,
    };
    const res = tmp_tokenizer.next();
    return tmp_tokenizer.buf[res.start..res.end];
}

fn expectClosing(p: *Parser, opening: TokenIndex, id: Token.Id) Error!void {
    _ = p.expectToken(id) catch |e| {
        if (e == error.ParsingFailed) {
            try p.errTok(switch (id) {
                .r_paren => .to_match_paren,
                .r_brace => .to_match_brace,
                .r_bracket => .to_match_brace,
                else => unreachable,
            }, opening);
        }
        return e;
    };
}

fn errOverflow(p: *Parser, op_tok: TokenIndex, res: Result) !void {
    if (res.ty.isUnsignedInt(p.pp.comp)) {
        try p.errExtra(.overflow_unsigned, op_tok, .{ .unsigned = res.val.data.int });
    } else {
        try p.errExtra(.overflow_signed, op_tok, .{ .signed = res.val.signExtend(res.ty, p.pp.comp) });
    }
}

fn errExpectedToken(p: *Parser, expected: Token.Id, actual: Token.Id) Error {
    switch (actual) {
        .invalid => try p.errExtra(.expected_invalid, p.tok_i, .{ .tok_id_expected = expected }),
        .eof => try p.errExtra(.expected_eof, p.tok_i, .{ .tok_id_expected = expected }),
        else => try p.errExtra(.expected_token, p.tok_i, .{ .tok_id = .{
            .expected = expected,
            .actual = actual,
        } }),
    }
    return error.ParsingFailed;
}

pub fn errStr(p: *Parser, tag: Diagnostics.Tag, tok_i: TokenIndex, str: []const u8) Compilation.Error!void {
    @setCold(true);
    return p.errExtra(tag, tok_i, .{ .str = str });
}

pub fn errExtra(p: *Parser, tag: Diagnostics.Tag, tok_i: TokenIndex, extra: Diagnostics.Message.Extra) Compilation.Error!void {
    @setCold(true);
    const tok = p.pp.tokens.get(tok_i);
    var loc = tok.loc;
    if (tok_i != 0 and tok.id == .eof) {
        // if the token is EOF, point at the end of the previous token instead
        const prev = p.pp.tokens.get(tok_i - 1);
        loc = prev.loc;
        loc.byte_offset += @intCast(u32, p.tokSlice(tok_i - 1).len);
    }
    try p.pp.comp.diag.add(.{
        .tag = tag,
        .loc = loc,
        .extra = extra,
    }, tok.expansionSlice());
}

pub fn errTok(p: *Parser, tag: Diagnostics.Tag, tok_i: TokenIndex) Compilation.Error!void {
    @setCold(true);
    return p.errExtra(tag, tok_i, .{ .none = {} });
}

pub fn err(p: *Parser, tag: Diagnostics.Tag) Compilation.Error!void {
    @setCold(true);
    return p.errTok(tag, p.tok_i);
}

pub fn todo(p: *Parser, msg: []const u8) Error {
    try p.errStr(.todo, p.tok_i, msg);
    return error.ParsingFailed;
}

pub fn ignoredAttrStr(p: *Parser, attr: Attribute.Tag, context: Attribute.ParseContext) ![]const u8 {
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    try p.strings.writer().print("Attribute '{s}' ignored in {s} context", .{ @tagName(attr), @tagName(context) });
    return try p.pp.comp.diag.arena.allocator().dupe(u8, p.strings.items[strings_top..]);
}

pub fn typeStr(p: *Parser, ty: Type) ![]const u8 {
    if (Type.Builder.fromType(ty).str()) |str| return str;
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    try ty.print(p.strings.writer());
    return try p.pp.comp.diag.arena.allocator().dupe(u8, p.strings.items[strings_top..]);
}

pub fn typePairStr(p: *Parser, a: Type, b: Type) ![]const u8 {
    return p.typePairStrExtra(a, " and ", b);
}

pub fn typePairStrExtra(p: *Parser, a: Type, msg: []const u8, b: Type) ![]const u8 {
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    try p.strings.append('\'');
    try a.print(p.strings.writer());
    try p.strings.append('\'');
    try p.strings.appendSlice(msg);
    try p.strings.append('\'');
    try b.print(p.strings.writer());
    try p.strings.append('\'');
    return try p.pp.comp.diag.arena.allocator().dupe(u8, p.strings.items[strings_top..]);
}

fn checkDeprecatedUnavailable(p: *Parser, ty: Type, usage_tok: TokenIndex, decl_tok: TokenIndex) !void {
    if (ty.getAttribute(.unavailable)) |unavailable| {
        try p.errDeprecated(.unavailable, usage_tok, unavailable.msg);
        try p.errStr(.unavailable_note, unavailable.__name_tok, p.tokSlice(decl_tok));
        return error.ParsingFailed;
    } else if (ty.getAttribute(.deprecated)) |deprecated| {
        try p.errDeprecated(.deprecated_declarations, usage_tok, deprecated.msg);
        try p.errStr(.deprecated_note, deprecated.__name_tok, p.tokSlice(decl_tok));
    }
}

fn errDeprecated(p: *Parser, tag: Diagnostics.Tag, tok_i: TokenIndex, msg: ?[]const u8) Compilation.Error!void {
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    const w = p.strings.writer();
    try w.print("'{s}' is ", .{p.tokSlice(tok_i)});
    const reason: []const u8 = switch (tag) {
        .unavailable => "unavailable",
        .deprecated_declarations => "deprecated",
        else => unreachable,
    };
    try w.writeAll(reason);
    if (msg) |m| {
        try w.print(": {s}", .{m});
    }
    const str = try p.pp.comp.diag.arena.allocator().dupe(u8, p.strings.items[strings_top..]);
    return p.errStr(tag, tok_i, str);
}

fn addNode(p: *Parser, node: Tree.Node) Allocator.Error!NodeIndex {
    if (p.in_macro) return .none;
    const res = p.nodes.len;
    try p.nodes.append(p.pp.comp.gpa, node);
    return @intToEnum(NodeIndex, res);
}

fn addList(p: *Parser, nodes: []const NodeIndex) Allocator.Error!Tree.Node.Range {
    if (p.in_macro) return Tree.Node.Range{ .start = 0, .end = 0 };
    const start = @intCast(u32, p.data.items.len);
    try p.data.appendSlice(nodes);
    const end = @intCast(u32, p.data.items.len);
    return Tree.Node.Range{ .start = start, .end = end };
}

fn findTypedef(p: *Parser, name_tok: TokenIndex, no_type_yet: bool) !?Scope.Symbol {
    const name = p.tokSlice(name_tok);
    var i = p.scopes.items.len;
    while (i > 0) {
        i -= 1;
        switch (p.scopes.items[i]) {
            .typedef => |t| if (mem.eql(u8, t.name, name)) return t,
            .@"struct" => |s| if (mem.eql(u8, s.name, name)) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_struct, name_tok, name);
                return s;
            },
            .@"union" => |u| if (mem.eql(u8, u.name, name)) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_union, name_tok, name);
                return u;
            },
            .@"enum" => |e| if (mem.eql(u8, e.name, name)) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_enum, name_tok, name);
                return e;
            },
            .def, .decl => |d| if (mem.eql(u8, d.name, name)) return null,
            else => {},
        }
    }
    return null;
}

fn findSymbol(p: *Parser, name_tok: TokenIndex, ref_kind: enum { reference, definition }) ?Scope {
    const name = p.tokSlice(name_tok);
    var i = p.scopes.items.len;
    while (i > 0) {
        i -= 1;
        const sym = p.scopes.items[i];
        switch (sym) {
            .def, .decl, .param => |s| if (mem.eql(u8, s.name, name)) return sym,
            .enumeration => |e| if (mem.eql(u8, e.name, name)) return sym,
            .block => if (ref_kind == .definition) return null,
            else => {},
        }
    }
    return null;
}

fn findTag(p: *Parser, kind: Token.Id, name_tok: TokenIndex, ref_kind: enum { reference, definition }) !?Scope.Symbol {
    const name = p.tokSlice(name_tok);
    var i = p.scopes.items.len;
    var saw_block = false;
    while (i > 0) {
        i -= 1;
        const sym = p.scopes.items[i];
        switch (sym) {
            .@"enum" => |e| if (mem.eql(u8, e.name, name)) {
                if (kind == .keyword_enum) return e;
                if (saw_block) return null;
                try p.errStr(.wrong_tag, name_tok, name);
                try p.errTok(.previous_definition, e.name_tok);
                return null;
            },
            .@"struct" => |s| if (mem.eql(u8, s.name, name)) {
                if (kind == .keyword_struct) return s;
                if (saw_block) return null;
                try p.errStr(.wrong_tag, name_tok, name);
                try p.errTok(.previous_definition, s.name_tok);
                return null;
            },
            .@"union" => |u| if (mem.eql(u8, u.name, name)) {
                if (kind == .keyword_union) return u;
                if (saw_block) return null;
                try p.errStr(.wrong_tag, name_tok, name);
                try p.errTok(.previous_definition, u.name_tok);
                return null;
            },
            .block => if (ref_kind == .reference) {
                saw_block = true;
            } else return null,
            else => {},
        }
    }
    return null;
}

fn inLoop(p: *Parser) bool {
    var i = p.scopes.items.len;
    while (i > 0) {
        i -= 1;
        switch (p.scopes.items[i]) {
            .loop => return true,
            else => {},
        }
    }
    return false;
}

fn inLoopOrSwitch(p: *Parser) bool {
    var i = p.scopes.items.len;
    while (i > 0) {
        i -= 1;
        switch (p.scopes.items[i]) {
            .loop, .@"switch" => return true,
            else => {},
        }
    }
    return false;
}

fn findLabel(p: *Parser, name: []const u8) ?TokenIndex {
    for (p.labels.items) |item| {
        switch (item) {
            .label => |l| if (mem.eql(u8, p.tokSlice(l), name)) return l,
            .unresolved_goto => {},
        }
    }
    return null;
}

fn findSwitch(p: *Parser) ?*Scope.Switch {
    var i = p.scopes.items.len;
    while (i > 0) {
        i -= 1;
        switch (p.scopes.items[i]) {
            .@"switch" => |s| return s,
            else => {},
        }
    }
    return null;
}

fn nodeIs(p: *Parser, node: NodeIndex, tag: Tree.Tag) bool {
    return p.getNode(node, tag) != null;
}

fn getNode(p: *Parser, node: NodeIndex, tag: Tree.Tag) ?NodeIndex {
    var cur = node;
    const tags = p.nodes.items(.tag);
    const data = p.nodes.items(.data);
    while (true) {
        const cur_tag = tags[@enumToInt(cur)];
        if (cur_tag == .paren_expr) {
            cur = data[@enumToInt(cur)].un;
        } else if (cur_tag == tag) {
            return cur;
        } else {
            return null;
        }
    }
}

fn pragma(p: *Parser) Compilation.Error!bool {
    var found_pragma = false;
    while (p.eatToken(.keyword_pragma)) |_| {
        found_pragma = true;

        const name_tok = p.tok_i;
        const name = p.tokSlice(name_tok);

        const end_idx = mem.indexOfScalarPos(Token.Id, p.tok_ids, p.tok_i, .nl).?;
        const pragma_len = @intCast(TokenIndex, end_idx) - p.tok_i;
        defer p.tok_i += pragma_len + 1; // skip past .nl as well
        if (p.pp.comp.getPragma(name)) |prag| {
            try prag.parserCB(p, p.tok_i);
        }
    }
    return found_pragma;
}

/// root : (decl | assembly ';' | staticAssert)*
pub fn parse(pp: *Preprocessor) Compilation.Error!Tree {
    pp.comp.pragmaEvent(.before_parse);

    var arena = std.heap.ArenaAllocator.init(pp.comp.gpa);
    errdefer arena.deinit();
    var p = Parser{
        .pp = pp,
        .arena = arena.allocator(),
        .tok_ids = pp.tokens.items(.id),
        .strings = std.ArrayList(u8).init(pp.comp.gpa),
        .value_map = Tree.ValueMap.init(pp.comp.gpa),
        .data = NodeList.init(pp.comp.gpa),
        .labels = std.ArrayList(Label).init(pp.comp.gpa),
        .scopes = std.ArrayList(Scope).init(pp.comp.gpa),
        .list_buf = NodeList.init(pp.comp.gpa),
        .decl_buf = NodeList.init(pp.comp.gpa),
        .param_buf = std.ArrayList(Type.Func.Param).init(pp.comp.gpa),
        .enum_buf = std.ArrayList(Type.Enum.Field).init(pp.comp.gpa),
        .record_buf = std.ArrayList(Type.Record.Field).init(pp.comp.gpa),
    };
    errdefer {
        p.nodes.deinit(pp.comp.gpa);
        p.strings.deinit();
        p.value_map.deinit();
    }
    defer {
        p.data.deinit();
        p.labels.deinit();
        p.scopes.deinit();
        p.list_buf.deinit();
        p.decl_buf.deinit();
        p.param_buf.deinit();
        p.enum_buf.deinit();
        p.record_buf.deinit();
        p.attr_buf.deinit(pp.comp.gpa);
    }

    // NodeIndex 0 must be invalid
    _ = try p.addNode(.{ .tag = .invalid, .ty = undefined, .data = undefined });

    {
        const ty = &pp.comp.types.va_list;
        const sym = Scope.Symbol{ .name = "__builtin_va_list", .ty = ty.*, .name_tok = 0 };
        try p.scopes.append(.{ .typedef = sym });

        if (ty.isArray()) ty.decayArray();
    }

    while (p.eatToken(.eof) == null) {
        if (try p.pragma()) continue;
        if (try p.parseOrNextDecl(staticAssert)) continue;
        if (try p.parseOrNextDecl(decl)) continue;
        if (p.eatToken(.keyword_extension)) |_| {
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            if (try p.parseOrNextDecl(decl)) continue;
            switch (p.tok_ids[p.tok_i]) {
                .semicolon => p.tok_i += 1,
                .keyword_static_assert,
                .keyword_pragma,
                .keyword_extension,
                .keyword_asm,
                .keyword_asm1,
                .keyword_asm2,
                => {},
                else => try p.err(.expected_external_decl),
            }
            continue;
        }
        if (p.assembly(.global) catch |er| switch (er) {
            error.ParsingFailed => {
                p.nextExternDecl();
                continue;
            },
            else => |e| return e,
        }) |_| continue;
        if (p.eatToken(.semicolon)) |tok| {
            try p.errTok(.extra_semi, tok);
            continue;
        }
        try p.err(.expected_external_decl);
        p.tok_i += 1;
    }
    const root_decls = p.decl_buf.toOwnedSlice();
    if (root_decls.len == 0) {
        try p.errTok(.empty_translation_unit, p.tok_i - 1);
    }
    pp.comp.pragmaEvent(.after_parse);
    return Tree{
        .comp = pp.comp,
        .tokens = pp.tokens.slice(),
        .arena = arena,
        .generated = pp.comp.generated_buf.items,
        .nodes = p.nodes.toOwnedSlice(),
        .data = p.data.toOwnedSlice(),
        .root_decls = root_decls,
        .strings = p.strings.toOwnedSlice(),
        .value_map = p.value_map,
    };
}

fn skipToPragmaSentinel(p: *Parser) void {
    while (true) : (p.tok_i += 1) {
        if (p.tok_ids[p.tok_i] == .nl) return;
        if (p.tok_ids[p.tok_i] == .eof) {
            p.tok_i -= 1;
            return;
        }
    }
}

fn parseOrNextDecl(p: *Parser, comptime func: fn (*Parser) Error!bool) Compilation.Error!bool {
    return func(p) catch |er| switch (er) {
        error.ParsingFailed => {
            p.nextExternDecl();
            return true;
        },
        else => |e| return e,
    };
}

fn nextExternDecl(p: *Parser) void {
    var parens: u32 = 0;
    while (true) : (p.tok_i += 1) {
        switch (p.tok_ids[p.tok_i]) {
            .l_paren, .l_brace, .l_bracket => parens += 1,
            .r_paren, .r_brace, .r_bracket => if (parens != 0) {
                parens -= 1;
            },
            .keyword_typedef,
            .keyword_extern,
            .keyword_static,
            .keyword_auto,
            .keyword_register,
            .keyword_thread_local,
            .keyword_inline,
            .keyword_inline1,
            .keyword_inline2,
            .keyword_noreturn,
            .keyword_void,
            .keyword_bool,
            .keyword_char,
            .keyword_short,
            .keyword_int,
            .keyword_long,
            .keyword_signed,
            .keyword_unsigned,
            .keyword_float,
            .keyword_double,
            .keyword_complex,
            .keyword_atomic,
            .keyword_enum,
            .keyword_struct,
            .keyword_union,
            .keyword_alignas,
            .identifier,
            .extended_identifier,
            .keyword_typeof,
            .keyword_typeof1,
            .keyword_typeof2,
            .keyword_extension,
            => if (parens == 0) return,
            .keyword_pragma => p.skipToPragmaSentinel(),
            .eof => return,
            .semicolon => if (parens == 0) {
                p.tok_i += 1;
                return;
            },
            else => {},
        }
    }
}

fn skipTo(p: *Parser, id: Token.Id) void {
    var parens: u32 = 0;
    while (true) : (p.tok_i += 1) {
        if (p.tok_ids[p.tok_i] == id and parens == 0) {
            p.tok_i += 1;
            return;
        }
        switch (p.tok_ids[p.tok_i]) {
            .l_paren, .l_brace, .l_bracket => parens += 1,
            .r_paren, .r_brace, .r_bracket => if (parens != 0) {
                parens -= 1;
            },
            .keyword_pragma => p.skipToPragmaSentinel(),
            .eof => return,
            else => {},
        }
    }
}

pub fn withAttributes(p: *Parser, ty: Type, attr_buf_start: usize) !Type {
    const attrs = p.attr_buf.items(.attr)[attr_buf_start..];
    return ty.withAttributes(p.arena, attrs);
}

// ====== declarations ======

/// decl
///  : declSpec (initDeclarator ( ',' initDeclarator)*)? ';'
///  | declSpec declarator decl* compoundStmt
fn decl(p: *Parser) Error!bool {
    _ = try p.pragma();
    const first_tok = p.tok_i;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;

    try p.attributeSpecifier();

    var decl_spec = if (try p.declSpec(false)) |some| some else blk: {
        if (p.func.ty != null) {
            p.tok_i = first_tok;
            return false;
        }
        switch (p.tok_ids[first_tok]) {
            .asterisk, .l_paren, .identifier, .extended_identifier => {},
            else => if (p.tok_i != first_tok) {
                try p.err(.expected_ident_or_l_paren);
                return error.ParsingFailed;
            } else return false,
        }
        var spec: Type.Builder = .{};
        break :blk DeclSpec{ .ty = try spec.finish(p, p.attr_buf.len) };
    };
    if (decl_spec.@"noreturn") |tok| {
        const attr = Attribute{ .tag = .noreturn, .args = .{ .noreturn = {} } };
        try p.attr_buf.append(p.pp.comp.gpa, .{ .attr = attr, .tok = tok });
    }
    try decl_spec.warnIgnoredAttrs(p, attr_buf_top);
    var init_d = (try p.initDeclarator(&decl_spec)) orelse {
        _ = try p.expectToken(.semicolon);
        if (decl_spec.ty.is(.@"enum") or
            (decl_spec.ty.isRecord() and !decl_spec.ty.isAnonymousRecord() and
            !decl_spec.ty.isTypeof())) // we follow GCC and clang's behavior here
            return true;

        try p.errTok(.missing_declaration, first_tok);
        return true;
    };

    init_d.d.ty = try p.withAttributes(init_d.d.ty, attr_buf_top);
    try p.validateAlignas(init_d.d.ty, null);

    // Check for function definition.
    if (init_d.d.func_declarator != null and init_d.initializer == .none and init_d.d.ty.isFunc()) fn_def: {
        switch (p.tok_ids[p.tok_i]) {
            .comma, .semicolon => break :fn_def,
            .l_brace => {},
            else => if (init_d.d.old_style_func == null) {
                try p.err(.expected_fn_body);
                return true;
            },
        }
        if (p.func.ty != null) try p.err(.func_not_in_root);

        if (p.findSymbol(init_d.d.name, .definition)) |sym| {
            if (sym == .def) {
                try p.errStr(.redefinition, init_d.d.name, p.tokSlice(init_d.d.name));
                try p.errTok(.previous_definition, sym.def.name_tok);
            }
        }
        try p.scopes.append(.{ .def = .{
            .name = p.tokSlice(init_d.d.name),
            .ty = init_d.d.ty,
            .name_tok = init_d.d.name,
        } });

        const func = p.func;
        p.func = .{
            .ty = init_d.d.ty,
            .name = init_d.d.name,
        };
        defer p.func = func;

        const scopes_top = p.scopes.items.len;
        defer p.scopes.items.len = scopes_top;

        // findSymbol stops the search at .block
        try p.scopes.append(.block);

        // Collect old style parameter declarations.
        if (init_d.d.old_style_func != null) {
            const attrs = init_d.d.ty.getAttributes();
            var base_ty = if (init_d.d.ty.specifier == .attributed) init_d.d.ty.elemType() else init_d.d.ty;
            base_ty.specifier = .func;
            init_d.d.ty = try base_ty.withAttributes(p.arena, attrs);

            const param_buf_top = p.param_buf.items.len;
            defer p.param_buf.items.len = param_buf_top;

            param_loop: while (true) {
                const param_decl_spec = (try p.declSpec(true)) orelse break;
                if (p.eatToken(.semicolon)) |semi| {
                    try p.errTok(.missing_declaration, semi);
                    continue :param_loop;
                }

                while (true) {
                    var d = (try p.declarator(param_decl_spec.ty, .normal)) orelse {
                        try p.errTok(.missing_declaration, first_tok);
                        _ = try p.expectToken(.semicolon);
                        continue :param_loop;
                    };
                    if (d.ty.hasIncompleteSize() and !d.ty.is(.void)) try p.errStr(.parameter_incomplete_ty, d.name, try p.typeStr(d.ty));
                    if (d.ty.isFunc()) {
                        // Params declared as functions are converted to function pointers.
                        const elem_ty = try p.arena.create(Type);
                        elem_ty.* = d.ty;
                        d.ty = Type{
                            .specifier = .pointer,
                            .data = .{ .sub_type = elem_ty },
                        };
                    } else if (d.ty.isArray()) {
                        // params declared as arrays are converted to pointers
                        d.ty.decayArray();
                    } else if (d.ty.is(.void)) {
                        try p.errTok(.invalid_void_param, d.name);
                    }

                    // find and correct parameter types
                    // TODO check for missing declarations and redefinitions
                    const name_str = p.tokSlice(d.name);
                    for (init_d.d.ty.params()) |*param| {
                        if (mem.eql(u8, param.name, name_str)) {
                            param.ty = d.ty;
                            break;
                        }
                    } else {
                        try p.errStr(.parameter_missing, d.name, name_str);
                    }

                    try p.scopes.append(.{ .param = .{
                        .name = name_str,
                        .name_tok = d.name,
                        .ty = d.ty,
                    } });
                    if (p.eatToken(.comma) == null) break;
                }
                _ = try p.expectToken(.semicolon);
            }
        } else {
            for (init_d.d.ty.params()) |param| {
                if (param.ty.hasUnboundVLA()) try p.errTok(.unbound_vla, param.name_tok);
                if (param.ty.hasIncompleteSize() and !param.ty.is(.void)) try p.errStr(.parameter_incomplete_ty, param.name_tok, try p.typeStr(param.ty));

                if (param.name.len == 0) {
                    try p.errTok(.omitting_parameter_name, param.name_tok);
                    continue;
                }

                try p.scopes.append(.{
                    .param = .{
                        .name = param.name,
                        .ty = param.ty,
                        .name_tok = param.name_tok,
                    },
                });
            }
        }

        const body = (try p.compoundStmt(true, null)) orelse {
            assert(init_d.d.old_style_func != null);
            try p.err(.expected_fn_body);
            return true;
        };
        const node = try p.addNode(.{
            .ty = init_d.d.ty,
            .tag = try decl_spec.validateFnDef(p),
            .data = .{ .decl = .{ .name = init_d.d.name, .node = body } },
        });
        try p.decl_buf.append(node);

        // check gotos
        if (func.ty == null) {
            for (p.labels.items) |item| {
                if (item == .unresolved_goto)
                    try p.errStr(.undeclared_label, item.unresolved_goto, p.tokSlice(item.unresolved_goto));
            }
            if (p.computed_goto_tok) |goto_tok| {
                if (!p.contains_address_of_label) try p.errTok(.invalid_computed_goto, goto_tok);
            }
            p.labels.items.len = 0;
            p.label_count = 0;
            p.contains_address_of_label = false;
            p.computed_goto_tok = null;
        }
        return true;
    }

    // Declare all variable/typedef declarators.
    while (true) {
        if (init_d.d.old_style_func) |tok_i| try p.errTok(.invalid_old_style_params, tok_i);
        const tag = try decl_spec.validate(p, &init_d.d.ty, init_d.initializer != .none);
        //        const attrs = p.attr_buf.items(.attr)[attr_buf_top..];
        //        init_d.d.ty = try init_d.d.ty.withAttributes(p.arena, attrs);

        const node = try p.addNode(.{ .ty = init_d.d.ty, .tag = tag, .data = .{
            .decl = .{ .name = init_d.d.name, .node = init_d.initializer },
        } });
        try p.decl_buf.append(node);

        const sym = Scope.Symbol{
            .name = p.tokSlice(init_d.d.name),
            .ty = init_d.d.ty,
            .name_tok = init_d.d.name,
        };
        if (decl_spec.storage_class == .typedef) {
            try p.scopes.append(.{ .typedef = sym });
        } else if (init_d.initializer != .none) {
            try p.scopes.append(.{ .def = sym });
        } else {
            try p.scopes.append(.{ .decl = sym });
        }

        if (p.eatToken(.comma) == null) break;

        init_d = (try p.initDeclarator(&decl_spec)) orelse {
            try p.err(.expected_ident_or_l_paren);
            continue;
        };
    }

    _ = try p.expectToken(.semicolon);
    return true;
}

/// staticAssert : keyword_static_assert '(' constExpr ',' STRING_LITERAL ')' ';'
fn staticAssert(p: *Parser) Error!bool {
    const static_assert = p.eatToken(.keyword_static_assert) orelse return false;
    const l_paren = try p.expectToken(.l_paren);
    const res_token = p.tok_i;
    const res = try p.constExpr();
    const str = if (p.eatToken(.comma) != null)
        switch (p.tok_ids[p.tok_i]) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => try p.stringLiteral(),
            else => {
                try p.err(.expected_str_literal);
                return error.ParsingFailed;
            },
        }
    else
        Result{};
    try p.expectClosing(l_paren, .r_paren);
    _ = try p.expectToken(.semicolon);
    if (str.node == .none) try p.errTok(.static_assert_missing_message, static_assert);

    if (res.val.tag == .unavailable) {
        // an unavailable sizeof expression is already a compile error, so we don't emit
        // another error for an invalid _Static_assert condition. This matches the behavior
        // of gcc/clang
        if (!p.nodeIs(res.node, .sizeof_expr)) try p.errTok(.static_assert_not_constant, res_token);
    } else if (!res.val.getBool()) {
        if (str.node != .none) {
            var buf = std.ArrayList(u8).init(p.pp.comp.gpa);
            defer buf.deinit();

            const data = str.val.data.bytes;
            try buf.ensureUnusedCapacity(data.len);
            try Tree.dumpStr(
                data,
                p.nodes.items(.tag)[@enumToInt(str.node)],
                buf.writer(),
            );
            try p.errStr(
                .static_assert_failure_message,
                static_assert,
                try p.pp.comp.diag.arena.allocator().dupe(u8, buf.items),
            );
        } else try p.errTok(.static_assert_failure, static_assert);
    }
    const node = try p.addNode(.{
        .tag = .static_assert,
        .data = .{ .bin = .{
            .lhs = res.node,
            .rhs = str.node,
        } },
    });
    try p.decl_buf.append(node);
    return true;
}

pub const DeclSpec = struct {
    storage_class: union(enum) {
        auto: TokenIndex,
        @"extern": TokenIndex,
        register: TokenIndex,
        static: TokenIndex,
        typedef: TokenIndex,
        none,
    } = .none,
    thread_local: ?TokenIndex = null,
    @"inline": ?TokenIndex = null,
    @"noreturn": ?TokenIndex = null,
    ty: Type,

    fn validateParam(d: DeclSpec, p: *Parser, ty: *Type) Error!void {
        switch (d.storage_class) {
            .none => {},
            .register => ty.qual.register = true,
            .auto, .@"extern", .static, .typedef => |tok_i| try p.errTok(.invalid_storage_on_param, tok_i),
        }
        if (d.thread_local) |tok_i| try p.errTok(.threadlocal_non_var, tok_i);
        if (d.@"inline") |tok_i| try p.errStr(.func_spec_non_func, tok_i, "inline");
        if (d.@"noreturn") |tok_i| try p.errStr(.func_spec_non_func, tok_i, "_Noreturn");
    }

    fn validateFnDef(d: DeclSpec, p: *Parser) Error!Tree.Tag {
        switch (d.storage_class) {
            .none, .@"extern", .static => {},
            .auto, .register, .typedef => |tok_i| try p.errTok(.illegal_storage_on_func, tok_i),
        }
        if (d.thread_local) |tok_i| try p.errTok(.threadlocal_non_var, tok_i);

        const is_static = d.storage_class == .static;
        const is_inline = d.@"inline" != null;
        if (is_static) {
            if (is_inline) return .inline_static_fn_def;
            return .static_fn_def;
        } else {
            if (is_inline) return .inline_fn_def;
            return .fn_def;
        }
    }

    fn validate(d: DeclSpec, p: *Parser, ty: *Type, has_init: bool) Error!Tree.Tag {
        const is_static = d.storage_class == .static;
        if (ty.isFunc() and d.storage_class != .typedef) {
            switch (d.storage_class) {
                .none, .@"extern" => {},
                .static => |tok_i| if (p.func.ty != null) try p.errTok(.static_func_not_global, tok_i),
                .typedef => unreachable,
                .auto, .register => |tok_i| try p.errTok(.illegal_storage_on_func, tok_i),
            }
            if (d.thread_local) |tok_i| try p.errTok(.threadlocal_non_var, tok_i);

            const is_inline = d.@"inline" != null;
            if (is_static) {
                if (is_inline) return .inline_static_fn_proto;
                return .static_fn_proto;
            } else {
                if (is_inline) return .inline_fn_proto;
                return .fn_proto;
            }
        } else {
            if (d.@"inline") |tok_i| try p.errStr(.func_spec_non_func, tok_i, "inline");
            // TODO move to attribute validation
            if (d.@"noreturn") |tok_i| try p.errStr(.func_spec_non_func, tok_i, "_Noreturn");
            switch (d.storage_class) {
                .auto, .register => if (p.func.ty == null) try p.err(.illegal_storage_on_global),
                .typedef => return .typedef,
                else => {},
            }
            ty.qual.register = d.storage_class == .register;

            const is_extern = d.storage_class == .@"extern" and !has_init;
            if (d.thread_local != null) {
                if (is_static) return .threadlocal_static_var;
                if (is_extern) return .threadlocal_extern_var;
                return .threadlocal_var;
            } else {
                if (is_static) return .static_var;
                if (is_extern) return .extern_var;
                return .@"var";
            }
        }
    }

    fn warnIgnoredAttrs(d: DeclSpec, p: *Parser, attr_buf_start: usize) !void {
        if (!d.ty.isEnumOrRecord()) return;

        var i = attr_buf_start;
        while (i < p.attr_buf.len) : (i += 1) {
            const ignored_attr = p.attr_buf.get(i);
            try p.errExtra(.ignored_record_attr, ignored_attr.tok, .{
                .ignored_record_attr = .{ .tag = ignored_attr.attr.tag, .specifier = switch (d.ty.specifier) {
                    .@"enum" => .@"enum",
                    .@"struct" => .@"struct",
                    .@"union" => .@"union",
                    else => continue,
                } },
            });
        }
    }
};

/// typeof
///   : keyword_typeof '(' typeName ')'
///   | keyword_typeof '(' expr ')'
fn typeof(p: *Parser) Error!?Type {
    switch (p.tok_ids[p.tok_i]) {
        .keyword_typeof, .keyword_typeof1, .keyword_typeof2 => p.tok_i += 1,
        else => return null,
    }
    const l_paren = try p.expectToken(.l_paren);
    if (try p.typeName()) |ty| {
        try p.expectClosing(l_paren, .r_paren);
        const typeof_ty = try p.arena.create(Type);
        typeof_ty.* = .{
            .data = ty.data,
            .qual = ty.qual.inheritFromTypeof(),
            .specifier = ty.specifier,
        };

        return Type{
            .data = .{ .sub_type = typeof_ty },
            .specifier = .typeof_type,
        };
    }
    const typeof_expr = try p.parseNoEval(expr);
    try typeof_expr.expect(p);
    try p.expectClosing(l_paren, .r_paren);

    const inner = try p.arena.create(Type.Expr);
    inner.* = .{
        .node = typeof_expr.node,
        .ty = .{
            .data = typeof_expr.ty.data,
            .qual = typeof_expr.ty.qual.inheritFromTypeof(),
            .specifier = typeof_expr.ty.specifier,
        },
    };

    return Type{
        .data = .{ .expr = inner },
        .specifier = .typeof_expr,
    };
}

/// declSpec: (storageClassSpec | typeSpec | typeQual | funcSpec | alignSpec)+
/// storageClassSpec:
///  : keyword_typedef
///  | keyword_extern
///  | keyword_static
///  | keyword_threadlocal
///  | keyword_auto
///  | keyword_register
/// funcSpec : keyword_inline | keyword_noreturn
fn declSpec(p: *Parser, is_param: bool) Error!?DeclSpec {
    var d: DeclSpec = .{ .ty = .{ .specifier = undefined } };
    var spec: Type.Builder = .{};
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;

    const start = p.tok_i;
    while (true) {
        if (try p.typeSpec(&spec)) continue;
        const id = p.tok_ids[p.tok_i];
        switch (id) {
            .keyword_typedef,
            .keyword_extern,
            .keyword_static,
            .keyword_auto,
            .keyword_register,
            => {
                if (d.storage_class != .none) {
                    try p.errStr(.multiple_storage_class, p.tok_i, @tagName(d.storage_class));
                    return error.ParsingFailed;
                }
                if (d.thread_local != null) {
                    switch (id) {
                        .keyword_typedef,
                        .keyword_auto,
                        .keyword_register,
                        => try p.errStr(.cannot_combine_spec, p.tok_i, id.lexeme().?),
                        else => {},
                    }
                }
                switch (id) {
                    .keyword_typedef => d.storage_class = .{ .typedef = p.tok_i },
                    .keyword_extern => d.storage_class = .{ .@"extern" = p.tok_i },
                    .keyword_static => d.storage_class = .{ .static = p.tok_i },
                    .keyword_auto => d.storage_class = .{ .auto = p.tok_i },
                    .keyword_register => d.storage_class = .{ .register = p.tok_i },
                    else => unreachable,
                }
            },
            .keyword_thread_local => {
                if (d.thread_local != null) {
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "_Thread_local");
                }
                switch (d.storage_class) {
                    .@"extern", .none, .static => {},
                    else => try p.errStr(.cannot_combine_spec, p.tok_i, @tagName(d.storage_class)),
                }
                d.thread_local = p.tok_i;
            },
            .keyword_inline, .keyword_inline1, .keyword_inline2 => {
                if (d.@"inline" != null) {
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "inline");
                }
                d.@"inline" = p.tok_i;
            },
            .keyword_noreturn => {
                if (d.@"noreturn" != null) {
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "_Noreturn");
                }
                d.@"noreturn" = p.tok_i;
            },
            else => break,
        }
        p.tok_i += 1;
    }

    if (p.tok_i == start) return null;

    d.ty = try spec.finish(p, attr_buf_top);
    if (is_param) try p.validateAlignas(d.ty, .alignas_on_param);
    return d;
}

fn validateAlignas(p: *Parser, ty: Type, tag: ?Diagnostics.Tag) !void {
    const base = ty.canonicalize(.standard);
    const default_align = base.alignof(p.pp.comp);
    for (ty.getAttributes()) |attr| {
        if (attr.tag != .aligned) continue;
        if (attr.args.aligned.alignment) |alignment| {
            if (!alignment.alignas) continue;

            const align_tok = attr.args.aligned.__name_tok;
            if (tag) |t| try p.errTok(t, align_tok);
            if (ty.isFunc()) {
                try p.errTok(.alignas_on_func, align_tok);
            } else if (alignment.requested < default_align) {
                try p.errExtra(.minimum_alignment, align_tok, .{ .unsigned = default_align });
            }
        }
    }
}

const InitDeclarator = struct { d: Declarator, initializer: NodeIndex = .none };

/// attribute
///  : attrIdentifier
///  | attrIdentifier '(' identifier ')'
///  | attrIdentifier '(' identifier (',' expr)+ ')'
///  | attrIdentifier '(' (expr (',' expr)*)? ')'
fn attribute(p: *Parser, kind: Attribute.Kind, namespace: ?[]const u8) Error!?TentativeAttribute {
    const name_tok = p.tok_i;
    switch (p.tok_ids[p.tok_i]) {
        .keyword_const, .keyword_const1, .keyword_const2 => p.tok_i += 1,
        else => _ = try p.expectIdentifier(),
    }
    const name = p.tokSlice(name_tok);

    const attr = Attribute.fromString(kind, namespace, name) orelse {
        const tag: Diagnostics.Tag = if (kind == .declspec) .declspec_attr_not_supported else .unknown_attribute;
        try p.errStr(tag, name_tok, name);
        if (p.eatToken(.l_paren)) |_| p.skipTo(.r_paren);
        return null;
    };

    const required_count = Attribute.requiredArgCount(attr);
    var arguments = Attribute.initArguments(attr, name_tok);
    var arg_idx: u32 = 0;

    switch (p.tok_ids[p.tok_i]) {
        .comma, .r_paren => {}, // will be consumed in attributeList
        .l_paren => blk: {
            p.tok_i += 1;
            if (p.eatToken(.r_paren)) |_| break :blk;

            if (Attribute.wantsIdentEnum(attr)) {
                if (try p.eatIdentifier()) |ident| {
                    if (Attribute.diagnoseIdent(attr, &arguments, p.tokSlice(ident))) |msg| {
                        try p.errExtra(msg.tag, ident, msg.extra);
                        p.skipTo(.r_paren);
                        return error.ParsingFailed;
                    }
                } else {
                    try p.errExtra(.attribute_requires_identifier, name_tok, .{ .str = name });
                    return error.ParsingFailed;
                }
            } else {
                const arg_start = p.tok_i;
                var first_expr = try p.assignExpr();
                try first_expr.expect(p);
                if (p.diagnose(attr, &arguments, arg_idx, first_expr)) |msg| {
                    try p.errExtra(msg.tag, arg_start, msg.extra);
                    p.skipTo(.r_paren);
                    return error.ParsingFailed;
                }
            }
            arg_idx += 1;
            while (p.eatToken(.r_paren) == null) : (arg_idx += 1) {
                _ = try p.expectToken(.comma);

                const arg_start = p.tok_i;
                var arg_expr = try p.assignExpr();
                try arg_expr.expect(p);
                if (p.diagnose(attr, &arguments, arg_idx, arg_expr)) |msg| {
                    try p.errExtra(msg.tag, arg_start, msg.extra);
                    p.skipTo(.r_paren);
                    return error.ParsingFailed;
                }
            }
        },
        else => {},
    }
    if (arg_idx < required_count) {
        try p.errExtra(.attribute_not_enough_args, name_tok, .{ .attr_arg_count = .{ .attribute = attr, .expected = required_count } });
        return error.ParsingFailed;
    }
    return TentativeAttribute{ .attr = .{ .tag = attr, .args = arguments }, .tok = name_tok };
}

fn diagnose(p: *Parser, attr: Attribute.Tag, arguments: *Attribute.Arguments, arg_idx: u32, res: Result) ?Diagnostics.Message {
    if (Attribute.wantsAlignment(attr, arg_idx)) {
        return Attribute.diagnoseAlignment(attr, arguments, arg_idx, res.val, res.ty, p.pp.comp);
    }
    const node = p.nodes.get(@enumToInt(res.node));
    return Attribute.diagnose(attr, arguments, arg_idx, res.val, node);
}

/// attributeList : (attribute (',' attribute)*)?
fn gnuAttributeList(p: *Parser) Error!void {
    if (p.tok_ids[p.tok_i] == .r_paren) return;

    if (try p.attribute(.gnu, null)) |attr| try p.attr_buf.append(p.pp.comp.gpa, attr);
    while (p.tok_ids[p.tok_i] != .r_paren) {
        _ = try p.expectToken(.comma);
        if (try p.attribute(.gnu, null)) |attr| try p.attr_buf.append(p.pp.comp.gpa, attr);
    }
}

fn c2xAttributeList(p: *Parser) Error!void {
    while (p.tok_ids[p.tok_i] != .r_bracket) {
        var namespace_tok = try p.expectIdentifier();
        var namespace: ?[]const u8 = null;
        if (p.eatToken(.colon_colon)) |_| {
            namespace = p.tokSlice(namespace_tok);
        } else {
            p.tok_i -= 1;
        }
        if (try p.attribute(.c2x, namespace)) |attr| try p.attr_buf.append(p.pp.comp.gpa, attr);
        _ = p.eatToken(.comma);
    }
}

fn msvcAttributeList(p: *Parser) Error!void {
    while (p.tok_ids[p.tok_i] != .r_paren) {
        if (try p.attribute(.declspec, null)) |attr| try p.attr_buf.append(p.pp.comp.gpa, attr);
        _ = p.eatToken(.comma);
    }
}

fn c2xAttribute(p: *Parser) !bool {
    if (!p.pp.comp.langopts.standard.atLeast(.c2x)) return false;
    const bracket1 = p.eatToken(.l_bracket) orelse return false;
    const bracket2 = p.eatToken(.l_bracket) orelse {
        p.tok_i -= 1;
        return false;
    };

    try p.c2xAttributeList();

    _ = try p.expectClosing(bracket2, .r_bracket);
    _ = try p.expectClosing(bracket1, .r_bracket);

    return true;
}

fn msvcAttribute(p: *Parser) !bool {
    const declspec_tok = p.eatToken(.keyword_declspec) orelse return false;
    if (!p.pp.comp.langopts.declspec_attrs) {
        try p.errTok(.declspec_not_enabled, declspec_tok);
        return error.ParsingFailed;
    }
    const l_paren = try p.expectToken(.l_paren);
    try p.msvcAttributeList();
    _ = try p.expectClosing(l_paren, .r_paren);

    return false;
}

fn gnuAttribute(p: *Parser) !bool {
    switch (p.tok_ids[p.tok_i]) {
        .keyword_attribute1, .keyword_attribute2 => p.tok_i += 1,
        else => return false,
    }
    const paren1 = try p.expectToken(.l_paren);
    const paren2 = try p.expectToken(.l_paren);

    try p.gnuAttributeList();

    _ = try p.expectClosing(paren2, .r_paren);
    _ = try p.expectClosing(paren1, .r_paren);
    return true;
}

/// alignAs : keyword_alignas '(' (typeName | constExpr ) ')'
fn alignAs(p: *Parser) !bool {
    const align_tok = p.eatToken(.keyword_alignas) orelse return false;
    const l_paren = try p.expectToken(.l_paren);
    if (try p.typeName()) |inner_ty| {
        const alignment = Attribute.Alignment{ .requested = inner_ty.alignof(p.pp.comp), .alignas = true };
        const attr = Attribute{ .tag = .aligned, .args = .{ .aligned = .{ .alignment = alignment, .__name_tok = align_tok } } };
        try p.attr_buf.append(p.pp.comp.gpa, .{ .attr = attr, .tok = align_tok });
    } else {
        const arg_start = p.tok_i;
        const res = try p.constExpr();
        if (!res.val.isZero()) {
            var args = Attribute.initArguments(.aligned, align_tok);
            if (p.diagnose(.aligned, &args, 0, res)) |msg| {
                try p.errExtra(msg.tag, arg_start, msg.extra);
                p.skipTo(.r_paren);
                return error.ParsingFailed;
            }
            args.aligned.alignment.?.node = res.node;
            args.aligned.alignment.?.alignas = true;
            try p.attr_buf.append(p.pp.comp.gpa, .{ .attr = .{ .tag = .aligned, .args = args }, .tok = align_tok });
        }
    }
    try p.expectClosing(l_paren, .r_paren);
    return true;
}

/// attributeSpecifier : (keyword_attribute '( '(' attributeList ')' ')')*
fn attributeSpecifier(p: *Parser) Error!void {
    while (true) {
        if (try p.alignAs()) continue;
        if (try p.gnuAttribute()) continue;
        if (try p.c2xAttribute()) continue;
        if (try p.msvcAttribute()) continue;
        break;
    }
}

/// initDeclarator : declarator assembly? attributeSpecifier? ('=' initializer)?
fn initDeclarator(p: *Parser, decl_spec: *DeclSpec) Error!?InitDeclarator {
    var init_d = InitDeclarator{
        .d = (try p.declarator(decl_spec.ty, .normal)) orelse return null,
    };
    _ = try p.assembly(.decl_label);
    try p.attributeSpecifier(); // if (init_d.d.ty.isFunc()) .function else .variable
    if (p.eatToken(.equal)) |eq| init: {
        if (decl_spec.storage_class == .typedef or init_d.d.func_declarator != null) {
            try p.errTok(.illegal_initializer, eq);
        } else if (init_d.d.ty.is(.variable_len_array)) {
            try p.errTok(.vla_init, eq);
        } else if (decl_spec.storage_class == .@"extern") {
            try p.err(.extern_initializer);
            decl_spec.storage_class = .none;
        }

        if (init_d.d.ty.hasIncompleteSize() and !init_d.d.ty.is(.incomplete_array)) {
            try p.errStr(.variable_incomplete_ty, init_d.d.name, try p.typeStr(init_d.d.ty));
            return error.ParsingFailed;
        }

        const scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = scopes_len;
        try p.scopes.append(.{ .decl = .{
            .name = p.tokSlice(init_d.d.name),
            .ty = init_d.d.ty,
            .name_tok = init_d.d.name,
        } });
        var init_list_expr = try p.initializer(init_d.d.ty);
        init_d.initializer = init_list_expr.node;
        if (!init_list_expr.ty.isArray()) break :init;
        if (init_d.d.ty.specifier == .incomplete_array) {
            // Modifying .data is exceptionally allowed for .incomplete_array.
            init_d.d.ty.data.array.len = init_list_expr.ty.arrayLen() orelse break :init;
            init_d.d.ty.specifier = .array;
        } else if (init_d.d.ty.is(.incomplete_array)) {
            const attrs = init_d.d.ty.getAttributes();

            const arr_ty = try p.arena.create(Type.Array);
            arr_ty.* = .{ .elem = init_d.d.ty.elemType(), .len = init_list_expr.ty.arrayLen().? };
            const ty = Type{
                .specifier = .array,
                .data = .{ .array = arr_ty },
            };
            init_d.d.ty = try ty.withAttributes(p.arena, attrs);
        }
    }
    const name = init_d.d.name;
    if (decl_spec.storage_class != .typedef and init_d.d.ty.hasIncompleteSize()) incomplete: {
        const specifier = init_d.d.ty.canonicalize(.standard).specifier;
        if (decl_spec.storage_class == .@"extern") switch (specifier) {
            .@"struct", .@"union", .@"enum" => break :incomplete,
            .incomplete_array => {
                init_d.d.ty.decayArray();
                break :incomplete;
            },
            else => {},
        };
        // if there was an initializer expression it must have contained an error
        if (init_d.initializer != .none) break :incomplete;
        try p.errStr(.variable_incomplete_ty, name, try p.typeStr(init_d.d.ty));
        return init_d;
    }
    if (p.findSymbol(name, .definition)) |scope| switch (scope) {
        .enumeration => {
            try p.errStr(.redefinition_different_sym, name, p.tokSlice(name));
            try p.errTok(.previous_definition, scope.enumeration.name_tok);
        },
        .decl => |s| if (!s.ty.eql(init_d.d.ty, p.pp.comp, true)) {
            try p.errStr(.redefinition_incompatible, name, p.tokSlice(name));
            try p.errTok(.previous_definition, s.name_tok);
        },
        .def => |s| if (!s.ty.eql(init_d.d.ty, p.pp.comp, true)) {
            try p.errStr(.redefinition_incompatible, name, p.tokSlice(name));
            try p.errTok(.previous_definition, s.name_tok);
        } else if (init_d.initializer != .none) {
            try p.errStr(.redefinition, name, p.tokSlice(name));
            try p.errTok(.previous_definition, s.name_tok);
        },
        .param => |s| {
            try p.errStr(.redefinition, name, p.tokSlice(name));
            try p.errTok(.previous_definition, s.name_tok);
        },
        else => unreachable,
    };
    return init_d;
}

/// typeSpec
///  : keyword_void
///  | keyword_char
///  | keyword_short
///  | keyword_int
///  | keyword_long
///  | keyword_float
///  | keyword_double
///  | keyword_signed
///  | keyword_unsigned
///  | keyword_bool
///  | keyword_complex
///  | atomicTypeSpec
///  | recordSpec
///  | enumSpec
///  | typedef  // IDENTIFIER
///  | typeof
/// atomicTypeSpec : keyword_atomic '(' typeName ')'
/// alignSpec
///   : keyword_alignas '(' typeName ')'
///   | keyword_alignas '(' constExpr ')'
fn typeSpec(p: *Parser, ty: *Type.Builder) Error!bool {
    const start = p.tok_i;
    while (true) {
        try p.attributeSpecifier(); // .typedef

        if (try p.typeof()) |inner_ty| {
            try ty.combineFromTypeof(p, inner_ty, start);
            continue;
        }
        if (try p.typeQual(&ty.qual)) continue;
        switch (p.tok_ids[p.tok_i]) {
            .keyword_void => try ty.combine(p, .void, p.tok_i),
            .keyword_bool => try ty.combine(p, .bool, p.tok_i),
            .keyword_char => try ty.combine(p, .char, p.tok_i),
            .keyword_short => try ty.combine(p, .short, p.tok_i),
            .keyword_int => try ty.combine(p, .int, p.tok_i),
            .keyword_long => try ty.combine(p, .long, p.tok_i),
            .keyword_signed => try ty.combine(p, .signed, p.tok_i),
            .keyword_unsigned => try ty.combine(p, .unsigned, p.tok_i),
            .keyword_float => try ty.combine(p, .float, p.tok_i),
            .keyword_double => try ty.combine(p, .double, p.tok_i),
            .keyword_complex => try ty.combine(p, .complex, p.tok_i),
            .keyword_atomic => {
                const atomic_tok = p.tok_i;
                p.tok_i += 1;
                const l_paren = p.eatToken(.l_paren) orelse {
                    // _Atomic qualifier not _Atomic(typeName)
                    p.tok_i = atomic_tok;
                    break;
                };
                const inner_ty = (try p.typeName()) orelse {
                    try p.err(.expected_type);
                    return error.ParsingFailed;
                };
                try p.expectClosing(l_paren, .r_paren);

                const new_spec = Type.Builder.fromType(inner_ty);
                try ty.combine(p, new_spec, atomic_tok);

                if (ty.qual.atomic != null)
                    try p.errStr(.duplicate_decl_spec, atomic_tok, "atomic")
                else
                    ty.qual.atomic = atomic_tok;
                continue;
            },
            .keyword_struct => {
                const tag_tok = p.tok_i;
                try ty.combine(p, .{ .@"struct" = try p.recordSpec() }, tag_tok);
                continue;
            },
            .keyword_union => {
                const tag_tok = p.tok_i;
                try ty.combine(p, .{ .@"union" = try p.recordSpec() }, tag_tok);
                continue;
            },
            .keyword_enum => {
                const tag_tok = p.tok_i;
                try ty.combine(p, .{ .@"enum" = try p.enumSpec() }, tag_tok);
                continue;
            },
            .identifier, .extended_identifier => {
                const typedef = (try p.findTypedef(p.tok_i, ty.specifier != .none)) orelse break;
                if (!ty.combineTypedef(p, typedef.ty, typedef.name_tok)) break;
            },
            else => break,
        }
        // consume single token specifiers here
        p.tok_i += 1;
    }
    return p.tok_i != start;
}

fn getAnonymousName(p: *Parser, kind_tok: TokenIndex) ![]const u8 {
    const loc = p.pp.tokens.items(.loc)[kind_tok];
    const source = p.pp.comp.getSource(loc.id);
    const line_col = source.lineCol(loc);

    const kind_str = switch (p.tok_ids[kind_tok]) {
        .keyword_struct, .keyword_union, .keyword_enum => p.tokSlice(kind_tok),
        else => "record field",
    };

    return std.fmt.allocPrint(
        p.arena,
        "(anonymous {s} at {s}:{d}:{d})",
        .{ kind_str, source.path, line_col.line_no, line_col.col },
    );
}

/// recordSpec
///  : (keyword_struct | keyword_union) IDENTIFIER? { recordDecl* }
///  | (keyword_struct | keyword_union) IDENTIFIER
fn recordSpec(p: *Parser) Error!*Type.Record {
    const kind_tok = p.tok_i;
    const is_struct = p.tok_ids[kind_tok] == .keyword_struct;
    p.tok_i += 1;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier(); // .record

    const maybe_ident = try p.eatIdentifier();
    const l_brace = p.eatToken(.l_brace) orelse {
        const ident = maybe_ident orelse {
            try p.err(.ident_or_l_brace);
            return error.ParsingFailed;
        };
        // check if this is a reference to a previous type
        if (try p.findTag(p.tok_ids[kind_tok], ident, .reference)) |prev| {
            return prev.ty.data.record;
        } else {
            // this is a forward declaration, create a new record Type.
            const record_ty = try Type.Record.create(p.arena, p.tokSlice(ident));
            const ty = Type{
                .specifier = if (is_struct) .@"struct" else .@"union",
                .data = .{ .record = record_ty },
            };
            const sym = Scope.Symbol{ .name = record_ty.name, .ty = ty, .name_tok = ident };
            try p.scopes.append(if (is_struct) .{ .@"struct" = sym } else .{ .@"union" = sym });
            return record_ty;
        }
    };

    // Get forward declared type or create a new one
    var defined = false;
    const record_ty: *Type.Record = if (maybe_ident) |ident| record_ty: {
        if (try p.findTag(p.tok_ids[kind_tok], ident, .definition)) |prev| {
            if (!prev.ty.data.record.isIncomplete()) {
                // if the record isn't incomplete, this is a redefinition
                try p.errStr(.redefinition, ident, p.tokSlice(ident));
                try p.errTok(.previous_definition, prev.name_tok);
            } else {
                defined = true;
                break :record_ty prev.ty.data.record;
            }
        }
        break :record_ty try Type.Record.create(p.arena, p.tokSlice(ident));
    } else try Type.Record.create(p.arena, try p.getAnonymousName(kind_tok));
    const ty = Type{
        .specifier = if (is_struct) .@"struct" else .@"union",
        .data = .{ .record = record_ty },
    };

    // declare a symbol for the type
    if (maybe_ident != null and !defined) {
        const sym = Scope.Symbol{ .name = record_ty.name, .ty = ty, .name_tok = maybe_ident.? };
        try p.scopes.append(if (is_struct) .{ .@"struct" = sym } else .{ .@"union" = sym });
    }

    // reserve space for this record
    try p.decl_buf.append(.none);
    const decl_buf_top = p.decl_buf.items.len;
    const record_buf_top = p.record_buf.items.len;
    const scopes_top = p.scopes.items.len;
    errdefer p.decl_buf.items.len = decl_buf_top - 1;
    defer {
        p.decl_buf.items.len = decl_buf_top;
        p.record_buf.items.len = record_buf_top;
        p.scopes.items.len = scopes_top;
    }

    const old_record = p.record;
    defer p.record = old_record;
    p.record = .{
        .kind = p.tok_ids[kind_tok],
        .scopes_top = scopes_top,
    };

    try p.recordDecls();

    if (p.record.flexible_field) |some| {
        if (p.record_buf.items[record_buf_top..].len == 1 and is_struct) {
            try p.errTok(.flexible_in_empty, some);
        }
    }

    record_ty.fields = try p.arena.dupe(Type.Record.Field, p.record_buf.items[record_buf_top..]);
    // TODO actually calculate
    record_ty.size = 1;
    record_ty.alignment = 1;

    if (p.record_buf.items.len == record_buf_top) try p.errStr(.empty_record, kind_tok, p.tokSlice(kind_tok));
    try p.expectClosing(l_brace, .r_brace);
    try p.attributeSpecifier(); // .record

    // finish by creating a node
    var node: Tree.Node = .{
        .tag = if (is_struct) .struct_decl_two else .union_decl_two,
        .ty = ty,
        .data = .{ .bin = .{ .lhs = .none, .rhs = .none } },
    };
    const record_decls = p.decl_buf.items[decl_buf_top..];
    switch (record_decls.len) {
        0 => {},
        1 => node.data = .{ .bin = .{ .lhs = record_decls[0], .rhs = .none } },
        2 => node.data = .{ .bin = .{ .lhs = record_decls[0], .rhs = record_decls[1] } },
        else => {
            node.tag = if (is_struct) .struct_decl else .union_decl;
            node.data = .{ .range = try p.addList(record_decls) };
        },
    }
    p.decl_buf.items[decl_buf_top - 1] = try p.addNode(node);
    return record_ty;
}

/// recordDecl
///  : specQual (recordDeclarator (',' recordDeclarator)*)? ;
///  | staticAssert
fn recordDecls(p: *Parser) Error!void {
    while (true) {
        if (try p.pragma()) continue;
        if (try p.parseOrNextDecl(staticAssert)) continue;
        if (p.eatToken(.keyword_extension)) |_| {
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            if (try p.parseOrNextDecl(recordDeclarator)) continue;
            try p.err(.expected_type);
            p.nextExternDecl();
            continue;
        }
        if (try p.parseOrNextDecl(recordDeclarator)) continue;
        break;
    }
}

/// recordDeclarator : keyword_extension? declarator (':' constExpr)?
fn recordDeclarator(p: *Parser) Error!bool {
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    const base_ty = (try p.specQual()) orelse return false;

    while (true) {
        const this_decl_top = p.attr_buf.len;
        defer p.attr_buf.len = this_decl_top;

        try p.attributeSpecifier(); // .record

        // 0 means unnamed
        var name_tok: TokenIndex = 0;
        var ty = base_ty;
        var bits_node: NodeIndex = .none;
        var bits: u32 = 0;
        const first_tok = p.tok_i;
        if (try p.declarator(ty, .record)) |d| {
            name_tok = d.name;
            ty = d.ty;
        }
        try p.attributeSpecifier(); // .record
        ty = try p.withAttributes(ty, attr_buf_top);

        if (p.eatToken(.colon)) |_| bits: {
            const res = try p.constExpr();
            if (!ty.isInt()) {
                try p.errStr(.non_int_bitfield, first_tok, try p.typeStr(ty));
                break :bits;
            }

            if (res.val.tag == .unavailable) {
                try p.errTok(.expected_integer_constant_expr, first_tok);
                break :bits;
            } else if (res.val.compare(.lt, Value.int(0), res.ty, p.pp.comp)) {
                try p.errExtra(.negative_bitwidth, first_tok, .{
                    .signed = res.val.signExtend(res.ty, p.pp.comp),
                });
                break :bits;
            }

            // incomplete size error is reported later
            const bit_size = ty.bitSizeof(p.pp.comp) orelse break :bits;
            if (res.val.compare(.gt, Value.int(bit_size), res.ty, p.pp.comp)) {
                try p.errTok(.bitfield_too_big, name_tok);
                break :bits;
            } else if (res.val.isZero() and name_tok != 0) {
                try p.errTok(.zero_width_named_field, name_tok);
                break :bits;
            }

            bits = res.val.getInt(u32);
            bits_node = res.node;
        }

        if (name_tok == 0 and bits_node == .none) unnamed: {
            if (ty.is(.@"enum")) break :unnamed;
            if (ty.isAnonymousRecord()) {
                // An anonymous record appears as indirect fields on the parent
                try p.record_buf.append(.{
                    .name = try p.getAnonymousName(first_tok),
                    .ty = ty,
                    .bit_width = 0,
                });
                const node = try p.addNode(.{
                    .tag = .indirect_record_field_decl,
                    .ty = ty,
                    .data = undefined,
                });
                try p.decl_buf.append(node);
                try p.record.addFieldsFromAnonymous(p, ty);
                break; // must be followed by a semicolon
            }
            try p.err(.missing_declaration);
        } else {
            try p.record_buf.append(.{
                .name = if (name_tok != 0) p.tokSlice(name_tok) else try p.getAnonymousName(first_tok),
                .ty = ty,
                .name_tok = name_tok,
                .bit_width = bits,
            });
            if (name_tok != 0) try p.record.addField(p, name_tok);
            const node = try p.addNode(.{
                .tag = .record_field_decl,
                .ty = ty,
                .data = .{ .decl = .{ .name = name_tok, .node = bits_node } },
            });
            try p.decl_buf.append(node);
        }

        if (ty.isFunc()) {
            try p.errTok(.func_field, first_tok);
        } else if (ty.is(.variable_len_array)) {
            try p.errTok(.vla_field, first_tok);
        } else if (ty.is(.incomplete_array)) {
            if (p.record.kind == .keyword_union) {
                try p.errTok(.flexible_in_union, first_tok);
            }
            if (p.record.flexible_field) |some| {
                try p.errTok(.flexible_non_final, some);
            }
            p.record.flexible_field = first_tok;
        } else if (ty.hasIncompleteSize()) {
            try p.errStr(.field_incomplete_ty, first_tok, try p.typeStr(ty));
        } else if (p.record.flexible_field) |some| {
            if (some != first_tok) try p.errTok(.flexible_non_final, some);
        }
        if (p.eatToken(.comma) == null) break;
    }
    _ = try p.expectToken(.semicolon);
    return true;
}

fn checkAlignasUsage(p: *Parser, tag: Diagnostics.Tag, attr_buf_start: usize) !void {
    var i = attr_buf_start;
    while (i < p.attr_buf.len) : (i += 1) {
        const tentative_attr = p.attr_buf.get(i);
        if (tentative_attr.attr.tag != .aligned) continue;
        if (tentative_attr.attr.args.aligned.alignment) |alignment| {
            if (alignment.alignas) try p.errTok(tag, tentative_attr.tok);
        }
    }
}

/// specQual : (typeSpec | typeQual | alignSpec)+
fn specQual(p: *Parser) Error!?Type {
    var spec: Type.Builder = .{};
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    if (try p.typeSpec(&spec)) {
        const ty = try spec.finish(p, attr_buf_top);
        try p.validateAlignas(ty, .align_ignored);
        return ty;
    }
    return null;
}

/// enumSpec
///  : keyword_enum IDENTIFIER? { enumerator (',' enumerator)? ',') }
///  | keyword_enum IDENTIFIER
fn enumSpec(p: *Parser) Error!*Type.Enum {
    const enum_tok = p.tok_i;
    p.tok_i += 1;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier(); // record

    const maybe_ident = try p.eatIdentifier();
    const l_brace = p.eatToken(.l_brace) orelse {
        const ident = maybe_ident orelse {
            try p.err(.ident_or_l_brace);
            return error.ParsingFailed;
        };
        // check if this is a reference to a previous type
        if (try p.findTag(.keyword_enum, ident, .reference)) |prev| {
            return prev.ty.data.@"enum";
        } else {
            // this is a forward declaration, create a new enum Type.
            const enum_ty = try Type.Enum.create(p.arena, p.tokSlice(ident));
            const ty = Type{ .specifier = .@"enum", .data = .{ .@"enum" = enum_ty } };
            const sym = Scope.Symbol{ .name = enum_ty.name, .ty = ty, .name_tok = ident };
            try p.scopes.append(.{ .@"enum" = sym });
            return enum_ty;
        }
    };

    // Get forward declared type or create a new one
    var defined = false;
    const enum_ty: *Type.Enum = if (maybe_ident) |ident| enum_ty: {
        if (try p.findTag(.keyword_enum, ident, .definition)) |prev| {
            if (!prev.ty.data.@"enum".isIncomplete()) {
                // if the enum isn't incomplete, this is a redefinition
                try p.errStr(.redefinition, ident, p.tokSlice(ident));
                try p.errTok(.previous_definition, prev.name_tok);
            } else {
                defined = true;
                break :enum_ty prev.ty.data.@"enum";
            }
        }
        break :enum_ty try Type.Enum.create(p.arena, p.tokSlice(ident));
    } else try Type.Enum.create(p.arena, try p.getAnonymousName(enum_tok));
    const ty = Type{
        .specifier = .@"enum",
        .data = .{ .@"enum" = enum_ty },
    };

    // declare a symbol for the type
    if (maybe_ident != null and !defined) {
        try p.scopes.append(.{ .@"enum" = .{
            .name = enum_ty.name,
            .ty = ty,
            .name_tok = maybe_ident.?,
        } });
    }

    // reserve space for this enum
    try p.decl_buf.append(.none);
    const decl_buf_top = p.decl_buf.items.len;
    const list_buf_top = p.list_buf.items.len;
    const enum_buf_top = p.enum_buf.items.len;
    errdefer p.decl_buf.items.len = decl_buf_top - 1;
    defer {
        p.decl_buf.items.len = decl_buf_top;
        p.list_buf.items.len = list_buf_top;
        p.enum_buf.items.len = enum_buf_top;
    }

    var e = Enumerator.init(p);
    while (try p.enumerator(&e)) |field_and_node| {
        try p.enum_buf.append(field_and_node.field);
        try p.list_buf.append(field_and_node.node);
        if (p.eatToken(.comma) == null) break;
    }
    enum_ty.fields = try p.arena.dupe(Type.Enum.Field, p.enum_buf.items[enum_buf_top..]);
    enum_ty.tag_ty = e.res.ty;

    if (p.enum_buf.items.len == enum_buf_top) try p.err(.empty_enum);
    try p.expectClosing(l_brace, .r_brace);
    try p.attributeSpecifier(); // record

    // finish by creating a node
    var node: Tree.Node = .{ .tag = .enum_decl_two, .ty = ty, .data = .{
        .bin = .{ .lhs = .none, .rhs = .none },
    } };
    const field_nodes = p.list_buf.items[list_buf_top..];
    switch (field_nodes.len) {
        0 => {},
        1 => node.data = .{ .bin = .{ .lhs = field_nodes[0], .rhs = .none } },
        2 => node.data = .{ .bin = .{ .lhs = field_nodes[0], .rhs = field_nodes[1] } },
        else => {
            node.tag = .enum_decl;
            node.data = .{ .range = try p.addList(field_nodes) };
        },
    }
    p.decl_buf.items[decl_buf_top - 1] = try p.addNode(node);
    return enum_ty;
}

const Enumerator = struct {
    res: Result,

    fn init(p: *Parser) Enumerator {
        return .{ .res = .{
            .ty = .{ .specifier = if (p.pp.comp.langopts.short_enums) .schar else .int },
            .val = Value.int(0),
        } };
    }

    /// Increment enumerator value adjusting type if needed.
    fn incr(e: *Enumerator, p: *Parser) !void {
        e.res.node = .none;
        _ = p;
        _ = e.res.val.add(e.res.val, Value.int(1), e.res.ty, p.pp.comp);
        // TODO adjust type if value does not fit current
    }

    /// Set enumerator value to specified value, adjusting type if needed.
    fn set(e: *Enumerator, p: *Parser, res: Result) !void {
        _ = p;
        e.res = res;
        // TODO adjust res type to try to fit with the previous type
    }
};

const EnumFieldAndNode = struct { field: Type.Enum.Field, node: NodeIndex };

/// enumerator : IDENTIFIER ('=' constExpr)
fn enumerator(p: *Parser, e: *Enumerator) Error!?EnumFieldAndNode {
    _ = try p.pragma();
    const name_tok = (try p.eatIdentifier()) orelse {
        if (p.tok_ids[p.tok_i] == .r_brace) return null;
        try p.err(.expected_identifier);
        p.skipTo(.r_brace);
        return error.ParsingFailed;
    };
    const name = p.tokSlice(name_tok);
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier();

    if (p.eatToken(.equal)) |_| {
        const specified = try p.constExpr();
        if (specified.val.tag == .unavailable) {
            try p.errTok(.enum_val_unavailable, name_tok + 2);
            try e.incr(p);
        } else {
            try e.set(p, specified);
        }
    } else {
        try e.incr(p);
    }

    if (p.findSymbol(name_tok, .definition)) |scope| switch (scope) {
        .enumeration => |sym| {
            try p.errStr(.redefinition, name_tok, name);
            try p.errTok(.previous_definition, sym.name_tok);
        },
        .decl, .def, .param => |sym| {
            try p.errStr(.redefinition_different_sym, name_tok, name);
            try p.errTok(.previous_definition, sym.name_tok);
        },
        else => unreachable,
    };

    var res = e.res;
    res.ty = try p.withAttributes(res.ty, attr_buf_top);

    try p.scopes.append(.{ .enumeration = .{
        .name = name,
        .value = res,
        .name_tok = name_tok,
    } });
    const node = try p.addNode(.{
        .tag = .enum_field_decl,
        .ty = res.ty,
        .data = .{ .decl = .{
            .name = name_tok,
            .node = res.node,
        } },
    });
    return EnumFieldAndNode{ .field = .{
        .name = name,
        .ty = res.ty,
        .name_tok = name_tok,
        .node = res.node,
    }, .node = node };
}

/// typeQual : keyword_const | keyword_restrict | keyword_volatile | keyword_atomic
fn typeQual(p: *Parser, b: *Type.Qualifiers.Builder) Error!bool {
    var any = false;
    while (true) {
        switch (p.tok_ids[p.tok_i]) {
            .keyword_restrict, .keyword_restrict1, .keyword_restrict2 => {
                if (b.restrict != null)
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "restrict")
                else
                    b.restrict = p.tok_i;
            },
            .keyword_const, .keyword_const1, .keyword_const2 => {
                if (b.@"const" != null)
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "const")
                else
                    b.@"const" = p.tok_i;
            },
            .keyword_volatile, .keyword_volatile1, .keyword_volatile2 => {
                if (b.@"volatile" != null)
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "volatile")
                else
                    b.@"volatile" = p.tok_i;
            },
            .keyword_atomic => {
                // _Atomic(typeName) instead of just _Atomic
                if (p.tok_ids[p.tok_i + 1] == .l_paren) break;
                if (b.atomic != null)
                    try p.errStr(.duplicate_decl_spec, p.tok_i, "atomic")
                else
                    b.atomic = p.tok_i;
            },
            else => break,
        }
        p.tok_i += 1;
        any = true;
    }
    return any;
}

const Declarator = struct {
    name: TokenIndex,
    ty: Type,
    func_declarator: ?TokenIndex = null,
    old_style_func: ?TokenIndex = null,
};
const DeclaratorKind = enum { normal, abstract, param, record };

/// declarator : pointer? (IDENTIFIER | '(' declarator ')') directDeclarator*
/// abstractDeclarator
/// : pointer? ('(' abstractDeclarator ')')? directAbstractDeclarator*
fn declarator(
    p: *Parser,
    base_type: Type,
    kind: DeclaratorKind,
) Error!?Declarator {
    const start = p.tok_i;
    var d = Declarator{ .name = 0, .ty = try p.pointer(base_type) };

    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;

    const maybe_ident = p.tok_i;
    if (kind != .abstract and (try p.eatIdentifier()) != null) {
        d.name = maybe_ident;
        const combine_tok = p.tok_i;
        d.ty = try p.directDeclarator(d.ty, &d, kind);
        try d.ty.validateCombinedType(p, combine_tok);
        d.ty = try p.withAttributes(d.ty, attr_buf_top);
        return d;
    } else if (p.eatToken(.l_paren)) |l_paren| blk: {
        var res = (try p.declarator(.{ .specifier = .void }, kind)) orelse {
            p.tok_i = l_paren;
            break :blk;
        };
        try p.expectClosing(l_paren, .r_paren);
        const suffix_start = p.tok_i;
        const outer = try p.directDeclarator(d.ty, &d, kind);
        try res.ty.combine(outer, p, res.func_declarator orelse suffix_start);
        try res.ty.validateCombinedType(p, suffix_start);
        res.old_style_func = d.old_style_func;
        return res;
    }

    const expected_ident = p.tok_i;

    d.ty = try p.directDeclarator(d.ty, &d, kind);

    if (kind == .normal and !d.ty.isEnumOrRecord()) {
        try p.errTok(.expected_ident_or_l_paren, expected_ident);
        return error.ParsingFailed;
    }
    try d.ty.validateCombinedType(p, expected_ident);
    d.ty = try p.withAttributes(d.ty, attr_buf_top);
    if (start == p.tok_i) return null;
    return d;
}

/// directDeclarator
///  : '[' typeQual* assignExpr? ']' directDeclarator?
///  | '[' keyword_static typeQual* assignExpr ']' directDeclarator?
///  | '[' typeQual+ keyword_static assignExpr ']' directDeclarator?
///  | '[' typeQual* '*' ']' directDeclarator?
///  | '(' paramDecls ')' directDeclarator?
///  | '(' (IDENTIFIER (',' IDENTIFIER))? ')' directDeclarator?
/// directAbstractDeclarator
///  : '[' typeQual* assignExpr? ']'
///  | '[' keyword_static typeQual* assignExpr ']'
///  | '[' typeQual+ keyword_static assignExpr ']'
///  | '[' '*' ']'
///  | '(' paramDecls? ')'
fn directDeclarator(p: *Parser, base_type: Type, d: *Declarator, kind: DeclaratorKind) Error!Type {
    try p.attributeSpecifier();
    if (p.eatToken(.l_bracket)) |l_bracket| {
        var res_ty = Type{
            // so that we can get any restrict type that might be present
            .specifier = .pointer,
        };
        var quals = Type.Qualifiers.Builder{};

        var got_quals = try p.typeQual(&quals);
        var static = p.eatToken(.keyword_static);
        if (static != null and !got_quals) got_quals = try p.typeQual(&quals);
        var star = p.eatToken(.asterisk);
        const size_tok = p.tok_i;
        const size = if (star) |_| Result{} else try p.assignExpr();
        try p.expectClosing(l_bracket, .r_bracket);

        if (star != null and static != null) {
            try p.errTok(.invalid_static_star, static.?);
            static = null;
        }
        if (kind != .param) {
            if (static != null)
                try p.errTok(.static_non_param, l_bracket)
            else if (got_quals)
                try p.errTok(.array_qualifiers, l_bracket);
            if (star) |some| try p.errTok(.star_non_param, some);
            static = null;
            quals = .{};
            star = null;
        } else {
            try quals.finish(p, &res_ty);
        }
        if (static) |_| try size.expect(p);

        const outer = try p.directDeclarator(base_type, d, kind);
        var max_bits = p.pp.comp.target.cpu.arch.ptrBitWidth();
        if (max_bits > 61) max_bits = 61;
        const max_bytes = (@as(u64, 1) << @truncate(u6, max_bits)) - 1;
        // `outer` is validated later so it may be invalid here
        const outer_size = if (outer.hasIncompleteSize()) 1 else outer.sizeof(p.pp.comp);
        const max_elems = max_bytes / std.math.max(1, outer_size orelse 1);

        if (size.val.tag == .unavailable) {
            if (size.node != .none) {
                if (p.func.ty == null and kind != .param and p.record.kind == .invalid) {
                    try p.errTok(.variable_len_array_file_scope, l_bracket);
                }
                const expr_ty = try p.arena.create(Type.Expr);
                expr_ty.node = size.node;
                res_ty.data = .{ .expr = expr_ty };
                res_ty.specifier = .variable_len_array;

                if (static) |some| try p.errTok(.useless_static, some);
            } else if (star) |_| {
                const elem_ty = try p.arena.create(Type);
                res_ty.data = .{ .sub_type = elem_ty };
                res_ty.specifier = .unspecified_variable_len_array;
            } else {
                const arr_ty = try p.arena.create(Type.Array);
                arr_ty.len = 0;
                res_ty.data = .{ .array = arr_ty };
                res_ty.specifier = .incomplete_array;
            }
        } else if (!size.ty.isInt() and !size.ty.isFloat()) {
            try p.errStr(.array_size_non_int, size_tok, try p.typeStr(size.ty));
            return error.ParsingFailed;
        } else {
            var size_val = size.val;
            const size_t = p.pp.comp.types.size;
            if (size_val.tag == .float) {
                size_val.floatToInt(size.ty, size_t, p.pp.comp);
            }
            if (size_val.compare(.lt, Value.int(0), size_t, p.pp.comp)) {
                try p.errTok(.negative_array_size, l_bracket);
            }
            const arr_ty = try p.arena.create(Type.Array);
            if (size_val.compare(.gt, Value.int(max_elems), size_t, p.pp.comp)) {
                try p.errTok(.array_too_large, l_bracket);
                arr_ty.len = max_elems;
            } else {
                arr_ty.len = size_val.getInt(u64);
            }
            res_ty.data = .{ .array = arr_ty };
            res_ty.specifier = .array;
        }

        try res_ty.combine(outer, p, l_bracket);
        return res_ty;
    } else if (p.eatToken(.l_paren)) |l_paren| {
        d.func_declarator = l_paren;

        const func_ty = try p.arena.create(Type.Func);
        func_ty.params = &.{};
        var specifier: Type.Specifier = .func;

        if (p.eatToken(.ellipsis)) |_| {
            try p.err(.param_before_var_args);
            try p.expectClosing(l_paren, .r_paren);
            var res_ty = Type{ .specifier = .func, .data = .{ .func = func_ty } };

            const outer = try p.directDeclarator(base_type, d, kind);
            try res_ty.combine(outer, p, l_paren);
            return res_ty;
        }

        if (try p.paramDecls()) |params| {
            func_ty.params = params;
            if (p.eatToken(.ellipsis)) |_| specifier = .var_args_func;
        } else if (p.tok_ids[p.tok_i] == .r_paren) {
            specifier = .old_style_func;
        } else if (p.tok_ids[p.tok_i] == .identifier or p.tok_ids[p.tok_i] == .extended_identifier) {
            d.old_style_func = p.tok_i;
            const param_buf_top = p.param_buf.items.len;
            const scopes_top = p.scopes.items.len;
            defer {
                p.param_buf.items.len = param_buf_top;
                p.scopes.items.len = scopes_top;
            }

            // findSymbol stops the search at .block
            try p.scopes.append(.block);

            specifier = .old_style_func;
            while (true) {
                const name_tok = try p.expectIdentifier();
                if (p.findSymbol(name_tok, .definition)) |scope| {
                    try p.errStr(.redefinition_of_parameter, name_tok, p.tokSlice(name_tok));
                    try p.errTok(.previous_definition, scope.param.name_tok);
                }
                try p.scopes.append(.{ .param = .{
                    .name = p.tokSlice(name_tok),
                    .ty = undefined,
                    .name_tok = name_tok,
                } });
                try p.param_buf.append(.{
                    .name = p.tokSlice(name_tok),
                    .name_tok = name_tok,
                    .ty = .{ .specifier = .int },
                });
                if (p.eatToken(.comma) == null) break;
            }
            func_ty.params = try p.arena.dupe(Type.Func.Param, p.param_buf.items[param_buf_top..]);
        } else {
            try p.err(.expected_param_decl);
        }

        try p.expectClosing(l_paren, .r_paren);
        var res_ty = Type{
            .specifier = specifier,
            .data = .{ .func = func_ty },
        };

        const outer = try p.directDeclarator(base_type, d, kind);
        try res_ty.combine(outer, p, l_paren);
        return res_ty;
    } else return base_type;
}

/// pointer : '*' typeQual* pointer?
fn pointer(p: *Parser, base_ty: Type) Error!Type {
    var ty = base_ty;
    while (p.eatToken(.asterisk)) |_| {
        const elem_ty = try p.arena.create(Type);
        elem_ty.* = ty;
        ty = Type{
            .specifier = .pointer,
            .data = .{ .sub_type = elem_ty },
        };
        var quals = Type.Qualifiers.Builder{};
        _ = try p.typeQual(&quals);
        try quals.finish(p, &ty);
    }
    return ty;
}

/// paramDecls : paramDecl (',' paramDecl)* (',' '...')
/// paramDecl : declSpec (declarator | abstractDeclarator)
fn paramDecls(p: *Parser) Error!?[]Type.Func.Param {
    // TODO warn about visibility of types declared here
    const param_buf_top = p.param_buf.items.len;
    const scopes_top = p.scopes.items.len;
    defer {
        p.param_buf.items.len = param_buf_top;
        p.scopes.items.len = scopes_top;
    }

    // findSymbol stops the search at .block
    try p.scopes.append(.block);

    while (true) {
        const param_decl_spec = if (try p.declSpec(true)) |some|
            some
        else if (p.param_buf.items.len == param_buf_top)
            return null
        else blk: {
            var spec: Type.Builder = .{};
            break :blk DeclSpec{ .ty = try spec.finish(p, p.attr_buf.len) };
        };

        var name_tok: TokenIndex = 0;
        const first_tok = p.tok_i;
        var param_ty = param_decl_spec.ty;
        if (try p.declarator(param_decl_spec.ty, .param)) |some| {
            if (some.old_style_func) |tok_i| try p.errTok(.invalid_old_style_params, tok_i);

            const attr_buf_top = p.attr_buf.len;
            defer p.attr_buf.len = attr_buf_top;
            try p.attributeSpecifier();

            name_tok = some.name;
            param_ty = try p.withAttributes(some.ty, attr_buf_top);
            if (some.name != 0) {
                if (p.findSymbol(name_tok, .definition)) |scope| {
                    if (scope == .enumeration) {
                        try p.errStr(.redefinition_of_parameter, name_tok, p.tokSlice(name_tok));
                        try p.errTok(.previous_definition, scope.enumeration.name_tok);
                    } else {
                        try p.errStr(.redefinition_of_parameter, name_tok, p.tokSlice(name_tok));
                        try p.errTok(.previous_definition, scope.param.name_tok);
                    }
                }
                try p.scopes.append(.{ .param = .{
                    .name = p.tokSlice(name_tok),
                    .ty = param_ty,
                    .name_tok = name_tok,
                } });
            }
        }

        if (param_ty.isFunc()) {
            // params declared as functions are converted to function pointers
            const elem_ty = try p.arena.create(Type);
            elem_ty.* = param_ty;
            param_ty = Type{
                .specifier = .pointer,
                .data = .{ .sub_type = elem_ty },
            };
        } else if (param_ty.isArray()) {
            // params declared as arrays are converted to pointers
            param_ty.decayArray();
        } else if (param_ty.is(.void)) {
            // validate void parameters
            if (p.param_buf.items.len == param_buf_top) {
                if (p.tok_ids[p.tok_i] != .r_paren) {
                    try p.err(.void_only_param);
                    if (param_ty.anyQual()) try p.err(.void_param_qualified);
                    return error.ParsingFailed;
                }
                return &[0]Type.Func.Param{};
            }
            try p.err(.void_must_be_first_param);
            return error.ParsingFailed;
        }

        try param_decl_spec.validateParam(p, &param_ty);
        try p.param_buf.append(.{
            .name = if (name_tok == 0) "" else p.tokSlice(name_tok),
            .name_tok = if (name_tok == 0) first_tok else name_tok,
            .ty = param_ty,
        });

        if (p.eatToken(.comma) == null) break;
        if (p.tok_ids[p.tok_i] == .ellipsis) break;
    }
    return try p.arena.dupe(Type.Func.Param, p.param_buf.items[param_buf_top..]);
}

/// typeName : specQual abstractDeclarator
fn typeName(p: *Parser) Error!?Type {
    var ty = (try p.specQual()) orelse return null;
    if (try p.declarator(ty, .abstract)) |some| {
        if (some.old_style_func) |tok_i| try p.errTok(.invalid_old_style_params, tok_i);
        return some.ty;
    } else return ty;
}

/// initializer
///  : assignExpr
///  | '{' initializerItems '}'
fn initializer(p: *Parser, init_ty: Type) Error!Result {
    // fast path for non-braced initializers
    if (p.tok_ids[p.tok_i] != .l_brace) {
        const tok = p.tok_i;
        var res = try p.assignExpr();
        try res.expect(p);
        if (try p.coerceArrayInit(&res, tok, init_ty)) return res;
        try p.coerceInit(&res, tok, init_ty);
        return res;
    }

    var il: InitList = .{};
    defer il.deinit(p.pp.comp.gpa);

    _ = try p.initializerItem(&il, init_ty);

    const res = try p.convertInitList(il, init_ty);
    var res_ty = p.nodes.items(.ty)[@enumToInt(res)];
    res_ty.qual = init_ty.qual;
    return Result{ .ty = res_ty, .node = res };
}

/// initializerItems : designation? initializer (',' designation? initializer)* ','?
/// designation : designator+ '='
/// designator
///  : '[' constExpr ']'
///  | '.' identifier
fn initializerItem(p: *Parser, il: *InitList, init_ty: Type) Error!bool {
    const l_brace = p.eatToken(.l_brace) orelse {
        const tok = p.tok_i;
        var res = try p.assignExpr();
        if (res.empty(p)) return false;

        const arr = try p.coerceArrayInit(&res, tok, init_ty);
        if (!arr) try p.coerceInit(&res, tok, init_ty);
        if (il.tok != 0) {
            try p.errTok(.initializer_overrides, tok);
            try p.errTok(.previous_initializer, il.tok);
        }
        il.node = res.node;
        il.tok = tok;
        return true;
    };

    const is_scalar = init_ty.isInt() or init_ty.isFloat() or init_ty.isPtr();
    if (p.eatToken(.r_brace)) |_| {
        if (is_scalar) try p.errTok(.empty_scalar_init, l_brace);
        if (il.tok != 0) {
            try p.errTok(.initializer_overrides, l_brace);
            try p.errTok(.previous_initializer, il.tok);
        }
        il.node = .none;
        il.tok = l_brace;
        return true;
    }

    var count: u64 = 0;
    var warned_excess = false;
    var is_str_init = false;
    var index_hint: ?usize = null;
    while (true) : (count += 1) {
        errdefer p.skipTo(.r_brace);

        const first_tok = p.tok_i;
        var cur_ty = init_ty;
        var cur_il = il;
        var designation = false;
        var cur_index_hint: ?usize = null;
        while (true) {
            if (p.eatToken(.l_bracket)) |l_bracket| {
                if (!cur_ty.isArray()) {
                    try p.errStr(.invalid_array_designator, l_bracket, try p.typeStr(cur_ty));
                    return error.ParsingFailed;
                }
                const expr_tok = p.tok_i;
                const index_res = try p.constExpr();
                try p.expectClosing(l_bracket, .r_bracket);

                if (index_res.val.tag == .unavailable) {
                    try p.errTok(.expected_integer_constant_expr, expr_tok);
                    return error.ParsingFailed;
                } else if (index_res.val.compare(.lt, index_res.val.zero(), index_res.ty, p.pp.comp)) {
                    try p.errExtra(.negative_array_designator, l_bracket + 1, .{
                        .signed = index_res.val.signExtend(index_res.ty, p.pp.comp),
                    });
                    return error.ParsingFailed;
                }

                const max_len = cur_ty.arrayLen() orelse std.math.maxInt(usize);
                if (index_res.val.data.int >= max_len) {
                    try p.errExtra(.oob_array_designator, l_bracket + 1, .{ .unsigned = index_res.val.data.int });
                    return error.ParsingFailed;
                }
                const checked = index_res.val.getInt(u64);
                cur_index_hint = cur_index_hint orelse checked;

                cur_il = try cur_il.find(p.pp.comp.gpa, checked);
                cur_ty = cur_ty.elemType();
                designation = true;
            } else if (p.eatToken(.period)) |period| {
                const field_name = p.tokSlice(try p.expectIdentifier());
                cur_ty = cur_ty.canonicalize(.standard);
                if (!cur_ty.isRecord()) {
                    try p.errStr(.invalid_field_designator, period, try p.typeStr(cur_ty));
                    return error.ParsingFailed;
                } else if (!cur_ty.hasField(field_name)) {
                    try p.errStr(.no_such_field_designator, period, field_name);
                    return error.ParsingFailed;
                }

                // TODO check if union already has field set
                outer: while (true) {
                    for (cur_ty.data.record.fields) |f, i| {
                        if (f.isAnonymousRecord()) {
                            // Recurse into anonymous field if it has a field by the name.
                            if (!f.ty.hasField(field_name)) continue;
                            cur_ty = f.ty.canonicalize(.standard);
                            cur_il = try il.find(p.pp.comp.gpa, i);
                            cur_index_hint = cur_index_hint orelse i;
                            continue :outer;
                        }
                        if (std.mem.eql(u8, field_name, f.name)) {
                            cur_il = try cur_il.find(p.pp.comp.gpa, i);
                            cur_ty = f.ty;
                            cur_index_hint = cur_index_hint orelse i;
                            break :outer;
                        }
                    }
                    unreachable; // we already checked that the starting type has this field
                }
                designation = true;
            } else break;
        }
        if (designation) index_hint = null;
        defer index_hint = cur_index_hint orelse null;

        if (designation) _ = try p.expectToken(.equal);

        var saw = false;
        if (is_str_init and p.isStringInit(init_ty)) {
            // discard further strings
            var tmp_il = InitList{};
            defer tmp_il.deinit(p.pp.comp.gpa);
            saw = try p.initializerItem(&tmp_il, .{ .specifier = .void });
        } else if (count == 0 and p.isStringInit(init_ty)) {
            is_str_init = true;
            saw = try p.initializerItem(il, init_ty);
        } else if (is_scalar and count != 0) {
            // discard further scalars
            var tmp_il = InitList{};
            defer tmp_il.deinit(p.pp.comp.gpa);
            saw = try p.initializerItem(&tmp_il, .{ .specifier = .void });
        } else if (p.tok_ids[p.tok_i] == .l_brace) {
            if (designation) {
                // designation overrides previous value, let existing mechanism handle it
                saw = try p.initializerItem(cur_il, cur_ty);
            } else if (try p.findAggregateInitializer(&cur_il, &cur_ty, &index_hint)) {
                saw = try p.initializerItem(cur_il, cur_ty);
            } else {
                // discard further values
                var tmp_il = InitList{};
                defer tmp_il.deinit(p.pp.comp.gpa);
                saw = try p.initializerItem(&tmp_il, .{ .specifier = .void });
                if (!warned_excess) try p.errTok(if (init_ty.isArray()) .excess_array_init else .excess_struct_init, first_tok);
                warned_excess = true;
            }
        } else if (index_hint != null and try p.findScalarInitializerAt(&cur_il, &cur_ty, &index_hint.?)) {
            saw = try p.initializerItem(cur_il, cur_ty);
        } else if (try p.findScalarInitializer(&cur_il, &cur_ty)) {
            saw = try p.initializerItem(cur_il, cur_ty);
        } else if (designation) {
            // designation overrides previous value, let existing mechanism handle it
            saw = try p.initializerItem(cur_il, cur_ty);
        } else {
            // discard further values
            var tmp_il = InitList{};
            defer tmp_il.deinit(p.pp.comp.gpa);
            saw = try p.initializerItem(&tmp_il, .{ .specifier = .void });
            if (!warned_excess and saw) try p.errTok(if (init_ty.isArray()) .excess_array_init else .excess_struct_init, first_tok);
            warned_excess = true;
        }

        if (!saw) {
            if (designation) {
                try p.err(.expected_expr);
                return error.ParsingFailed;
            }
            break;
        } else if (count == 1) {
            if (is_str_init) try p.errTok(.excess_str_init, first_tok);
            if (is_scalar) try p.errTok(.excess_scalar_init, first_tok);
        }

        if (p.eatToken(.comma) == null) break;
    }
    try p.expectClosing(l_brace, .r_brace);

    if (is_scalar or is_str_init) return true;
    if (il.tok != 0) {
        try p.errTok(.initializer_overrides, l_brace);
        try p.errTok(.previous_initializer, il.tok);
    }
    il.node = .none;
    il.tok = l_brace;
    return true;
}

/// Returns true if the value is unused.
fn findScalarInitializerAt(p: *Parser, il: **InitList, ty: *Type, start_index: *usize) Error!bool {
    if (ty.isArray()) {
        start_index.* += 1;

        const arr_ty = ty.*;
        const elem_count = arr_ty.arrayLen() orelse std.math.maxInt(usize);
        if (elem_count == 0) {
            if (p.tok_ids[p.tok_i] != .l_brace) {
                try p.err(.empty_aggregate_init_braces);
                return error.ParsingFailed;
            }
            return false;
        }
        const elem_ty = arr_ty.elemType();
        const arr_il = il.*;
        if (start_index.* < elem_count) {
            ty.* = elem_ty;
            il.* = try arr_il.find(p.pp.comp.gpa, start_index.*);
            _ = try p.findScalarInitializer(il, ty);
            return true;
        }
        return false;
    } else if (ty.get(.@"struct")) |struct_ty| {
        start_index.* += 1;

        const field_count = struct_ty.data.record.fields.len;
        if (field_count == 0) {
            if (p.tok_ids[p.tok_i] != .l_brace) {
                try p.err(.empty_aggregate_init_braces);
                return error.ParsingFailed;
            }
            return false;
        }
        const struct_il = il.*;
        if (start_index.* < field_count) {
            const field = struct_ty.data.record.fields[start_index.*];
            ty.* = field.ty;
            il.* = try struct_il.find(p.pp.comp.gpa, start_index.*);
            _ = try p.findScalarInitializer(il, ty);
            return true;
        }
        return false;
    } else if (ty.get(.@"union")) |_| {
        return false;
    }
    return il.*.node == .none;
}

/// Returns true if the value is unused.
fn findScalarInitializer(p: *Parser, il: **InitList, ty: *Type) Error!bool {
    if (ty.isArray()) {
        var index = il.*.list.items.len;
        if (index != 0) index = il.*.list.items[index - 1].index;

        const arr_ty = ty.*;
        const elem_count = arr_ty.arrayLen() orelse std.math.maxInt(usize);
        if (elem_count == 0) {
            if (p.tok_ids[p.tok_i] != .l_brace) {
                try p.err(.empty_aggregate_init_braces);
                return error.ParsingFailed;
            }
            return false;
        }
        const elem_ty = arr_ty.elemType();
        const arr_il = il.*;
        while (index < elem_count) : (index += 1) {
            ty.* = elem_ty;
            il.* = try arr_il.find(p.pp.comp.gpa, index);
            if (try p.findScalarInitializer(il, ty)) return true;
        }
        return false;
    } else if (ty.get(.@"struct")) |struct_ty| {
        var index = il.*.list.items.len;
        if (index != 0) index = il.*.list.items[index - 1].index + 1;

        const field_count = struct_ty.data.record.fields.len;
        if (field_count == 0) {
            if (p.tok_ids[p.tok_i] != .l_brace) {
                try p.err(.empty_aggregate_init_braces);
                return error.ParsingFailed;
            }
            return false;
        }
        const struct_il = il.*;
        while (index < field_count) : (index += 1) {
            const field = struct_ty.data.record.fields[index];
            ty.* = field.ty;
            il.* = try struct_il.find(p.pp.comp.gpa, index);
            if (try p.findScalarInitializer(il, ty)) return true;
        }
        return false;
    } else if (ty.get(.@"union")) |union_ty| {
        if (union_ty.data.record.fields.len == 0) {
            if (p.tok_ids[p.tok_i] != .l_brace) {
                try p.err(.empty_aggregate_init_braces);
                return error.ParsingFailed;
            }
            return false;
        }
        ty.* = union_ty.data.record.fields[0].ty;
        il.* = try il.*.find(p.pp.comp.gpa, 0);
        if (try p.findScalarInitializer(il, ty)) return true;
        return false;
    }
    return il.*.node == .none;
}

fn findAggregateInitializer(p: *Parser, il: **InitList, ty: *Type, start_index: *?usize) Error!bool {
    if (ty.isArray()) {
        var index = il.*.list.items.len;
        if (index != 0) index = il.*.list.items[index - 1].index + 1;
        if (start_index.*) |*some| {
            some.* += 1;
            index = some.*;
        }

        const arr_ty = ty.*;
        const elem_count = arr_ty.arrayLen() orelse std.math.maxInt(usize);
        const elem_ty = arr_ty.elemType();
        if (index < elem_count) {
            ty.* = elem_ty;
            il.* = try il.*.find(p.pp.comp.gpa, index);
            return true;
        }
        return false;
    } else if (ty.get(.@"struct")) |struct_ty| {
        var index = il.*.list.items.len;
        if (index != 0) index = il.*.list.items[index - 1].index + 1;
        if (start_index.*) |*some| {
            some.* += 1;
            index = some.*;
        }

        const field_count = struct_ty.data.record.fields.len;
        if (index < field_count) {
            ty.* = struct_ty.data.record.fields[index].ty;
            il.* = try il.*.find(p.pp.comp.gpa, index);
            return true;
        }
        return false;
    } else if (ty.get(.@"union")) |union_ty| {
        if (start_index.*) |_| return false; // overrides

        ty.* = union_ty.data.record.fields[0].ty;
        il.* = try il.*.find(p.pp.comp.gpa, 0);
        return true;
    } else {
        try p.err(.too_many_scalar_init_braces);
        return il.*.node == .none;
    }
}

fn coerceArrayInit(p: *Parser, item: *Result, tok: TokenIndex, target: Type) !bool {
    if (!target.isArray()) return false;

    const is_str_lit = p.nodeIs(item.node, .string_literal_expr);
    if (!is_str_lit and !p.nodeIs(item.node, .compound_literal_expr)) {
        try p.errTok(.array_init_str, tok);
        return true; // do not do further coercion
    }

    const target_spec = target.elemType().canonicalize(.standard).specifier;
    const item_spec = item.ty.elemType().canonicalize(.standard).specifier;

    const compatible = target.elemType().eql(item.ty.elemType(), p.pp.comp, false) or
        (is_str_lit and item_spec == .char and (target_spec == .uchar or target_spec == .schar));
    if (!compatible) {
        const e_msg = " with array of type ";
        try p.errStr(.incompatible_array_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
        return true; // do not do further coercion
    }

    if (target.get(.array)) |arr_ty| {
        assert(item.ty.specifier == .array);
        var len = item.ty.arrayLen().?;
        const array_len = arr_ty.arrayLen().?;
        if (is_str_lit) {
            // the null byte of a string can be dropped
            if (len - 1 > array_len)
                try p.errTok(.str_init_too_long, tok);
        } else if (len > array_len) {
            try p.errStr(
                .arr_init_too_long,
                tok,
                try p.typePairStrExtra(target, " with array of type ", item.ty),
            );
        }
    }
    return true;
}

fn coerceInit(p: *Parser, item: *Result, tok: TokenIndex, target: Type) !void {
    if (target.is(.void)) return; // Do not do type coercion on excess items

    // item does not need to be qualified
    var unqual_ty = target.canonicalize(.standard);
    unqual_ty.qual = .{};
    const e_msg = " from incompatible type ";
    try item.lvalConversion(p);
    if (unqual_ty.is(.bool)) {
        // this is ridiculous but it's what clang does
        if (item.ty.isInt() or item.ty.isFloat() or item.ty.isPtr()) {
            try item.boolCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
        }
    } else if (unqual_ty.isInt()) {
        if (item.ty.isInt() or item.ty.isFloat()) {
            try item.intCast(p, unqual_ty);
        } else if (item.ty.isPtr()) {
            try p.errStr(.implicit_ptr_to_int, tok, try p.typePairStrExtra(item.ty, " to ", target));
            try item.intCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
        }
    } else if (unqual_ty.isFloat()) {
        if (item.ty.isInt() or item.ty.isFloat()) {
            try item.floatCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
        }
    } else if (unqual_ty.isPtr()) {
        if (item.val.isZero()) {
            try item.nullCast(p, target);
        } else if (item.ty.isInt()) {
            try p.errStr(.implicit_int_to_ptr, tok, try p.typePairStrExtra(item.ty, " to ", target));
            try item.ptrCast(p, unqual_ty);
        } else if (item.ty.isPtr()) {
            if (!item.ty.isVoidStar() and !unqual_ty.isVoidStar() and !unqual_ty.eql(item.ty, p.pp.comp, false)) {
                try p.errStr(.incompatible_ptr_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
                try item.ptrCast(p, unqual_ty);
            } else if (!unqual_ty.eql(item.ty, p.pp.comp, true)) {
                if (!unqual_ty.elemType().qual.hasQuals(item.ty.elemType().qual)) {
                    try p.errStr(.ptr_init_discards_quals, tok, try p.typePairStrExtra(target, e_msg, item.ty));
                }
                try item.ptrCast(p, unqual_ty);
            }
        } else {
            try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
        }
    } else if (unqual_ty.isRecord()) {
        if (!unqual_ty.eql(item.ty, p.pp.comp, false))
            try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
    } else if (unqual_ty.isArray() or unqual_ty.isFunc()) {
        // we have already issued an error for this
    } else {
        try p.errStr(.incompatible_init, tok, try p.typePairStrExtra(target, e_msg, item.ty));
    }
}

fn isStringInit(p: *Parser, ty: Type) bool {
    if (!ty.isArray() or !ty.elemType().isInt()) return false;
    var i = p.tok_i;
    while (true) : (i += 1) {
        switch (p.tok_ids[i]) {
            .l_paren => {},
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            => return true,
            else => return false,
        }
    }
}

/// Convert InitList into an AST
fn convertInitList(p: *Parser, il: InitList, init_ty: Type) Error!NodeIndex {
    if (init_ty.isInt() or init_ty.isFloat() or init_ty.isPtr()) {
        if (il.node == .none) {
            return p.addNode(.{ .tag = .default_init_expr, .ty = init_ty, .data = undefined });
        }
        return il.node;
    } else if (init_ty.is(.variable_len_array)) {
        return error.ParsingFailed; // vla invalid, reported earlier
    } else if (init_ty.isArray()) {
        if (il.node != .none) {
            return il.node;
        }
        const list_buf_top = p.list_buf.items.len;
        defer p.list_buf.items.len = list_buf_top;

        const elem_ty = init_ty.elemType();

        const max_items = init_ty.arrayLen() orelse std.math.maxInt(usize);
        var start: u64 = 0;
        for (il.list.items) |*init| {
            if (init.index > start) {
                const elem = try p.addNode(.{
                    .tag = .array_filler_expr,
                    .ty = elem_ty,
                    .data = .{ .int = init.index - start },
                });
                try p.list_buf.append(elem);
            }
            start = init.index + 1;

            const elem = try p.convertInitList(init.list, elem_ty);
            try p.list_buf.append(elem);
        }

        var arr_init_node: Tree.Node = .{
            .tag = .array_init_expr_two,
            .ty = init_ty,
            .data = .{ .bin = .{ .lhs = .none, .rhs = .none } },
        };

        if (init_ty.specifier == .incomplete_array) {
            arr_init_node.ty.specifier = .array;
            arr_init_node.ty.data.array.len = start;
        } else if (init_ty.is(.incomplete_array)) {
            const arr_ty = try p.arena.create(Type.Array);
            arr_ty.* = .{ .elem = init_ty.elemType(), .len = start };
            arr_init_node.ty = .{
                .specifier = .array,
                .data = .{ .array = arr_ty },
            };
            const attrs = init_ty.getAttributes();
            arr_init_node.ty = try arr_init_node.ty.withAttributes(p.arena, attrs);
        } else if (start < max_items) {
            const elem = try p.addNode(.{
                .tag = .array_filler_expr,
                .ty = elem_ty,
                .data = .{ .int = max_items - start },
            });
            try p.list_buf.append(elem);
        }

        const items = p.list_buf.items[list_buf_top..];
        switch (items.len) {
            0 => {},
            1 => arr_init_node.data.bin.lhs = items[0],
            2 => arr_init_node.data.bin = .{ .lhs = items[0], .rhs = items[1] },
            else => {
                arr_init_node.tag = .array_init_expr;
                arr_init_node.data = .{ .range = try p.addList(items) };
            },
        }
        return try p.addNode(arr_init_node);
    } else if (init_ty.get(.@"struct")) |struct_ty| {
        assert(!struct_ty.hasIncompleteSize());

        const list_buf_top = p.list_buf.items.len;
        defer p.list_buf.items.len = list_buf_top;

        var init_index: usize = 0;
        for (struct_ty.data.record.fields) |f, i| {
            if (init_index < il.list.items.len and il.list.items[init_index].index == i) {
                const item = try p.convertInitList(il.list.items[init_index].list, f.ty);
                try p.list_buf.append(item);
                init_index += 1;
            } else {
                const item = try p.addNode(.{ .tag = .default_init_expr, .ty = f.ty, .data = undefined });
                try p.list_buf.append(item);
            }
        }

        var struct_init_node: Tree.Node = .{
            .tag = .struct_init_expr_two,
            .ty = init_ty,
            .data = .{ .bin = .{ .lhs = .none, .rhs = .none } },
        };
        const items = p.list_buf.items[list_buf_top..];
        switch (items.len) {
            0 => {},
            1 => struct_init_node.data.bin.lhs = items[0],
            2 => struct_init_node.data.bin = .{ .lhs = items[0], .rhs = items[1] },
            else => {
                struct_init_node.tag = .struct_init_expr;
                struct_init_node.data = .{ .range = try p.addList(items) };
            },
        }
        return try p.addNode(struct_init_node);
    } else if (init_ty.get(.@"union")) |union_ty| {
        var union_init_node: Tree.Node = .{
            .tag = .union_init_expr,
            .ty = init_ty,
            .data = .{ .union_init = .{ .field_index = 0, .node = .none } },
        };
        if (union_ty.data.record.fields.len == 0) {
            // do nothing for empty unions
        } else if (il.list.items.len == 0) {
            union_init_node.data.union_init.node = try p.addNode(.{
                .tag = .default_init_expr,
                .ty = init_ty,
                .data = undefined,
            });
        } else {
            const init = il.list.items[0];
            const field_ty = union_ty.data.record.fields[init.index].ty;
            union_init_node.data.union_init = .{
                .field_index = @truncate(u32, init.index),
                .node = try p.convertInitList(init.list, field_ty),
            };
        }
        return try p.addNode(union_init_node);
    } else {
        return error.ParsingFailed; // initializer target is invalid, reported earlier
    }
}

/// assembly : keyword_asm asmQual* '(' asmStr ')'
fn assembly(p: *Parser, kind: enum { global, decl_label, stmt }) Error!?NodeIndex {
    const asm_tok = p.tok_i;
    switch (p.tok_ids[p.tok_i]) {
        .keyword_asm, .keyword_asm1, .keyword_asm2 => p.tok_i += 1,
        else => return null,
    }

    var @"volatile" = false;
    var @"inline" = false;
    var goto = false;
    while (true) : (p.tok_i += 1) switch (p.tok_ids[p.tok_i]) {
        .keyword_volatile, .keyword_volatile1, .keyword_volatile2 => {
            if (kind != .stmt) try p.errStr(.meaningless_asm_qual, p.tok_i, "volatile");
            if (@"volatile") try p.errStr(.duplicate_asm_qual, p.tok_i, "volatile");
            @"volatile" = true;
        },
        .keyword_inline, .keyword_inline1, .keyword_inline2 => {
            if (kind != .stmt) try p.errStr(.meaningless_asm_qual, p.tok_i, "inline");
            if (@"inline") try p.errStr(.duplicate_asm_qual, p.tok_i, "inline");
            @"inline" = true;
        },
        .keyword_goto => {
            if (kind != .stmt) try p.errStr(.meaningless_asm_qual, p.tok_i, "goto");
            if (goto) try p.errStr(.duplicate_asm_qual, p.tok_i, "goto");
            goto = true;
        },
        else => break,
    };

    const l_paren = try p.expectToken(.l_paren);
    switch (kind) {
        .decl_label => {
            const str = (try p.asmStr()).val.data.bytes;
            const attr = Attribute{ .tag = .asm_label, .args = .{ .asm_label = .{ .name = str[0 .. str.len - 1] } } };
            try p.attr_buf.append(p.pp.comp.gpa, .{ .attr = attr, .tok = asm_tok });
        },
        .global => _ = try p.asmStr(),
        .stmt => return p.todo("assembly statements"),
    }
    try p.expectClosing(l_paren, .r_paren);

    if (kind != .decl_label) _ = try p.expectToken(.semicolon);
    return .none;
}

/// Same as stringLiteral but errors on unicode and wide string literals
fn asmStr(p: *Parser) Error!Result {
    var i = p.tok_i;
    while (true) : (i += 1) switch (p.tok_ids[i]) {
        .string_literal => {},
        .string_literal_utf_16, .string_literal_utf_8, .string_literal_utf_32 => {
            try p.errStr(.invalid_asm_str, p.tok_i, "unicode");
            return error.ParsingFailed;
        },
        .string_literal_wide => {
            try p.errStr(.invalid_asm_str, p.tok_i, "wide");
            return error.ParsingFailed;
        },
        else => break,
    };
    return try p.stringLiteral();
}

// ====== statements ======

/// stmt
///  : labeledStmt
///  | compoundStmt
///  | keyword_if '(' expr ')' stmt (keyword_else stmt)?
///  | keyword_switch '(' expr ')' stmt
///  | keyword_while '(' expr ')' stmt
///  | keyword_do stmt while '(' expr ')' ';'
///  | keyword_for '(' (decl | expr? ';') expr? ';' expr? ')' stmt
///  | keyword_goto (IDENTIFIER | ('*' expr)) ';'
///  | keyword_continue ';'
///  | keyword_break ';'
///  | keyword_return expr? ';'
///  | assembly ';'
///  | expr? ';'
fn stmt(p: *Parser) Error!NodeIndex {
    if (try p.labeledStmt()) |some| return some;
    if (try p.compoundStmt(false, null)) |some| return some;
    if (p.eatToken(.keyword_if)) |_| {
        const start_scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = start_scopes_len;

        const l_paren = try p.expectToken(.l_paren);
        var cond = try p.expr();
        try cond.expect(p);
        try cond.lvalConversion(p);
        if (cond.ty.isInt())
            try cond.intCast(p, cond.ty.integerPromotion(p.pp.comp))
        else if (!cond.ty.isFloat() and !cond.ty.isPtr())
            try p.errStr(.statement_scalar, l_paren + 1, try p.typeStr(cond.ty));
        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        const then = try p.stmt();
        const @"else" = if (p.eatToken(.keyword_else)) |_| try p.stmt() else .none;

        if (then != .none and @"else" != .none)
            return try p.addNode(.{
                .tag = .if_then_else_stmt,
                .data = .{ .if3 = .{ .cond = cond.node, .body = (try p.addList(&.{ then, @"else" })).start } },
            })
        else if (then == .none and @"else" != .none)
            return try p.addNode(.{
                .tag = .if_else_stmt,
                .data = .{ .bin = .{ .lhs = cond.node, .rhs = @"else" } },
            })
        else
            return try p.addNode(.{
                .tag = .if_then_stmt,
                .data = .{ .bin = .{ .lhs = cond.node, .rhs = then } },
            });
    }
    if (p.eatToken(.keyword_switch)) |_| {
        const start_scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = start_scopes_len;

        const l_paren = try p.expectToken(.l_paren);
        var cond = try p.expr();
        try cond.expect(p);
        try cond.lvalConversion(p);
        if (cond.ty.isInt())
            try cond.intCast(p, cond.ty.integerPromotion(p.pp.comp))
        else
            try p.errStr(.statement_int, l_paren + 1, try p.typeStr(cond.ty));
        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        var switch_scope = Scope.Switch{
            .cases = Scope.Switch.CaseMap.initContext(
                p.pp.comp.gpa,
                .{ .ty = cond.ty, .comp = p.pp.comp },
            ),
        };
        defer switch_scope.cases.deinit();
        try p.scopes.append(.{ .@"switch" = &switch_scope });
        const body = try p.stmt();

        return try p.addNode(.{
            .tag = .switch_stmt,
            .data = .{ .bin = .{ .lhs = cond.node, .rhs = body } },
        });
    }
    if (p.eatToken(.keyword_while)) |_| {
        const start_scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = start_scopes_len;

        const l_paren = try p.expectToken(.l_paren);
        var cond = try p.expr();
        try cond.expect(p);
        try cond.lvalConversion(p);
        if (cond.ty.isInt())
            try cond.intCast(p, cond.ty.integerPromotion(p.pp.comp))
        else if (!cond.ty.isFloat() and !cond.ty.isPtr())
            try p.errStr(.statement_scalar, l_paren + 1, try p.typeStr(cond.ty));
        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        try p.scopes.append(.loop);
        const body = try p.stmt();

        return try p.addNode(.{
            .tag = .while_stmt,
            .data = .{ .bin = .{ .rhs = cond.node, .lhs = body } },
        });
    }
    if (p.eatToken(.keyword_do)) |_| {
        const start_scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = start_scopes_len;

        try p.scopes.append(.loop);
        const body = try p.stmt();
        p.scopes.items.len = start_scopes_len;

        _ = try p.expectToken(.keyword_while);
        const l_paren = try p.expectToken(.l_paren);
        var cond = try p.expr();
        try cond.expect(p);
        try cond.lvalConversion(p);
        if (cond.ty.isInt())
            try cond.intCast(p, cond.ty.integerPromotion(p.pp.comp))
        else if (!cond.ty.isFloat() and !cond.ty.isPtr())
            try p.errStr(.statement_scalar, l_paren + 1, try p.typeStr(cond.ty));
        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        _ = try p.expectToken(.semicolon);
        return try p.addNode(.{
            .tag = .do_while_stmt,
            .data = .{ .bin = .{ .rhs = cond.node, .lhs = body } },
        });
    }
    if (p.eatToken(.keyword_for)) |_| {
        const start_scopes_len = p.scopes.items.len;
        defer p.scopes.items.len = start_scopes_len;
        const decl_buf_top = p.decl_buf.items.len;
        defer p.decl_buf.items.len = decl_buf_top;

        const l_paren = try p.expectToken(.l_paren);
        const got_decl = try p.decl();

        // for (init
        const init_start = p.tok_i;
        var err_start = p.pp.comp.diag.list.items.len;
        var init = if (!got_decl) try p.expr() else Result{};
        try init.saveValue(p);
        try init.maybeWarnUnused(p, init_start, err_start);
        if (!got_decl) _ = try p.expectToken(.semicolon);

        // for (init; cond
        var cond = try p.expr();
        if (cond.node != .none) {
            try cond.lvalConversion(p);
            if (cond.ty.isInt())
                try cond.intCast(p, cond.ty.integerPromotion(p.pp.comp))
            else if (!cond.ty.isFloat() and !cond.ty.isPtr())
                try p.errStr(.statement_scalar, l_paren + 1, try p.typeStr(cond.ty));
        }
        try cond.saveValue(p);
        _ = try p.expectToken(.semicolon);

        // for (init; cond; incr
        const incr_start = p.tok_i;
        err_start = p.pp.comp.diag.list.items.len;
        var incr = try p.expr();
        try incr.maybeWarnUnused(p, incr_start, err_start);
        try incr.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        try p.scopes.append(.loop);
        const body = try p.stmt();

        if (got_decl) {
            const start = (try p.addList(p.decl_buf.items[decl_buf_top..])).start;
            const end = (try p.addList(&.{ cond.node, incr.node, body })).end;

            return try p.addNode(.{
                .tag = .for_decl_stmt,
                .data = .{ .range = .{ .start = start, .end = end } },
            });
        } else if (init.node == .none and cond.node == .none and incr.node == .none) {
            return try p.addNode(.{
                .tag = .forever_stmt,
                .data = .{ .un = body },
            });
        } else return try p.addNode(.{ .tag = .for_stmt, .data = .{ .if3 = .{
            .cond = body,
            .body = (try p.addList(&.{ init.node, cond.node, incr.node })).start,
        } } });
    }
    if (p.eatToken(.keyword_goto)) |goto_tok| {
        if (p.eatToken(.asterisk)) |_| {
            const expr_tok = p.tok_i;
            var e = try p.expr();
            try e.expect(p);
            try e.lvalConversion(p);
            p.computed_goto_tok = p.computed_goto_tok orelse goto_tok;
            if (!e.ty.isPtr()) {
                if (!e.ty.isInt()) {
                    try p.errStr(.incompatible_param, expr_tok, try p.typeStr(e.ty));
                    return error.ParsingFailed;
                }
                const elem_ty = try p.arena.create(Type);
                elem_ty.* = .{ .specifier = .void, .qual = .{ .@"const" = true } };
                const result_ty = Type{
                    .specifier = .pointer,
                    .data = .{ .sub_type = elem_ty },
                };
                if (e.val.isZero()) {
                    try e.nullCast(p, result_ty);
                } else {
                    try p.errStr(.implicit_int_to_ptr, expr_tok, try p.typePairStrExtra(e.ty, " to ", result_ty));
                    try e.ptrCast(p, result_ty);
                }
            }

            try e.un(p, .computed_goto_stmt);
            _ = try p.expectToken(.semicolon);
            return e.node;
        }
        const name_tok = try p.expectIdentifier();
        const str = p.tokSlice(name_tok);
        if (p.findLabel(str) == null) {
            try p.labels.append(.{ .unresolved_goto = name_tok });
        }
        _ = try p.expectToken(.semicolon);
        return try p.addNode(.{
            .tag = .goto_stmt,
            .data = .{ .decl_ref = name_tok },
        });
    }
    if (p.eatToken(.keyword_continue)) |cont| {
        if (!p.inLoop()) try p.errTok(.continue_not_in_loop, cont);
        _ = try p.expectToken(.semicolon);
        return try p.addNode(.{ .tag = .continue_stmt, .data = undefined });
    }
    if (p.eatToken(.keyword_break)) |br| {
        if (!p.inLoopOrSwitch()) try p.errTok(.break_not_in_loop_or_switch, br);
        _ = try p.expectToken(.semicolon);
        return try p.addNode(.{ .tag = .break_stmt, .data = undefined });
    }
    if (try p.returnStmt()) |some| return some;
    if (try p.assembly(.stmt)) |some| return some;

    const expr_start = p.tok_i;
    const err_start = p.pp.comp.diag.list.items.len;

    const e = try p.expr();
    if (e.node != .none) {
        _ = try p.expectToken(.semicolon);
        try e.maybeWarnUnused(p, expr_start, err_start);
        return e.node;
    }

    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier(); // statement

    if (p.eatToken(.semicolon)) |_| {
        var null_node: Tree.Node = .{ .tag = .null_stmt, .data = undefined };
        null_node.ty = try p.withAttributes(null_node.ty, attr_buf_top);
        if (null_node.ty.getAttribute(.fallthrough) != null) {
            if (p.tok_ids[p.tok_i] != .keyword_case and p.tok_ids[p.tok_i] != .keyword_default) {
                // TODO: this condition is not completely correct; the last statement of a compound
                // statement is also valid if it precedes a switch label (so intervening '}' are ok,
                // but only if they close a compound statement)
                try p.errTok(.invalid_fallthrough, expr_start);
            }
        }
        return p.addNode(null_node);
    }

    try p.err(.expected_stmt);
    return error.ParsingFailed;
}

/// labeledStmt
/// : IDENTIFIER ':' stmt
/// | keyword_case constExpr ':' stmt
/// | keyword_default ':' stmt
fn labeledStmt(p: *Parser) Error!?NodeIndex {
    if ((p.tok_ids[p.tok_i] == .identifier or p.tok_ids[p.tok_i] == .extended_identifier) and p.tok_ids[p.tok_i + 1] == .colon) {
        const name_tok = p.expectIdentifier() catch unreachable;
        const str = p.tokSlice(name_tok);
        if (p.findLabel(str)) |some| {
            try p.errStr(.duplicate_label, name_tok, str);
            try p.errStr(.previous_label, some, str);
        } else {
            p.label_count += 1;
            try p.labels.append(.{ .label = name_tok });
            var i: usize = 0;
            while (i < p.labels.items.len) {
                if (p.labels.items[i] == .unresolved_goto and
                    mem.eql(u8, p.tokSlice(p.labels.items[i].unresolved_goto), str))
                {
                    _ = p.labels.swapRemove(i);
                } else i += 1;
            }
        }

        p.tok_i += 1;
        const attr_buf_top = p.attr_buf.len;
        defer p.attr_buf.len = attr_buf_top;
        try p.attributeSpecifier(); // label

        return try p.addNode(.{
            .tag = .labeled_stmt,
            .data = .{ .decl = .{ .name = name_tok, .node = try p.stmt() } },
        });
    } else if (p.eatToken(.keyword_case)) |case| {
        const val = try p.constExpr();
        _ = try p.expectToken(.colon);
        const s = try p.stmt();
        const node = try p.addNode(.{
            .tag = .case_stmt,
            .data = .{ .bin = .{ .lhs = val.node, .rhs = s } },
        });
        if (p.findSwitch()) |some| {
            if (val.val.tag == .unavailable) {
                try p.errTok(.case_val_unavailable, case + 1);
                return node;
            }
            // TODO cast to target type
            const gop = try some.cases.getOrPut(val);
            if (gop.found_existing) {
                if (some.cases.ctx.ty.isUnsignedInt(p.pp.comp)) {
                    try p.errExtra(.duplicate_switch_case_unsigned, case, .{
                        .unsigned = val.val.data.int,
                    });
                } else {
                    try p.errExtra(.duplicate_switch_case_signed, case, .{
                        .signed = val.val.signExtend(val.ty, p.pp.comp),
                    });
                }
                try p.errTok(.previous_case, gop.value_ptr.tok);
            } else {
                gop.value_ptr.* = .{
                    .tok = case,
                    .node = node,
                };
            }
        } else {
            try p.errStr(.case_not_in_switch, case, "case");
        }
        return node;
    } else if (p.eatToken(.keyword_default)) |default| {
        _ = try p.expectToken(.colon);
        const s = try p.stmt();
        const node = try p.addNode(.{
            .tag = .default_stmt,
            .data = .{ .un = s },
        });
        if (p.findSwitch()) |some| {
            if (some.default) |previous| {
                try p.errTok(.multiple_default, default);
                try p.errTok(.previous_case, previous.tok);
            } else {
                some.default = .{
                    .tok = default,
                    .node = node,
                };
            }
        } else {
            try p.errStr(.case_not_in_switch, default, "default");
        }
        return node;
    } else return null;
}

const StmtExprState = struct {
    last_expr_tok: TokenIndex = 0,
    last_expr_res: Result = .{ .ty = .{ .specifier = .void } },
};

/// compoundStmt : '{' ( decl | keyword_extension decl | staticAssert | stmt)* '}'
fn compoundStmt(p: *Parser, is_fn_body: bool, stmt_expr_state: ?*StmtExprState) Error!?NodeIndex {
    const l_brace = p.eatToken(.l_brace) orelse return null;

    const decl_buf_top = p.decl_buf.items.len;
    defer p.decl_buf.items.len = decl_buf_top;

    const scopes_top = p.scopes.items.len;
    defer p.scopes.items.len = scopes_top;
    // the parameters of a function are in the same scope as the body
    if (!is_fn_body) try p.scopes.append(.block);

    var noreturn_index: ?TokenIndex = null;
    var noreturn_label_count: u32 = 0;

    while (p.eatToken(.r_brace) == null) : (_ = try p.pragma()) {
        if (stmt_expr_state) |state| state.* = .{};
        if (try p.parseOrNextStmt(staticAssert, l_brace)) continue;
        if (try p.parseOrNextStmt(decl, l_brace)) continue;
        if (p.eatToken(.keyword_extension)) |ext| {
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            if (try p.parseOrNextStmt(decl, l_brace)) continue;
            p.tok_i = ext;
        }
        const stmt_tok = p.tok_i;
        const s = p.stmt() catch |er| switch (er) {
            error.ParsingFailed => {
                try p.nextStmt(l_brace);
                continue;
            },
            else => |e| return e,
        };
        if (s == .none) continue;
        if (stmt_expr_state) |state| {
            state.* = .{
                .last_expr_tok = stmt_tok,
                .last_expr_res = .{
                    .node = s,
                    .ty = p.nodes.items(.ty)[@enumToInt(s)],
                },
            };
        }
        try p.decl_buf.append(s);

        if (noreturn_index == null and p.nodeIsNoreturn(s)) {
            noreturn_index = p.tok_i;
            noreturn_label_count = p.label_count;
        }
        switch (p.nodes.items(.tag)[@enumToInt(s)]) {
            .case_stmt, .default_stmt, .labeled_stmt => noreturn_index = null,
            else => {},
        }
    }

    if (noreturn_index) |some| {
        // if new labels were defined we cannot be certain that the code is unreachable
        if (some != p.tok_i - 1 and noreturn_label_count == p.label_count) try p.errTok(.unreachable_code, some);
    }
    if (is_fn_body and (p.decl_buf.items.len == decl_buf_top or !p.nodeIsNoreturn(p.decl_buf.items[p.decl_buf.items.len - 1]))) {
        if (!p.func.ty.?.returnType().is(.void)) try p.errStr(.func_does_not_return, p.tok_i - 1, p.tokSlice(p.func.name));
        try p.decl_buf.append(try p.addNode(.{ .tag = .implicit_return, .ty = p.func.ty.?.returnType(), .data = undefined }));
    }
    if (is_fn_body) {
        if (p.func.ident) |some| try p.decl_buf.insert(decl_buf_top, some.node);
        if (p.func.pretty_ident) |some| try p.decl_buf.insert(decl_buf_top, some.node);
    }

    var node: Tree.Node = .{
        .tag = .compound_stmt_two,
        .data = .{ .bin = .{ .lhs = .none, .rhs = .none } },
    };
    const statements = p.decl_buf.items[decl_buf_top..];
    switch (statements.len) {
        0 => {},
        1 => node.data = .{ .bin = .{ .lhs = statements[0], .rhs = .none } },
        2 => node.data = .{ .bin = .{ .lhs = statements[0], .rhs = statements[1] } },
        else => {
            node.tag = .compound_stmt;
            node.data = .{ .range = try p.addList(statements) };
        },
    }
    return try p.addNode(node);
}

fn nodeIsNoreturn(p: *Parser, node: NodeIndex) bool {
    switch (p.nodes.items(.tag)[@enumToInt(node)]) {
        .break_stmt, .continue_stmt, .return_stmt => return true,
        .if_then_else_stmt => {
            const data = p.data.items[p.nodes.items(.data)[@enumToInt(node)].if3.body..];
            return p.nodeIsNoreturn(data[0]) and p.nodeIsNoreturn(data[1]);
        },
        .compound_stmt_two => {
            const data = p.nodes.items(.data)[@enumToInt(node)];
            if (data.bin.rhs != .none) return p.nodeIsNoreturn(data.bin.rhs);
            if (data.bin.lhs != .none) return p.nodeIsNoreturn(data.bin.lhs);
            return false;
        },
        .compound_stmt => {
            const data = p.nodes.items(.data)[@enumToInt(node)];
            return p.nodeIsNoreturn(p.data.items[data.range.end - 1]);
        },
        .labeled_stmt => {
            const data = p.nodes.items(.data)[@enumToInt(node)];
            return p.nodeIsNoreturn(data.decl.node);
        },
        else => return false,
    }
}

fn parseOrNextStmt(p: *Parser, comptime func: fn (*Parser) Error!bool, l_brace: TokenIndex) !bool {
    return func(p) catch |er| switch (er) {
        error.ParsingFailed => {
            try p.nextStmt(l_brace);
            return true;
        },
        else => |e| return e,
    };
}

fn nextStmt(p: *Parser, l_brace: TokenIndex) !void {
    var parens: u32 = 0;
    while (p.tok_i < p.tok_ids.len) : (p.tok_i += 1) {
        switch (p.tok_ids[p.tok_i]) {
            .l_paren, .l_brace, .l_bracket => parens += 1,
            .r_paren, .r_bracket => if (parens != 0) {
                parens -= 1;
            },
            .r_brace => if (parens == 0)
                return
            else {
                parens -= 1;
            },
            .semicolon,
            .keyword_for,
            .keyword_while,
            .keyword_do,
            .keyword_if,
            .keyword_goto,
            .keyword_switch,
            .keyword_case,
            .keyword_default,
            .keyword_continue,
            .keyword_break,
            .keyword_return,
            .keyword_typedef,
            .keyword_extern,
            .keyword_static,
            .keyword_auto,
            .keyword_register,
            .keyword_thread_local,
            .keyword_inline,
            .keyword_inline1,
            .keyword_inline2,
            .keyword_noreturn,
            .keyword_void,
            .keyword_bool,
            .keyword_char,
            .keyword_short,
            .keyword_int,
            .keyword_long,
            .keyword_signed,
            .keyword_unsigned,
            .keyword_float,
            .keyword_double,
            .keyword_complex,
            .keyword_atomic,
            .keyword_enum,
            .keyword_struct,
            .keyword_union,
            .keyword_alignas,
            .keyword_typeof,
            .keyword_typeof1,
            .keyword_typeof2,
            .keyword_extension,
            => if (parens == 0) return,
            .keyword_pragma => p.skipToPragmaSentinel(),
            else => {},
        }
    }
    p.tok_i -= 1; // So we can consume EOF
    try p.expectClosing(l_brace, .r_brace);
    unreachable;
}

fn returnStmt(p: *Parser) Error!?NodeIndex {
    const ret_tok = p.eatToken(.keyword_return) orelse return null;

    const e_tok = p.tok_i;
    var e = try p.expr();
    _ = try p.expectToken(.semicolon);
    const ret_ty = p.func.ty.?.returnType();

    if (e.node == .none) {
        if (!ret_ty.is(.void)) try p.errStr(.func_should_return, ret_tok, p.tokSlice(p.func.name));
        return try p.addNode(.{ .tag = .return_stmt, .data = .{ .un = e.node } });
    } else if (ret_ty.is(.void)) {
        try p.errStr(.void_func_returns_value, e_tok, p.tokSlice(p.func.name));
        return try p.addNode(.{ .tag = .return_stmt, .data = .{ .un = e.node } });
    }

    try e.lvalConversion(p);
    // Return type conversion is done as if it was assignment
    if (ret_ty.is(.bool)) {
        // this is ridiculous but it's what clang does
        if (e.ty.isInt() or e.ty.isFloat() or e.ty.isPtr()) {
            try e.boolCast(p, ret_ty);
        } else {
            try p.errStr(.incompatible_return, e_tok, try p.typeStr(e.ty));
        }
    } else if (ret_ty.isInt()) {
        if (e.ty.isInt() or e.ty.isFloat()) {
            try e.intCast(p, ret_ty);
        } else if (e.ty.isPtr()) {
            try p.errStr(.implicit_ptr_to_int, e_tok, try p.typePairStrExtra(e.ty, " to ", ret_ty));
            try e.intCast(p, ret_ty);
        } else {
            try p.errStr(.incompatible_return, e_tok, try p.typeStr(e.ty));
        }
    } else if (ret_ty.isFloat()) {
        if (e.ty.isInt() or e.ty.isFloat()) {
            try e.floatCast(p, ret_ty);
        } else {
            try p.errStr(.incompatible_return, e_tok, try p.typeStr(e.ty));
        }
    } else if (ret_ty.isPtr()) {
        if (e.val.isZero()) {
            try e.nullCast(p, ret_ty);
        } else if (e.ty.isInt()) {
            try p.errStr(.implicit_int_to_ptr, e_tok, try p.typePairStrExtra(e.ty, " to ", ret_ty));
            try e.intCast(p, ret_ty);
        } else if (!e.ty.isVoidStar() and !ret_ty.isVoidStar() and !ret_ty.eql(e.ty, p.pp.comp, false)) {
            try p.errStr(.incompatible_return, e_tok, try p.typeStr(e.ty));
        }
    } else if (ret_ty.isRecord()) {
        if (!ret_ty.eql(e.ty, p.pp.comp, false)) {
            try p.errStr(.incompatible_return, e_tok, try p.typeStr(e.ty));
        }
    } else if (ret_ty.isFunc()) {
        // Syntax error reported earlier; just let this return as-is since it is a parse failure anyway
    } else unreachable;

    try e.saveValue(p);
    return try p.addNode(.{ .tag = .return_stmt, .data = .{ .un = e.node } });
}

// ====== expressions ======

pub fn macroExpr(p: *Parser) Compilation.Error!bool {
    const res = p.condExpr() catch |e| switch (e) {
        error.OutOfMemory => return error.OutOfMemory,
        error.FatalError => return error.FatalError,
        error.ParsingFailed => return false,
    };
    if (res.val.tag == .unavailable) {
        try p.errTok(.expected_expr, p.tok_i);
        return false;
    }
    return res.val.getBool();
}

const Result = struct {
    node: NodeIndex = .none,
    ty: Type = .{ .specifier = .int },
    val: Value = .{},

    fn expect(res: Result, p: *Parser) Error!void {
        if (p.in_macro) {
            if (res.val.tag == .unavailable) {
                try p.errTok(.expected_expr, p.tok_i);
                return error.ParsingFailed;
            }
            return;
        }
        if (res.node == .none) {
            try p.errTok(.expected_expr, p.tok_i);
            return error.ParsingFailed;
        }
    }

    fn empty(res: Result, p: *Parser) bool {
        if (p.in_macro) return res.val.tag == .unavailable;
        return res.node == .none;
    }

    fn maybeWarnUnused(res: Result, p: *Parser, expr_start: TokenIndex, err_start: usize) Error!void {
        if (res.ty.is(.void) or res.node == .none) return;
        // don't warn about unused result if the expression contained errors besides other unused results
        var i = err_start;
        while (i < p.pp.comp.diag.list.items.len) : (i += 1) {
            if (p.pp.comp.diag.list.items[i].tag != .unused_value) return;
        }
        var cur_node = res.node;
        while (true) switch (p.nodes.items(.tag)[@enumToInt(cur_node)]) {
            .invalid, // So that we don't need to check for node == 0
            .assign_expr,
            .mul_assign_expr,
            .div_assign_expr,
            .mod_assign_expr,
            .add_assign_expr,
            .sub_assign_expr,
            .shl_assign_expr,
            .shr_assign_expr,
            .bit_and_assign_expr,
            .bit_xor_assign_expr,
            .bit_or_assign_expr,
            .call_expr,
            .call_expr_one,
            .pre_inc_expr,
            .pre_dec_expr,
            .post_inc_expr,
            .post_dec_expr,
            => return,
            .stmt_expr => {
                const body = p.nodes.items(.data)[@enumToInt(cur_node)].un;
                switch (p.nodes.items(.tag)[@enumToInt(body)]) {
                    .compound_stmt_two => {
                        const body_stmt = p.nodes.items(.data)[@enumToInt(body)].bin;
                        cur_node = if (body_stmt.rhs != .none) body_stmt.rhs else body_stmt.lhs;
                    },
                    .compound_stmt => {
                        const data = p.nodes.items(.data)[@enumToInt(body)];
                        cur_node = p.data.items[data.range.end - 1];
                    },
                    else => unreachable,
                }
            },
            .comma_expr => cur_node = p.nodes.items(.data)[@enumToInt(cur_node)].bin.rhs,
            .paren_expr => cur_node = p.nodes.items(.data)[@enumToInt(cur_node)].un,
            else => break,
        };
        try p.errTok(.unused_value, expr_start);
    }

    fn bin(lhs: *Result, p: *Parser, tag: Tree.Tag, rhs: Result) !void {
        lhs.node = try p.addNode(.{
            .tag = tag,
            .ty = lhs.ty,
            .data = .{ .bin = .{ .lhs = lhs.node, .rhs = rhs.node } },
        });
    }

    fn un(operand: *Result, p: *Parser, tag: Tree.Tag) Error!void {
        operand.node = try p.addNode(.{
            .tag = tag,
            .ty = operand.ty,
            .data = .{ .un = operand.node },
        });
    }

    fn qualCast(res: *Result, p: *Parser, elem_ty: *Type) Error!void {
        res.ty = .{
            .data = .{ .sub_type = elem_ty },
            .specifier = .pointer,
        };
        try res.un(p, .qual_cast);
    }

    fn adjustCondExprPtrs(a: *Result, tok: TokenIndex, b: *Result, p: *Parser) !bool {
        assert(a.ty.isPtr() and b.ty.isPtr());

        const a_elem = a.ty.elemType();
        const b_elem = b.ty.elemType();
        if (a_elem.eql(b_elem, p.pp.comp, true)) return true;

        var adjusted_elem_ty = try p.arena.create(Type);
        adjusted_elem_ty.* = a_elem;

        const has_void_star_branch = a.ty.isVoidStar() or b.ty.isVoidStar();
        const only_quals_differ = a_elem.eql(b_elem, p.pp.comp, false);
        const pointers_compatible = only_quals_differ or has_void_star_branch;

        if (!pointers_compatible or has_void_star_branch) {
            if (!pointers_compatible) {
                try p.errStr(.pointer_mismatch, tok, try p.typePairStrExtra(a.ty, " and ", b.ty));
            }
            adjusted_elem_ty.* = .{ .specifier = .void };
        }
        if (pointers_compatible) {
            adjusted_elem_ty.qual = a_elem.qual.mergeCV(b_elem.qual);
        }
        if (!adjusted_elem_ty.eql(a_elem, p.pp.comp, true)) try a.qualCast(p, adjusted_elem_ty);
        if (!adjusted_elem_ty.eql(b_elem, p.pp.comp, true)) try b.qualCast(p, adjusted_elem_ty);
        return true;
    }

    /// Adjust types for binary operation, returns true if the result can and should be evaluated.
    fn adjustTypes(a: *Result, tok: TokenIndex, b: *Result, p: *Parser, kind: enum {
        integer,
        arithmetic,
        boolean_logic,
        relational,
        equality,
        conditional,
        add,
        sub,
    }) !bool {
        try a.lvalConversion(p);
        try b.lvalConversion(p);

        const a_int = a.ty.isInt();
        const b_int = b.ty.isInt();
        if (a_int and b_int) {
            try a.usualArithmeticConversion(b, p);
            return a.shouldEval(b, p);
        }
        if (kind == .integer) return a.invalidBinTy(tok, b, p);

        const a_float = a.ty.isFloat();
        const b_float = b.ty.isFloat();
        const a_arithmetic = a_int or a_float;
        const b_arithmetic = b_int or b_float;
        if (a_arithmetic and b_arithmetic) {
            // <, <=, >, >= only work on real types
            if (kind == .relational and (!a.ty.isReal() or !b.ty.isReal()))
                return a.invalidBinTy(tok, b, p);

            try a.usualArithmeticConversion(b, p);
            return a.shouldEval(b, p);
        }
        if (kind == .arithmetic) return a.invalidBinTy(tok, b, p);

        const a_ptr = a.ty.isPtr();
        const b_ptr = b.ty.isPtr();
        const a_scalar = a_arithmetic or a_ptr;
        const b_scalar = b_arithmetic or b_ptr;
        switch (kind) {
            .boolean_logic => {
                if (!a_scalar or !b_scalar) return a.invalidBinTy(tok, b, p);

                // Do integer promotions but nothing else
                if (a_int) try a.intCast(p, a.ty.integerPromotion(p.pp.comp));
                if (b_int) try b.intCast(p, b.ty.integerPromotion(p.pp.comp));
                return a.shouldEval(b, p);
            },
            .relational, .equality => {
                // comparisons between floats and pointes not allowed
                if (!a_scalar or !b_scalar or (a_float and b_ptr) or (b_float and a_ptr))
                    return a.invalidBinTy(tok, b, p);

                if ((a_int or b_int) and !(a.val.isZero() or b.val.isZero())) {
                    try p.errStr(.comparison_ptr_int, tok, try p.typePairStr(a.ty, b.ty));
                } else if (a_ptr and b_ptr) {
                    if (!a.ty.isVoidStar() and !b.ty.isVoidStar() and !a.ty.eql(b.ty, p.pp.comp, false))
                        try p.errStr(.comparison_distinct_ptr, tok, try p.typePairStr(a.ty, b.ty));
                } else if (a_ptr) {
                    try b.ptrCast(p, a.ty);
                } else {
                    assert(b_ptr);
                    try a.ptrCast(p, b.ty);
                }

                return a.shouldEval(b, p);
            },
            .conditional => {
                // doesn't matter what we return here, as the result is ignored
                if (a.ty.is(.void) or b.ty.is(.void)) {
                    try a.toVoid(p);
                    try b.toVoid(p);
                    return true;
                }
                if ((a_ptr and b_int) or (a_int and b_ptr)) {
                    if (a.val.isZero() or b.val.isZero()) {
                        try a.nullCast(p, b.ty);
                        try b.nullCast(p, a.ty);
                        return true;
                    }
                    const int_ty = if (a_int) a else b;
                    const ptr_ty = if (a_ptr) a else b;
                    try p.errStr(.implicit_int_to_ptr, tok, try p.typePairStrExtra(int_ty.ty, " to ", ptr_ty.ty));
                    try int_ty.ptrCast(p, ptr_ty.ty);

                    return true;
                }
                if (a_ptr and b_ptr) return a.adjustCondExprPtrs(tok, b, p);
                if (a.ty.isRecord() and b.ty.isRecord() and a.ty.eql(b.ty, p.pp.comp, false)) {
                    return true;
                }
                return a.invalidBinTy(tok, b, p);
            },
            .add => {
                // if both aren't arithmetic one should be pointer and the other an integer
                if (a_ptr == b_ptr or a_int == b_int) return a.invalidBinTy(tok, b, p);

                // Do integer promotions but nothing else
                if (a_int) try a.intCast(p, a.ty.integerPromotion(p.pp.comp));
                if (b_int) try b.intCast(p, b.ty.integerPromotion(p.pp.comp));

                // The result type is the type of the pointer operand
                if (a_int) a.ty = b.ty else b.ty = a.ty;
                return a.shouldEval(b, p);
            },
            .sub => {
                // if both aren't arithmetic then either both should be pointers or just a
                if (!a_ptr or !(b_ptr or b_int)) return a.invalidBinTy(tok, b, p);

                if (a_ptr and b_ptr) {
                    if (!a.ty.eql(b.ty, p.pp.comp, false)) try p.errStr(.incompatible_pointers, tok, try p.typePairStr(a.ty, b.ty));
                    a.ty = p.pp.comp.types.ptrdiff;
                }

                // Do integer promotion on b if needed
                if (b_int) try b.intCast(p, b.ty.integerPromotion(p.pp.comp));
                return a.shouldEval(b, p);
            },
            else => return a.invalidBinTy(tok, b, p),
        }
    }

    fn lvalConversion(res: *Result, p: *Parser) Error!void {
        if (res.ty.isFunc()) {
            var elem_ty = try p.arena.create(Type);
            elem_ty.* = res.ty;
            res.ty.specifier = .pointer;
            res.ty.data = .{ .sub_type = elem_ty };
            try res.un(p, .function_to_pointer);
        } else if (res.ty.isArray()) {
            res.val.tag = .unavailable;
            res.ty.decayArray();
            try res.un(p, .array_to_pointer);
        } else if (!p.in_macro and Tree.isLval(p.nodes.slice(), p.data.items, p.value_map, res.node)) {
            res.val.tag = .unavailable;
            res.ty.qual = .{};
            try res.un(p, .lval_to_rval);
        }
    }

    fn boolCast(res: *Result, p: *Parser, bool_ty: Type) Error!void {
        if (res.ty.isPtr()) {
            res.val.toBool();
            res.ty = bool_ty;
            try res.un(p, .pointer_to_bool);
        } else if (res.ty.isInt() and !res.ty.is(.bool)) {
            res.val.toBool();
            res.ty = bool_ty;
            try res.un(p, .int_to_bool);
        } else if (res.ty.isFloat()) {
            res.val.floatToInt(res.ty, bool_ty, p.pp.comp);
            res.ty = bool_ty;
            try res.un(p, .float_to_bool);
        }
    }

    fn intCast(res: *Result, p: *Parser, int_ty: Type) Error!void {
        if (res.ty.is(.bool)) {
            res.ty = int_ty;
            try res.un(p, .bool_to_int);
        } else if (res.ty.isPtr()) {
            res.ty = int_ty;
            try res.un(p, .pointer_to_int);
        } else if (res.ty.isFloat()) {
            res.val.floatToInt(res.ty, int_ty, p.pp.comp);
            res.ty = int_ty;
            try res.un(p, .float_to_int);
        } else if (!res.ty.eql(int_ty, p.pp.comp, true)) {
            if (int_ty.hasIncompleteSize()) return error.ParsingFailed; // Diagnostic already issued
            res.val.intCast(res.ty, int_ty, p.pp.comp);
            res.ty = int_ty;
            try res.un(p, .int_cast);
        }
    }

    fn floatCast(res: *Result, p: *Parser, float_ty: Type) Error!void {
        if (res.ty.is(.bool)) {
            res.val.intToFloat(res.ty, float_ty, p.pp.comp);
            res.ty = float_ty;
            try res.un(p, .bool_to_float);
        } else if (res.ty.isInt()) {
            res.val.intToFloat(res.ty, float_ty, p.pp.comp);
            res.ty = float_ty;
            try res.un(p, .int_to_float);
        } else if (!res.ty.eql(float_ty, p.pp.comp, true)) {
            res.val.floatCast(res.ty, float_ty, p.pp.comp);
            res.ty = float_ty;
            try res.un(p, .float_cast);
        }
    }

    fn ptrCast(res: *Result, p: *Parser, ptr_ty: Type) Error!void {
        if (res.ty.is(.bool)) {
            res.ty = ptr_ty;
            try res.un(p, .bool_to_pointer);
        } else if (res.ty.isInt()) {
            res.val.intCast(res.ty, ptr_ty, p.pp.comp);
            res.ty = ptr_ty;
            try res.un(p, .int_to_pointer);
        }
    }

    fn toVoid(res: *Result, p: *Parser) Error!void {
        if (!res.ty.is(.void)) {
            res.ty = .{ .specifier = .void };
            res.node = try p.addNode(.{
                .tag = .to_void,
                .ty = res.ty,
                .data = .{ .un = res.node },
            });
        }
    }

    fn nullCast(res: *Result, p: *Parser, ptr_ty: Type) Error!void {
        if (!res.val.isZero()) return;
        res.ty = ptr_ty;
        try res.un(p, .null_to_pointer);
    }

    fn usualArithmeticConversion(a: *Result, b: *Result, p: *Parser) Error!void {
        // if either is a float cast to that type
        const float_types = [3][2]Type.Specifier{
            .{ .complex_long_double, .long_double },
            .{ .complex_double, .double },
            .{ .complex_float, .float },
        };
        const a_spec = a.ty.canonicalize(.standard).specifier;
        const b_spec = b.ty.canonicalize(.standard).specifier;
        for (float_types) |pair| {
            if (a_spec == pair[0] or a_spec == pair[1] or
                b_spec == pair[0] or b_spec == pair[1])
            {
                const both_real = a.ty.isReal() and b.ty.isReal();
                const res_spec = pair[@boolToInt(both_real)];
                const ty = Type{ .specifier = res_spec };
                try a.floatCast(p, ty);
                try b.floatCast(p, ty);
                return;
            }
        }

        // Do integer promotion on both operands
        const a_promoted = a.ty.integerPromotion(p.pp.comp);
        const b_promoted = b.ty.integerPromotion(p.pp.comp);
        if (a_promoted.eql(b_promoted, p.pp.comp, true)) {
            // cast to promoted type
            try a.intCast(p, a_promoted);
            try b.intCast(p, a_promoted);
            return;
        }

        const a_unsigned = a_promoted.isUnsignedInt(p.pp.comp);
        const b_unsigned = b_promoted.isUnsignedInt(p.pp.comp);
        if (a_unsigned == b_unsigned) {
            // cast to greater signed or unsigned type
            const res_spec = std.math.max(@enumToInt(a_promoted.specifier), @enumToInt(b_promoted.specifier));
            const res_ty = Type{ .specifier = @intToEnum(Type.Specifier, res_spec) };
            try a.intCast(p, res_ty);
            try b.intCast(p, res_ty);
            return;
        }

        // cast to the unsigned type with greater rank
        const a_larger = @enumToInt(a_promoted.specifier) > @enumToInt(b_promoted.specifier);
        const b_larger = @enumToInt(b_promoted.specifier) > @enumToInt(b_promoted.specifier);
        if (a_unsigned) {
            const target = if (a_larger) a_promoted else b_promoted;
            try a.intCast(p, target);
            try b.intCast(p, target);
        } else {
            assert(b_unsigned);
            const target = if (b_larger) b_promoted else a_promoted;
            try a.intCast(p, target);
            try b.intCast(p, target);
        }
    }

    fn invalidBinTy(a: *Result, tok: TokenIndex, b: *Result, p: *Parser) Error!bool {
        try p.errStr(.invalid_bin_types, tok, try p.typePairStr(a.ty, b.ty));
        return false;
    }

    fn shouldEval(a: *Result, b: *Result, p: *Parser) Error!bool {
        if (p.no_eval) return false;
        if (a.val.tag != .unavailable and b.val.tag != .unavailable)
            return true;

        try a.saveValue(p);
        try b.saveValue(p);
        return p.no_eval;
    }

    /// Saves value and replaces it with `.unavailable`.
    fn saveValue(res: *Result, p: *Parser) !void {
        assert(!p.in_macro);
        if (res.val.tag == .unavailable) return;
        if (!p.in_macro) try p.value_map.put(res.node, res.val);
        res.val.tag = .unavailable;
    }
};

/// expr : assignExpr (',' assignExpr)*
fn expr(p: *Parser) Error!Result {
    var expr_start = p.tok_i;
    var err_start = p.pp.comp.diag.list.items.len;
    var lhs = try p.assignExpr();
    if (p.tok_ids[p.tok_i] == .comma) try lhs.expect(p);
    while (p.eatToken(.comma)) |_| {
        try lhs.maybeWarnUnused(p, expr_start, err_start);
        expr_start = p.tok_i;
        err_start = p.pp.comp.diag.list.items.len;

        const rhs = try p.assignExpr();
        try rhs.expect(p);
        lhs.val = rhs.val;
        lhs.ty = rhs.ty;
        try lhs.bin(p, .comma_expr, rhs);
    }
    return lhs;
}

fn tokToTag(p: *Parser, tok: TokenIndex) Tree.Tag {
    return switch (p.tok_ids[tok]) {
        .equal => .assign_expr,
        .asterisk_equal => .mul_assign_expr,
        .slash_equal => .div_assign_expr,
        .percent_equal => .mod_assign_expr,
        .plus_equal => .add_assign_expr,
        .minus_equal => .sub_assign_expr,
        .angle_bracket_angle_bracket_left_equal => .shl_assign_expr,
        .angle_bracket_angle_bracket_right_equal => .shr_assign_expr,
        .ampersand_equal => .bit_and_assign_expr,
        .caret_equal => .bit_xor_assign_expr,
        .pipe_equal => .bit_or_assign_expr,
        .equal_equal => .equal_expr,
        .bang_equal => .not_equal_expr,
        .angle_bracket_left => .less_than_expr,
        .angle_bracket_left_equal => .less_than_equal_expr,
        .angle_bracket_right => .greater_than_expr,
        .angle_bracket_right_equal => .greater_than_equal_expr,
        .angle_bracket_angle_bracket_left => .shl_expr,
        .angle_bracket_angle_bracket_right => .shr_expr,
        .plus => .add_expr,
        .minus => .sub_expr,
        .asterisk => .mul_expr,
        .slash => .div_expr,
        .percent => .mod_expr,
        else => unreachable,
    };
}

/// assignExpr
///  : condExpr
///  | unExpr ('=' | '*=' | '/=' | '%=' | '+=' | '-=' | '<<=' | '>>=' | '&=' | '^=' | '|=') assignExpr
fn assignExpr(p: *Parser) Error!Result {
    var lhs = try p.condExpr();
    if (lhs.empty(p)) return lhs;

    const tok = p.tok_i;
    const eq = p.eatToken(.equal);
    const mul = eq orelse p.eatToken(.asterisk_equal);
    const div = mul orelse p.eatToken(.slash_equal);
    const mod = div orelse p.eatToken(.percent_equal);
    const add = mod orelse p.eatToken(.plus_equal);
    const sub = add orelse p.eatToken(.minus_equal);
    const shl = sub orelse p.eatToken(.angle_bracket_angle_bracket_left_equal);
    const shr = shl orelse p.eatToken(.angle_bracket_angle_bracket_right_equal);
    const bit_and = shr orelse p.eatToken(.ampersand_equal);
    const bit_xor = bit_and orelse p.eatToken(.caret_equal);
    const bit_or = bit_xor orelse p.eatToken(.pipe_equal);

    const tag = p.tokToTag(bit_or orelse return lhs);
    var rhs = try p.assignExpr();
    try rhs.expect(p);
    try rhs.lvalConversion(p);

    var is_const: bool = undefined;
    if (!Tree.isLvalExtra(p.nodes.slice(), p.data.items, p.value_map, lhs.node, &is_const) or is_const) {
        try p.errTok(.not_assignable, tok);
        return error.ParsingFailed;
    }

    // adjustTypes will do do lvalue conversion but we do not want that
    var lhs_copy = lhs;
    switch (tag) {
        .assign_expr => {}, // handle plain assignment separately
        .mul_assign_expr,
        .div_assign_expr,
        .mod_assign_expr,
        => {
            if (rhs.val.isZero()) {
                switch (tag) {
                    .div_assign_expr => try p.errStr(.division_by_zero, div.?, "division"),
                    .mod_assign_expr => try p.errStr(.division_by_zero, mod.?, "remainder"),
                    else => {},
                }
            }
            _ = try lhs_copy.adjustTypes(tok, &rhs, p, .arithmetic);
            try lhs.bin(p, tag, rhs);
            return lhs;
        },
        .sub_assign_expr,
        .add_assign_expr,
        => {
            if (lhs.ty.isPtr() and rhs.ty.isInt()) {
                try rhs.ptrCast(p, lhs.ty);
            } else {
                _ = try lhs_copy.adjustTypes(tok, &rhs, p, .arithmetic);
            }
            try lhs.bin(p, tag, rhs);
            return lhs;
        },
        .shl_assign_expr,
        .shr_assign_expr,
        .bit_and_assign_expr,
        .bit_xor_assign_expr,
        .bit_or_assign_expr,
        => {
            _ = try lhs_copy.adjustTypes(tok, &rhs, p, .integer);
            try lhs.bin(p, tag, rhs);
            return lhs;
        },
        else => unreachable,
    }

    // rhs does not need to be qualified
    var unqual_ty = lhs.ty.canonicalize(.standard);
    unqual_ty.qual = .{};
    const e_msg = " from incompatible type ";
    if (lhs.ty.is(.bool)) {
        // this is ridiculous but it's what clang does
        if (rhs.ty.isInt() or rhs.ty.isFloat() or rhs.ty.isPtr()) {
            try rhs.boolCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
        }
    } else if (unqual_ty.isInt()) {
        if (rhs.ty.isInt() or rhs.ty.isFloat()) {
            try rhs.intCast(p, unqual_ty);
        } else if (rhs.ty.isPtr()) {
            try p.errStr(.implicit_ptr_to_int, tok, try p.typePairStrExtra(rhs.ty, " to ", lhs.ty));
            try rhs.intCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
        }
    } else if (unqual_ty.isFloat()) {
        if (rhs.ty.isInt() or rhs.ty.isFloat()) {
            try rhs.floatCast(p, unqual_ty);
        } else {
            try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
        }
    } else if (unqual_ty.isPtr()) {
        if (rhs.val.isZero()) {
            try rhs.nullCast(p, lhs.ty);
        } else if (rhs.ty.isInt()) {
            try p.errStr(.implicit_int_to_ptr, tok, try p.typePairStrExtra(rhs.ty, " to ", lhs.ty));
            try rhs.ptrCast(p, unqual_ty);
        } else if (rhs.ty.isPtr()) {
            if (!unqual_ty.isVoidStar() and !rhs.ty.isVoidStar() and !unqual_ty.eql(rhs.ty, p.pp.comp, false)) {
                try p.errStr(.incompatible_ptr_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
                try rhs.ptrCast(p, unqual_ty);
            } else if (!unqual_ty.eql(rhs.ty, p.pp.comp, true)) {
                if (!unqual_ty.elemType().qual.hasQuals(rhs.ty.elemType().qual)) {
                    try p.errStr(.ptr_assign_discards_quals, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
                }
                try rhs.ptrCast(p, unqual_ty);
            }
        } else {
            try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
        }
    } else if (unqual_ty.isRecord()) {
        if (!unqual_ty.eql(rhs.ty, p.pp.comp, false))
            try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
    } else if (unqual_ty.isArray() or unqual_ty.isFunc()) {
        try p.errTok(.not_assignable, tok);
    } else {
        try p.errStr(.incompatible_assign, tok, try p.typePairStrExtra(lhs.ty, e_msg, rhs.ty));
    }

    try lhs.bin(p, tag, rhs);
    return lhs;
}

/// constExpr : condExpr
fn constExpr(p: *Parser) Error!Result {
    const start = p.tok_i;
    const res = try p.condExpr();
    try res.expect(p);
    if (!res.ty.isInt()) {
        try p.errTok(.expected_integer_constant_expr, start);
        return error.ParsingFailed;
    }
    // saveValue sets val to unavailable
    var copy = res;
    try copy.saveValue(p);
    return res;
}

/// condExpr : lorExpr ('?' expression? ':' condExpr)?
fn condExpr(p: *Parser) Error!Result {
    var cond = try p.lorExpr();
    if (cond.empty(p) or p.eatToken(.question_mark) == null) return cond;
    const saved_eval = p.no_eval;

    // Depending on the value of the condition, avoid evaluating unreachable branches.
    var then_expr = blk: {
        defer p.no_eval = saved_eval;
        if (cond.val.tag != .unavailable and !cond.val.getBool()) p.no_eval = true;
        break :blk try p.expr();
    };
    try then_expr.expect(p); // TODO binary cond expr
    const colon = try p.expectToken(.colon);
    var else_expr = blk: {
        defer p.no_eval = saved_eval;
        if (cond.val.tag != .unavailable and cond.val.getBool()) p.no_eval = true;
        break :blk try p.condExpr();
    };
    try else_expr.expect(p);

    _ = try then_expr.adjustTypes(colon, &else_expr, p, .conditional);

    if (cond.val.tag != .unavailable) {
        cond.val = if (cond.val.getBool()) then_expr.val else else_expr.val;
    } else {
        try then_expr.saveValue(p);
        try else_expr.saveValue(p);
    }
    cond.ty = then_expr.ty;
    cond.node = try p.addNode(.{
        .tag = .cond_expr,
        .ty = cond.ty,
        .data = .{ .if3 = .{ .cond = cond.node, .body = (try p.addList(&.{ then_expr.node, else_expr.node })).start } },
    });
    return cond;
}

/// lorExpr : landExpr ('||' landExpr)*
fn lorExpr(p: *Parser) Error!Result {
    var lhs = try p.landExpr();
    if (lhs.empty(p)) return lhs;
    const saved_eval = p.no_eval;
    defer p.no_eval = saved_eval;

    while (p.eatToken(.pipe_pipe)) |tok| {
        if (lhs.val.tag != .unavailable and lhs.val.getBool()) p.no_eval = true;
        var rhs = try p.landExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(tok, &rhs, p, .boolean_logic)) {
            const res = @boolToInt(lhs.val.getBool() or rhs.val.getBool());
            lhs.val = Value.int(res);
        }
        lhs.ty = .{ .specifier = .int };
        try lhs.bin(p, .bool_or_expr, rhs);
    }
    return lhs;
}

/// landExpr : orExpr ('&&' orExpr)*
fn landExpr(p: *Parser) Error!Result {
    var lhs = try p.orExpr();
    if (lhs.empty(p)) return lhs;
    const saved_eval = p.no_eval;
    defer p.no_eval = saved_eval;

    while (p.eatToken(.ampersand_ampersand)) |tok| {
        if (lhs.val.tag != .unavailable and !lhs.val.getBool()) p.no_eval = true;
        var rhs = try p.orExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(tok, &rhs, p, .boolean_logic)) {
            const res = @boolToInt(lhs.val.getBool() and rhs.val.getBool());
            lhs.val = Value.int(res);
        }
        lhs.ty = .{ .specifier = .int };
        try lhs.bin(p, .bool_and_expr, rhs);
    }
    return lhs;
}

/// orExpr : xorExpr ('|' xorExpr)*
fn orExpr(p: *Parser) Error!Result {
    var lhs = try p.xorExpr();
    if (lhs.empty(p)) return lhs;
    while (p.eatToken(.pipe)) |tok| {
        var rhs = try p.xorExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = lhs.val.bitOr(rhs.val, lhs.ty, p.pp.comp);
        }
        try lhs.bin(p, .bit_or_expr, rhs);
    }
    return lhs;
}

/// xorExpr : andExpr ('^' andExpr)*
fn xorExpr(p: *Parser) Error!Result {
    var lhs = try p.andExpr();
    if (lhs.empty(p)) return lhs;
    while (p.eatToken(.caret)) |tok| {
        var rhs = try p.andExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = lhs.val.bitXor(rhs.val, lhs.ty, p.pp.comp);
        }
        try lhs.bin(p, .bit_xor_expr, rhs);
    }
    return lhs;
}

/// andExpr : eqExpr ('&' eqExpr)*
fn andExpr(p: *Parser) Error!Result {
    var lhs = try p.eqExpr();
    if (lhs.empty(p)) return lhs;
    while (p.eatToken(.ampersand)) |tok| {
        var rhs = try p.eqExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = lhs.val.bitAnd(rhs.val, lhs.ty, p.pp.comp);
        }
        try lhs.bin(p, .bit_and_expr, rhs);
    }
    return lhs;
}

/// eqExpr : compExpr (('==' | '!=') compExpr)*
fn eqExpr(p: *Parser) Error!Result {
    var lhs = try p.compExpr();
    if (lhs.empty(p)) return lhs;
    while (true) {
        const eq = p.eatToken(.equal_equal);
        const ne = eq orelse p.eatToken(.bang_equal);
        const tag = p.tokToTag(ne orelse break);
        var rhs = try p.compExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(ne.?, &rhs, p, .equality)) {
            const op: std.math.CompareOperator = if (tag == .equal_expr) .eq else .neq;
            const res = lhs.val.compare(op, rhs.val, lhs.ty, p.pp.comp);
            lhs.val = Value.int(@boolToInt(res));
        }
        lhs.ty = .{ .specifier = .int };
        try lhs.bin(p, tag, rhs);
    }
    return lhs;
}

/// compExpr : shiftExpr (('<' | '<=' | '>' | '>=') shiftExpr)*
fn compExpr(p: *Parser) Error!Result {
    var lhs = try p.shiftExpr();
    if (lhs.empty(p)) return lhs;
    while (true) {
        const lt = p.eatToken(.angle_bracket_left);
        const le = lt orelse p.eatToken(.angle_bracket_left_equal);
        const gt = le orelse p.eatToken(.angle_bracket_right);
        const ge = gt orelse p.eatToken(.angle_bracket_right_equal);
        const tag = p.tokToTag(ge orelse break);
        var rhs = try p.shiftExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(ge.?, &rhs, p, .relational)) {
            const op: std.math.CompareOperator = switch (tag) {
                .less_than_expr => .lt,
                .less_than_equal_expr => .lte,
                .greater_than_expr => .gt,
                .greater_than_equal_expr => .gte,
                else => unreachable,
            };
            const res = lhs.val.compare(op, rhs.val, lhs.ty, p.pp.comp);
            lhs.val = Value.int(@boolToInt(res));
        }
        lhs.ty = .{ .specifier = .int };
        try lhs.bin(p, tag, rhs);
    }
    return lhs;
}

/// shiftExpr : addExpr (('<<' | '>>') addExpr)*
fn shiftExpr(p: *Parser) Error!Result {
    var lhs = try p.addExpr();
    if (lhs.empty(p)) return lhs;
    while (true) {
        const shl = p.eatToken(.angle_bracket_angle_bracket_left);
        const shr = shl orelse p.eatToken(.angle_bracket_angle_bracket_right);
        const tag = p.tokToTag(shr orelse break);
        var rhs = try p.addExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(shr.?, &rhs, p, .integer)) {
            if (shl != null) {
                lhs.val = lhs.val.shl(rhs.val, lhs.ty, p.pp.comp);
            } else {
                lhs.val = lhs.val.shr(rhs.val, lhs.ty, p.pp.comp);
            }
        }
        try lhs.bin(p, tag, rhs);
    }
    return lhs;
}

/// addExpr : mulExpr (('+' | '-') mulExpr)*
fn addExpr(p: *Parser) Error!Result {
    var lhs = try p.mulExpr();
    if (lhs.empty(p)) return lhs;
    while (true) {
        const plus = p.eatToken(.plus);
        const minus = plus orelse p.eatToken(.minus);
        const tag = p.tokToTag(minus orelse break);
        var rhs = try p.mulExpr();
        try rhs.expect(p);

        if (try lhs.adjustTypes(minus.?, &rhs, p, if (plus != null) .add else .sub)) {
            if (plus != null) {
                if (lhs.val.add(lhs.val, rhs.val, lhs.ty, p.pp.comp)) try p.errOverflow(plus.?, lhs);
            } else {
                if (lhs.val.sub(lhs.val, rhs.val, lhs.ty, p.pp.comp)) try p.errOverflow(minus.?, lhs);
            }
        }
        try lhs.bin(p, tag, rhs);
    }
    return lhs;
}

/// mulExpr : castExpr (('*' | '/' | '%') castExpr)*´
fn mulExpr(p: *Parser) Error!Result {
    var lhs = try p.castExpr();
    if (lhs.empty(p)) return lhs;
    while (true) {
        const mul = p.eatToken(.asterisk);
        const div = mul orelse p.eatToken(.slash);
        const percent = div orelse p.eatToken(.percent);
        const tag = p.tokToTag(percent orelse break);
        var rhs = try p.castExpr();
        try rhs.expect(p);

        if (rhs.val.isZero() and mul == null and !p.no_eval) {
            const err_tag: Diagnostics.Tag = if (p.in_macro) .division_by_zero_macro else .division_by_zero;
            lhs.val.tag = .unavailable;
            if (div != null) {
                try p.errStr(err_tag, div.?, "division");
            } else {
                try p.errStr(err_tag, percent.?, "remainder");
            }
            if (p.in_macro) return error.ParsingFailed;
        }

        if (try lhs.adjustTypes(percent.?, &rhs, p, if (tag == .mod_expr) .integer else .arithmetic)) {
            if (mul != null) {
                if (lhs.val.mul(lhs.val, rhs.val, lhs.ty, p.pp.comp)) try p.errOverflow(mul.?, lhs);
            } else if (div != null) {
                lhs.val = Value.div(lhs.val, rhs.val, lhs.ty, p.pp.comp);
            } else {
                var res = Value.rem(lhs.val, rhs.val, lhs.ty, p.pp.comp);
                if (res.tag == .unavailable) {
                    if (p.in_macro) {
                        // match clang behavior by defining invalid remainder to be zero in macros
                        res = Value.int(0);
                    } else {
                        try lhs.saveValue(p);
                        try rhs.saveValue(p);
                    }
                }
                lhs.val = res;
            }
        }

        try lhs.bin(p, tag, rhs);
    }
    return lhs;
}

/// This will always be the last message, if present
fn removeUnusedWarningForTok(p: *Parser, last_expr_tok: TokenIndex) void {
    if (last_expr_tok == 0) return;
    if (p.pp.comp.diag.list.items.len == 0) return;

    const last_expr_loc = p.pp.tokens.items(.loc)[last_expr_tok];
    const last_msg = p.pp.comp.diag.list.items[p.pp.comp.diag.list.items.len - 1];

    if (last_msg.tag == .unused_value and last_msg.loc.eql(last_expr_loc)) {
        p.pp.comp.diag.list.items.len = p.pp.comp.diag.list.items.len - 1;
    }
}

/// castExpr
///  :  '(' compoundStmt ')'
///  |  '(' typeName ')' castExpr
///  | '(' typeName ')' '{' initializerItems '}'
///  | __builtin_choose_expr '(' constExpr ',' assignExpr ',' assignExpr ')'
///  | __builtin_va_arg '(' assignExpr ',' typeName ')'
///  | unExpr
fn castExpr(p: *Parser) Error!Result {
    if (p.eatToken(.l_paren)) |l_paren| cast_expr: {
        if (p.tok_ids[p.tok_i] == .l_brace) {
            try p.err(.gnu_statement_expression);
            if (p.func.ty == null) {
                try p.err(.stmt_expr_not_allowed_file_scope);
                return error.ParsingFailed;
            }
            var stmt_expr_state: StmtExprState = .{};
            const body_node = (try p.compoundStmt(false, &stmt_expr_state)).?; // compoundStmt only returns null if .l_brace isn't the first token
            p.removeUnusedWarningForTok(stmt_expr_state.last_expr_tok);

            var res = Result{
                .node = body_node,
                .ty = stmt_expr_state.last_expr_res.ty,
                .val = stmt_expr_state.last_expr_res.val,
            };
            try p.expectClosing(l_paren, .r_paren);
            try res.un(p, .stmt_expr);
            return res;
        }
        const ty = (try p.typeName()) orelse {
            p.tok_i -= 1;
            break :cast_expr;
        };
        try p.expectClosing(l_paren, .r_paren);

        if (p.tok_ids[p.tok_i] == .l_brace) {
            // compound literal
            if (ty.isFunc()) {
                try p.err(.func_init);
            } else if (ty.is(.variable_len_array)) {
                try p.err(.vla_init);
            } else if (ty.hasIncompleteSize() and !ty.is(.incomplete_array)) {
                try p.errStr(.variable_incomplete_ty, p.tok_i, try p.typeStr(ty));
                return error.ParsingFailed;
            }
            var init_list_expr = try p.initializer(ty);
            try init_list_expr.un(p, .compound_literal_expr);
            return init_list_expr;
        }

        var operand = try p.castExpr();
        try operand.expect(p);
        if (ty.is(.void)) {
            // everything can cast to void
            operand.val.tag = .unavailable;
        } else if (ty.isInt() or ty.isFloat() or ty.isPtr()) cast: {
            const old_float = operand.ty.isFloat();
            const new_float = ty.isFloat();

            if (new_float and operand.ty.isPtr()) {
                try p.errStr(.invalid_cast_to_float, l_paren, try p.typeStr(operand.ty));
                return error.ParsingFailed;
            } else if (old_float and ty.isPtr()) {
                try p.errStr(.invalid_cast_to_pointer, l_paren, try p.typeStr(operand.ty));
                return error.ParsingFailed;
            }
            if (operand.val.tag == .unavailable) break :cast;

            const old_int = operand.ty.isInt() or operand.ty.isPtr();
            const new_int = ty.isInt() or ty.isPtr();
            if (ty.is(.bool)) {
                operand.val.toBool();
            } else if (old_float and new_int) {
                operand.val.floatToInt(operand.ty, ty, p.pp.comp);
            } else if (new_float and old_int) {
                operand.val.intToFloat(operand.ty, ty, p.pp.comp);
            } else if (new_float and old_float) {
                operand.val.floatCast(operand.ty, ty, p.pp.comp);
            }
        } else {
            try p.errStr(.invalid_cast_type, l_paren, try p.typeStr(operand.ty));
            return error.ParsingFailed;
        }
        if (ty.anyQual()) try p.errStr(.qual_cast, l_paren, try p.typeStr(ty));
        operand.ty = ty;
        operand.ty.qual = .{};
        try operand.un(p, .cast_expr);
        return operand;
    }
    switch (p.tok_ids[p.tok_i]) {
        .builtin_choose_expr => return p.builtinChooseExpr(),
        .builtin_va_arg => return p.builtinVaArg(),
        // TODO: other special-cased builtins
        else => {},
    }
    return p.unExpr();
}

fn builtinChooseExpr(p: *Parser) Error!Result {
    p.tok_i += 1;
    const l_paren = try p.expectToken(.l_paren);
    const cond_tok = p.tok_i;
    var cond = try p.constExpr();
    if (cond.val.tag == .unavailable) {
        try p.errTok(.builtin_choose_cond, cond_tok);
        return error.ParsingFailed;
    }

    _ = try p.expectToken(.comma);

    var then_expr = if (cond.val.getBool()) try p.assignExpr() else try p.parseNoEval(assignExpr);
    try then_expr.expect(p);

    _ = try p.expectToken(.comma);

    var else_expr = if (!cond.val.getBool()) try p.assignExpr() else try p.parseNoEval(assignExpr);
    try else_expr.expect(p);

    try p.expectClosing(l_paren, .r_paren);

    if (cond.val.getBool()) {
        cond.val = then_expr.val;
        cond.ty = then_expr.ty;
    } else {
        cond.val = else_expr.val;
        cond.ty = else_expr.ty;
    }
    cond.node = try p.addNode(.{
        .tag = .builtin_choose_expr,
        .ty = cond.ty,
        .data = .{ .if3 = .{ .cond = cond.node, .body = (try p.addList(&.{ then_expr.node, else_expr.node })).start } },
    });
    return cond;
}

fn builtinVaArg(p: *Parser) Error!Result {
    const builtin_tok = p.tok_i;
    p.tok_i += 1;

    const l_paren = try p.expectToken(.l_paren);
    const va_list_tok = p.tok_i;
    var va_list = try p.assignExpr();
    try va_list.expect(p);
    try va_list.lvalConversion(p);

    _ = try p.expectToken(.comma);

    const ty = (try p.typeName()) orelse {
        try p.err(.expected_type);
        return error.ParsingFailed;
    };
    try p.expectClosing(l_paren, .r_paren);

    if (!va_list.ty.eql(p.pp.comp.types.va_list, p.pp.comp, true)) {
        try p.errStr(.incompatible_va_arg, va_list_tok, try p.typeStr(va_list.ty));
        return error.ParsingFailed;
    }

    return Result{ .ty = ty, .node = try p.addNode(.{
        .tag = .builtin_call_expr_one,
        .ty = ty,
        .data = .{ .decl = .{ .name = builtin_tok, .node = va_list.node } },
    }) };
}

/// unExpr
///  : primaryExpr suffixExpr*
///  | '&&' IDENTIFIER
///  | ('&' | '*' | '+' | '-' | '~' | '!' | '++' | '--' | keyword_extension) castExpr
///  | keyword_sizeof unExpr
///  | keyword_sizeof '(' typeName ')'
///  | keyword_alignof '(' typeName ')'
fn unExpr(p: *Parser) Error!Result {
    const tok = p.tok_i;
    switch (p.tok_ids[tok]) {
        .ampersand_ampersand => {
            const address_tok = p.tok_i;
            p.tok_i += 1;
            const name_tok = try p.expectIdentifier();
            try p.errTok(.gnu_label_as_value, address_tok);
            p.contains_address_of_label = true;

            const str = p.tokSlice(name_tok);
            if (p.findLabel(str) == null) {
                try p.labels.append(.{ .unresolved_goto = name_tok });
            }
            const elem_ty = try p.arena.create(Type);
            elem_ty.* = .{ .specifier = .void };
            const result_ty = Type{ .specifier = .pointer, .data = .{ .sub_type = elem_ty } };
            return Result{
                .node = try p.addNode(.{
                    .tag = .addr_of_label,
                    .data = .{ .decl_ref = name_tok },
                    .ty = result_ty,
                }),
                .ty = result_ty,
            };
        },
        .ampersand => {
            if (p.in_macro) {
                try p.err(.invalid_preproc_operator);
                return error.ParsingFailed;
            }
            p.tok_i += 1;
            var operand = try p.castExpr();
            try operand.expect(p);

            const slice = p.nodes.slice();
            if (!Tree.isLval(slice, p.data.items, p.value_map, operand.node)) {
                try p.errTok(.addr_of_rvalue, tok);
            }
            if (operand.ty.qual.register) try p.errTok(.addr_of_register, tok);

            const elem_ty = try p.arena.create(Type);
            elem_ty.* = operand.ty;
            operand.ty = Type{
                .specifier = .pointer,
                .data = .{ .sub_type = elem_ty },
            };
            try operand.saveValue(p);
            try operand.un(p, .addr_of_expr);
            return operand;
        },
        .asterisk => {
            const asterisk_loc = p.tok_i;
            p.tok_i += 1;
            var operand = try p.castExpr();
            try operand.expect(p);

            if (operand.ty.isArray() or operand.ty.isPtr()) {
                operand.ty = operand.ty.elemType();
            } else if (!operand.ty.isFunc()) {
                try p.errTok(.indirection_ptr, tok);
            }
            if (operand.ty.hasIncompleteSize() and !operand.ty.is(.void)) {
                try p.errStr(.deref_incomplete_ty_ptr, asterisk_loc, try p.typeStr(operand.ty));
            }
            operand.ty.qual = .{};
            try operand.un(p, .deref_expr);
            return operand;
        },
        .plus => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            try operand.lvalConversion(p);
            if (!operand.ty.isInt() and !operand.ty.isFloat())
                try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));

            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));
            return operand;
        },
        .minus => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            try operand.lvalConversion(p);
            if (!operand.ty.isInt() and !operand.ty.isFloat())
                try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));

            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));
            if (operand.val.tag != .unavailable) {
                _ = operand.val.sub(operand.val.zero(), operand.val, operand.ty, p.pp.comp);
            }
            try operand.un(p, .negate_expr);
            return operand;
        },
        .plus_plus => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            if (!operand.ty.isInt() and !operand.ty.isFloat() and !operand.ty.isReal() and !operand.ty.isPtr())
                try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));

            if (!Tree.isLval(p.nodes.slice(), p.data.items, p.value_map, operand.node) or operand.ty.isConst()) {
                try p.errTok(.not_assignable, tok);
                return error.ParsingFailed;
            }
            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));

            if (operand.val.tag != .unavailable) {
                if (operand.val.add(operand.val, operand.val.one(), operand.ty, p.pp.comp))
                    try p.errOverflow(tok, operand);
            }

            try operand.un(p, .pre_inc_expr);
            return operand;
        },
        .minus_minus => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            if (!operand.ty.isInt() and !operand.ty.isFloat() and !operand.ty.isReal() and !operand.ty.isPtr())
                try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));

            if (!Tree.isLval(p.nodes.slice(), p.data.items, p.value_map, operand.node) or operand.ty.isConst()) {
                try p.errTok(.not_assignable, tok);
                return error.ParsingFailed;
            }
            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));

            if (operand.val.tag != .unavailable) {
                if (operand.val.sub(operand.val, operand.val.one(), operand.ty, p.pp.comp))
                    try p.errOverflow(tok, operand);
            }

            try operand.un(p, .pre_dec_expr);
            return operand;
        },
        .tilde => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            try operand.lvalConversion(p);
            if (!operand.ty.isInt()) try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));
            if (operand.ty.isInt()) {
                try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));
                if (operand.val.tag != .unavailable) {
                    operand.val = operand.val.bitNot(operand.ty, p.pp.comp);
                }
            } else {
                operand.val.tag = .unavailable;
            }
            try operand.un(p, .bit_not_expr);
            return operand;
        },
        .bang => {
            p.tok_i += 1;

            var operand = try p.castExpr();
            try operand.expect(p);
            try operand.lvalConversion(p);
            if (!operand.ty.isInt() and !operand.ty.isFloat() and !operand.ty.isPtr())
                try p.errStr(.invalid_argument_un, tok, try p.typeStr(operand.ty));

            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));
            if (operand.val.tag != .unavailable) {
                const res = Value.int(@boolToInt(!operand.val.getBool()));
                operand.val = res;
            }
            operand.ty = .{ .specifier = .int };
            try operand.un(p, .bool_not_expr);
            return operand;
        },
        .keyword_sizeof => {
            p.tok_i += 1;
            const expected_paren = p.tok_i;
            var res = Result{};
            if (try p.typeName()) |ty| {
                res.ty = ty;
                try p.errTok(.expected_parens_around_typename, expected_paren);
            } else if (p.eatToken(.l_paren)) |l_paren| {
                if (try p.typeName()) |ty| {
                    res.ty = ty;
                    try p.expectClosing(l_paren, .r_paren);
                } else {
                    p.tok_i = expected_paren;
                    res = try p.parseNoEval(unExpr);
                }
            } else {
                res = try p.parseNoEval(unExpr);
            }

            if (res.ty.sizeof(p.pp.comp)) |size| {
                res.val = .{ .tag = .int, .data = .{ .int = size } };
            } else {
                res.val.tag = .unavailable;
                try p.errStr(.invalid_sizeof, expected_paren - 1, try p.typeStr(res.ty));
            }
            res.ty = p.pp.comp.types.size;
            try res.un(p, .sizeof_expr);
            return res;
        },
        .keyword_alignof, .keyword_alignof1, .keyword_alignof2 => {
            p.tok_i += 1;
            const expected_paren = p.tok_i;
            var res = Result{};
            if (try p.typeName()) |ty| {
                res.ty = ty;
                try p.errTok(.expected_parens_around_typename, expected_paren);
            } else if (p.eatToken(.l_paren)) |l_paren| {
                if (try p.typeName()) |ty| {
                    res.ty = ty;
                    try p.expectClosing(l_paren, .r_paren);
                } else {
                    p.tok_i = expected_paren;
                    res = try p.parseNoEval(unExpr);
                    try p.errTok(.alignof_expr, expected_paren);
                }
            } else {
                res = try p.parseNoEval(unExpr);
                try p.errTok(.alignof_expr, expected_paren);
            }

            res.val = Value.int(res.ty.alignof(p.pp.comp));
            res.ty = p.pp.comp.types.size;
            try res.un(p, .alignof_expr);
            return res;
        },
        .keyword_extension => {
            p.tok_i += 1;
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            var child = try p.castExpr();
            try child.expect(p);
            return child;
        },
        else => {
            var lhs = try p.primaryExpr();
            if (lhs.empty(p)) return lhs;
            while (true) {
                const suffix = try p.suffixExpr(lhs);
                if (suffix.empty(p)) break;
                lhs = suffix;
            }
            return lhs;
        },
    }
}

/// suffixExpr
///  : '[' expr ']'
///  | '(' argumentExprList? ')'
///  | '.' IDENTIFIER
///  | '->' IDENTIFIER
///  | '++'
///  | '--'
/// argumentExprList : assignExpr (',' assignExpr)*
fn suffixExpr(p: *Parser, lhs: Result) Error!Result {
    assert(!lhs.empty(p));
    switch (p.tok_ids[p.tok_i]) {
        .l_paren => return p.callExpr(lhs),
        .plus_plus => {
            defer p.tok_i += 1;

            var operand = lhs;
            if (!operand.ty.isInt() and !operand.ty.isFloat() and !operand.ty.isReal() and !operand.ty.isPtr())
                try p.errStr(.invalid_argument_un, p.tok_i, try p.typeStr(operand.ty));

            if (!Tree.isLval(p.nodes.slice(), p.data.items, p.value_map, operand.node) or operand.ty.isConst()) {
                try p.err(.not_assignable);
                return error.ParsingFailed;
            }
            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));

            try operand.un(p, .post_dec_expr);
            return operand;
        },
        .minus_minus => {
            defer p.tok_i += 1;

            var operand = lhs;
            if (!operand.ty.isInt() and !operand.ty.isFloat() and !operand.ty.isReal() and !operand.ty.isPtr())
                try p.errStr(.invalid_argument_un, p.tok_i, try p.typeStr(operand.ty));

            if (!Tree.isLval(p.nodes.slice(), p.data.items, p.value_map, operand.node) or operand.ty.isConst()) {
                try p.err(.not_assignable);
                return error.ParsingFailed;
            }
            if (operand.ty.isInt()) try operand.intCast(p, operand.ty.integerPromotion(p.pp.comp));

            try operand.un(p, .post_dec_expr);
            return operand;
        },
        .l_bracket => {
            const l_bracket = p.tok_i;
            p.tok_i += 1;
            var index = try p.expr();
            try index.expect(p);
            try p.expectClosing(l_bracket, .r_bracket);

            const l_ty = lhs.ty;
            const r_ty = index.ty;
            var ptr = lhs;
            try ptr.lvalConversion(p);
            try index.lvalConversion(p);
            if (ptr.ty.isPtr()) {
                ptr.ty = ptr.ty.elemType();
                if (!index.ty.isInt()) try p.errTok(.invalid_index, l_bracket);
                try p.checkArrayBounds(index, l_ty, l_bracket);
            } else if (index.ty.isPtr()) {
                index.ty = index.ty.elemType();
                if (!ptr.ty.isInt()) try p.errTok(.invalid_index, l_bracket);
                try p.checkArrayBounds(ptr, r_ty, l_bracket);
                std.mem.swap(Result, &ptr, &index);
            } else {
                try p.errTok(.invalid_subscript, l_bracket);
            }

            try ptr.saveValue(p);
            try index.saveValue(p);
            try ptr.bin(p, .array_access_expr, index);
            return ptr;
        },
        .period => {
            p.tok_i += 1;
            const name = try p.expectIdentifier();
            return p.fieldAccess(lhs, name, false);
        },
        .arrow => {
            p.tok_i += 1;
            const name = try p.expectIdentifier();
            if (lhs.ty.isArray()) {
                var copy = lhs;
                copy.ty.decayArray();
                try copy.un(p, .array_to_pointer);
                return p.fieldAccess(copy, name, true);
            }
            return p.fieldAccess(lhs, name, true);
        },
        else => return Result{},
    }
}

fn fieldAccess(
    p: *Parser,
    lhs: Result,
    field_name_tok: TokenIndex,
    is_arrow: bool,
) !Result {
    const expr_ty = lhs.ty;
    const is_ptr = expr_ty.isPtr();
    const expr_base_ty = if (is_ptr) expr_ty.elemType() else expr_ty;
    const record_ty = expr_base_ty.canonicalize(.standard);

    switch (record_ty.specifier) {
        .@"struct", .@"union" => {},
        else => {
            try p.errStr(.expected_record_ty, field_name_tok, try p.typeStr(expr_ty));
            return error.ParsingFailed;
        },
    }
    if (record_ty.hasIncompleteSize()) {
        try p.errStr(.deref_incomplete_ty_ptr, field_name_tok - 2, try p.typeStr(expr_base_ty));
        return error.ParsingFailed;
    }
    if (is_arrow and !is_ptr) try p.errStr(.member_expr_not_ptr, field_name_tok, try p.typeStr(expr_ty));
    if (!is_arrow and is_ptr) try p.errStr(.member_expr_ptr, field_name_tok, try p.typeStr(expr_ty));

    const field_name = p.tokSlice(field_name_tok);
    if (!record_ty.hasField(field_name)) {
        p.strings.items.len = 0;

        try p.strings.writer().print("'{s}' in '", .{field_name});
        try expr_ty.print(p.strings.writer());
        try p.strings.append('\'');

        const duped = try p.pp.comp.diag.arena.allocator().dupe(u8, p.strings.items);
        try p.errStr(.no_such_member, field_name_tok, duped);
        return error.ParsingFailed;
    }
    return p.fieldAccessExtra(lhs.node, record_ty, field_name, is_arrow);
}

fn fieldAccessExtra(p: *Parser, lhs: NodeIndex, record_ty: Type, field_name: []const u8, is_arrow: bool) Error!Result {
    for (record_ty.data.record.fields) |f, i| {
        if (f.isAnonymousRecord()) {
            if (!f.ty.hasField(field_name)) continue;
            const inner = try p.addNode(.{
                .tag = if (is_arrow) .member_access_ptr_expr else .member_access_expr,
                .ty = f.ty,
                .data = .{ .member = .{ .lhs = lhs, .index = @intCast(u32, i) } },
            });
            return p.fieldAccessExtra(inner, f.ty, field_name, false);
        }
        if (std.mem.eql(u8, field_name, f.name)) return Result{
            .ty = f.ty,
            .node = try p.addNode(.{
                .tag = if (is_arrow) .member_access_ptr_expr else .member_access_expr,
                .ty = f.ty,
                .data = .{ .member = .{ .lhs = lhs, .index = @intCast(u32, i) } },
            }),
        };
    }
    // We already checked that this container has a field by the name.
    unreachable;
}

fn callExpr(p: *Parser, lhs: Result) Error!Result {
    const l_paren = p.tok_i;
    p.tok_i += 1;
    const ty = lhs.ty.isCallable() orelse {
        try p.errStr(.not_callable, l_paren, try p.typeStr(lhs.ty));
        return error.ParsingFailed;
    };
    const params = ty.params();
    var func = lhs;
    try func.lvalConversion(p);

    const list_buf_top = p.list_buf.items.len;
    defer p.list_buf.items.len = list_buf_top;
    try p.list_buf.append(func.node);
    var arg_count: u32 = 0;

    const builtin_node = p.getNode(lhs.node, .builtin_call_expr_one);

    var first_after = l_paren;
    while (p.eatToken(.r_paren) == null) {
        const param_tok = p.tok_i;
        if (arg_count == params.len) first_after = p.tok_i;
        var arg = try p.assignExpr();
        try arg.expect(p);
        const raw_arg_node = arg.node;
        try arg.lvalConversion(p);
        if (arg.ty.hasIncompleteSize() and !arg.ty.is(.void)) return error.ParsingFailed;

        if (arg_count >= params.len) {
            if (arg.ty.isInt()) try arg.intCast(p, arg.ty.integerPromotion(p.pp.comp));
            if (arg.ty.is(.float)) try arg.floatCast(p, .{ .specifier = .double });
            try arg.saveValue(p);
            try p.list_buf.append(arg.node);
            arg_count += 1;

            _ = p.eatToken(.comma) orelse {
                try p.expectClosing(l_paren, .r_paren);
                break;
            };
            continue;
        }

        const p_ty = params[arg_count].ty;
        if (p_ty.is(.special_va_start)) va_start: {
            const builtin_tok = p.nodes.items(.data)[@enumToInt(builtin_node.?)].decl.name;
            var func_ty = p.func.ty orelse {
                try p.errTok(.va_start_not_in_func, builtin_tok);
                break :va_start;
            };
            if (func_ty.specifier != .var_args_func) {
                try p.errTok(.va_start_fixed_args, builtin_tok);
                break :va_start;
            }
            const func_params = func_ty.params();
            const last_param_name = func_params[func_params.len - 1].name;
            const decl_ref = p.getNode(raw_arg_node, .decl_ref_expr);
            if (decl_ref == null or
                !mem.eql(u8, p.tokSlice(p.nodes.items(.data)[@enumToInt(decl_ref.?)].decl_ref), last_param_name))
            {
                try p.errTok(.va_start_not_last_param, param_tok);
            }
        } else if (p_ty.is(.bool)) {
            // this is ridiculous but it's what clang does
            if (arg.ty.isInt() or arg.ty.isFloat() or arg.ty.isPtr()) {
                try arg.boolCast(p, p_ty);
            } else {
                try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
                try p.errTok(.parameter_here, params[arg_count].name_tok);
            }
        } else if (p_ty.isInt()) {
            if (arg.ty.isInt() or arg.ty.isFloat()) {
                try arg.intCast(p, p_ty);
            } else if (arg.ty.isPtr()) {
                try p.errStr(
                    .implicit_ptr_to_int,
                    param_tok,
                    try p.typePairStrExtra(arg.ty, " to ", p_ty),
                );
                try p.errTok(.parameter_here, params[arg_count].name_tok);
                try arg.intCast(p, p_ty);
            } else {
                try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
                try p.errTok(.parameter_here, params[arg_count].name_tok);
            }
        } else if (p_ty.isFloat()) {
            if (arg.ty.isInt() or arg.ty.isFloat()) {
                try arg.floatCast(p, p_ty);
            } else {
                try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
                try p.errTok(.parameter_here, params[arg_count].name_tok);
            }
        } else if (p_ty.isPtr()) {
            if (arg.val.isZero()) {
                try arg.nullCast(p, p_ty);
            } else if (arg.ty.isInt()) {
                try p.errStr(
                    .implicit_int_to_ptr,
                    param_tok,
                    try p.typePairStrExtra(arg.ty, " to ", p_ty),
                );
                try p.errTok(.parameter_here, params[arg_count].name_tok);
                try arg.intCast(p, p_ty);
            } else if (!arg.ty.isVoidStar() and !p_ty.isVoidStar() and !p_ty.eql(arg.ty, p.pp.comp, false)) {
                try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
                try p.errTok(.parameter_here, params[arg_count].name_tok);
            }
        } else if (p_ty.isRecord()) {
            if (!p_ty.eql(arg.ty, p.pp.comp, false)) {
                try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
                try p.errTok(.parameter_here, params[arg_count].name_tok);
            }
        } else {
            // should be unreachable
            try p.errStr(.incompatible_param, param_tok, try p.typeStr(arg.ty));
            try p.errTok(.parameter_here, params[arg_count].name_tok);
        }

        try arg.saveValue(p);
        try p.list_buf.append(arg.node);
        arg_count += 1;

        _ = p.eatToken(.comma) orelse {
            try p.expectClosing(l_paren, .r_paren);
            break;
        };
    }

    const extra = Diagnostics.Message.Extra{ .arguments = .{
        .expected = @intCast(u32, params.len),
        .actual = @intCast(u32, arg_count),
    } };
    if (ty.is(.func) and params.len != arg_count) {
        try p.errExtra(.expected_arguments, first_after, extra);
    }
    if (ty.is(.old_style_func) and params.len != arg_count) {
        try p.errExtra(.expected_arguments_old, first_after, extra);
    }
    if (ty.is(.var_args_func) and arg_count < params.len) {
        try p.errExtra(.expected_at_least_arguments, first_after, extra);
    }

    if (builtin_node) |some| {
        const index = @enumToInt(some);
        var call_node = p.nodes.get(index);
        defer p.nodes.set(index, call_node);
        const args = p.list_buf.items[list_buf_top..];
        switch (arg_count) {
            0 => {},
            1 => call_node.data.decl.node = args[1], // args[0] == func.node
            else => {
                call_node.tag = .builtin_call_expr;
                args[0] = @intToEnum(NodeIndex, call_node.data.decl.name);
                call_node.data = .{ .range = try p.addList(args) };
            },
        }
        return Result{ .node = some, .ty = call_node.ty.returnType() };
    }

    var call_node: Tree.Node = .{
        .tag = .call_expr_one,
        .ty = ty.returnType(),
        .data = .{ .bin = .{ .lhs = func.node, .rhs = .none } },
    };
    const args = p.list_buf.items[list_buf_top..];
    switch (arg_count) {
        0 => {},
        1 => call_node.data.bin.rhs = args[1], // args[0] == func.node
        else => {
            call_node.tag = .call_expr;
            call_node.data = .{ .range = try p.addList(args) };
        },
    }
    return Result{ .node = try p.addNode(call_node), .ty = call_node.ty };
}

fn checkArrayBounds(p: *Parser, index: Result, arr_ty: Type, tok: TokenIndex) !void {
    if (index.val.tag == .unavailable) return;
    const len = Value.int(arr_ty.arrayLen() orelse return);

    if (index.ty.isUnsignedInt(p.pp.comp)) {
        if (index.val.compare(.gte, len, p.pp.comp.types.size, p.pp.comp))
            try p.errExtra(.array_after, tok, .{ .unsigned = index.val.data.int });
    } else {
        if (index.val.compare(.lt, Value.int(0), index.ty, p.pp.comp)) {
            try p.errExtra(.array_before, tok, .{
                .signed = index.val.signExtend(index.ty, p.pp.comp),
            });
        } else if (index.val.compare(.gte, len, p.pp.comp.types.size, p.pp.comp)) {
            try p.errExtra(.array_after, tok, .{ .unsigned = index.val.data.int });
        }
    }
}

/// primaryExpr
///  : IDENTIFIER
///  | INTEGER_LITERAL
///  | FLOAT_LITERAL
///  | IMAGINARY_LITERAL
///  | CHAR_LITERAL
///  | STRING_LITERAL
///  | '(' expr ')'
///  | genericSelection
fn primaryExpr(p: *Parser) Error!Result {
    if (p.eatToken(.l_paren)) |l_paren| {
        var e = try p.expr();
        try e.expect(p);
        try p.expectClosing(l_paren, .r_paren);
        try e.un(p, .paren_expr);
        return e;
    }
    switch (p.tok_ids[p.tok_i]) {
        .identifier, .extended_identifier => {
            const name_tok = p.expectIdentifier() catch unreachable;
            const name = p.tokSlice(name_tok);
            if (p.pp.comp.builtins.get(name)) |some| {
                for (p.tok_ids[p.tok_i..]) |id| switch (id) {
                    .r_paren => {}, // closing grouped expr
                    .l_paren => break, // beginning of a call
                    else => {
                        try p.errTok(.builtin_must_be_called, name_tok);
                        return error.ParsingFailed;
                    },
                };
                return Result{
                    .ty = some,
                    .node = try p.addNode(.{
                        .tag = .builtin_call_expr_one,
                        .ty = some,
                        .data = .{ .decl = .{ .name = name_tok, .node = .none } },
                    }),
                };
            }
            const sym = p.findSymbol(name_tok, .reference) orelse {
                if (p.tok_ids[p.tok_i] == .l_paren) {
                    // allow implicitly declaring functions before C99 like `puts("foo")`
                    if (mem.startsWith(u8, name, "__builtin_"))
                        try p.errStr(.unknown_builtin, name_tok, name)
                    else
                        try p.errStr(.implicit_func_decl, name_tok, name);

                    const func_ty = try p.arena.create(Type.Func);
                    func_ty.* = .{ .return_type = .{ .specifier = .int }, .params = &.{} };
                    const ty: Type = .{ .specifier = .old_style_func, .data = .{ .func = func_ty } };
                    const node = try p.addNode(.{
                        .ty = ty,
                        .tag = .fn_proto,
                        .data = .{ .decl = .{ .name = name_tok } },
                    });

                    try p.decl_buf.append(node);
                    try p.scopes.append(.{ .decl = .{
                        .name = name,
                        .ty = ty,
                        .name_tok = name_tok,
                    } });

                    return Result{
                        .ty = ty,
                        .node = try p.addNode(.{
                            .tag = .decl_ref_expr,
                            .ty = ty,
                            .data = .{ .decl_ref = name_tok },
                        }),
                    };
                }
                try p.errStr(.undeclared_identifier, name_tok, p.tokSlice(name_tok));
                return error.ParsingFailed;
            };
            switch (sym) {
                .enumeration => |e| {
                    var res = e.value;
                    try p.checkDeprecatedUnavailable(res.ty, name_tok, e.name_tok);
                    res.node = try p.addNode(.{
                        .tag = .enumeration_ref,
                        .ty = res.ty,
                        .data = .{ .decl_ref = name_tok },
                    });
                    return res;
                },
                .def, .decl, .param => |s| {
                    try p.checkDeprecatedUnavailable(s.ty, name_tok, s.name_tok);
                    return Result{
                        .ty = s.ty,
                        .node = try p.addNode(.{
                            .tag = .decl_ref_expr,
                            .ty = s.ty,
                            .data = .{ .decl_ref = name_tok },
                        }),
                    };
                },
                else => unreachable,
            }
        },
        .macro_func, .macro_function => {
            defer p.tok_i += 1;
            var ty: Type = undefined;
            var tok = p.tok_i;
            if (p.func.ident) |some| {
                ty = some.ty;
                tok = p.nodes.items(.data)[@enumToInt(some.node)].decl.name;
            } else if (p.func.ty) |_| {
                p.strings.items.len = 0;
                try p.strings.appendSlice(p.tokSlice(p.func.name));
                try p.strings.append(0);
                const predef = try p.makePredefinedIdentifier();
                ty = predef.ty;
                p.func.ident = predef;
            } else {
                p.strings.items.len = 0;
                try p.strings.append(0);
                const predef = try p.makePredefinedIdentifier();
                ty = predef.ty;
                p.func.ident = predef;
                try p.decl_buf.append(predef.node);
            }
            if (p.func.ty == null) try p.err(.predefined_top_level);
            return Result{
                .ty = ty,
                .node = try p.addNode(.{
                    .tag = .decl_ref_expr,
                    .ty = ty,
                    .data = .{ .decl_ref = tok },
                }),
            };
        },
        .macro_pretty_func => {
            defer p.tok_i += 1;
            var ty: Type = undefined;
            if (p.func.pretty_ident) |some| {
                ty = some.ty;
            } else if (p.func.ty) |func_ty| {
                p.strings.items.len = 0;
                try Type.printNamed(func_ty, p.tokSlice(p.func.name), p.strings.writer());
                try p.strings.append(0);
                const predef = try p.makePredefinedIdentifier();
                ty = predef.ty;
                p.func.pretty_ident = predef;
            } else {
                p.strings.items.len = 0;
                try p.strings.appendSlice("top level\x00");
                const predef = try p.makePredefinedIdentifier();
                ty = predef.ty;
                p.func.pretty_ident = predef;
                try p.decl_buf.append(predef.node);
            }
            if (p.func.ty == null) try p.err(.predefined_top_level);
            return Result{
                .ty = ty,
                .node = try p.addNode(.{
                    .tag = .decl_ref_expr,
                    .ty = ty,
                    .data = .{ .decl_ref = p.tok_i },
                }),
            };
        },
        .string_literal,
        .string_literal_utf_16,
        .string_literal_utf_8,
        .string_literal_utf_32,
        .string_literal_wide,
        => return p.stringLiteral(),
        .char_literal,
        .char_literal_utf_16,
        .char_literal_utf_32,
        .char_literal_wide,
        => return p.charLiteral(),
        .float_literal, .imaginary_literal => |tag| {
            defer p.tok_i += 1;
            const ty = Type{ .specifier = .double };
            const d_val = try p.parseFloat(p.tok_i, f64);
            var res = Result{
                .ty = ty,
                .node = try p.addNode(.{ .tag = .double_literal, .ty = ty, .data = undefined }),
                .val = Value.float(d_val),
            };
            if (!p.in_macro) try p.value_map.put(res.node, res.val);
            if (tag == .imaginary_literal) {
                try p.err(.gnu_imaginary_constant);
                res.ty = .{ .specifier = .complex_double };
                res.val.tag = .unavailable;
                try res.un(p, .imaginary_literal);
            }
            return res;
        },
        .float_literal_f, .imaginary_literal_f => |tag| {
            defer p.tok_i += 1;
            const ty = Type{ .specifier = .float };
            const f_val = try p.parseFloat(p.tok_i, f64);
            var res = Result{
                .ty = ty,
                .node = try p.addNode(.{ .tag = .float_literal, .ty = ty, .data = undefined }),
                .val = Value.float(f_val),
            };
            if (!p.in_macro) try p.value_map.put(res.node, res.val);
            if (tag == .imaginary_literal_f) {
                try p.err(.gnu_imaginary_constant);
                res.ty = .{ .specifier = .complex_float };
                res.val.tag = .unavailable;
                try res.un(p, .imaginary_literal);
            }
            return res;
        },
        .float_literal_l => return p.todo("long double literals"),
        .imaginary_literal_l => {
            try p.err(.gnu_imaginary_constant);
            return p.todo("long double imaginary literals");
        },
        .zero => {
            p.tok_i += 1;
            var res: Result = .{ .val = Value.int(0) };
            res.node = try p.addNode(.{ .tag = .int_literal, .ty = res.ty, .data = undefined });
            if (!p.in_macro) try p.value_map.put(res.node, res.val);
            return res;
        },
        .one => {
            p.tok_i += 1;
            var res: Result = .{ .val = Value.int(1) };
            res.node = try p.addNode(.{ .tag = .int_literal, .ty = res.ty, .data = undefined });
            if (!p.in_macro) try p.value_map.put(res.node, res.val);
            return res;
        },
        .integer_literal,
        .integer_literal_u,
        .integer_literal_l,
        .integer_literal_lu,
        .integer_literal_ll,
        .integer_literal_llu,
        => return p.integerLiteral(),
        .keyword_generic => return p.genericSelection(),
        else => return Result{},
    }
}

fn makePredefinedIdentifier(p: *Parser) !Result {
    const slice = p.strings.items;
    const elem_ty = .{ .specifier = .char, .qual = .{ .@"const" = true } };
    const arr_ty = try p.arena.create(Type.Array);
    arr_ty.* = .{ .elem = elem_ty, .len = slice.len };
    const ty: Type = .{ .specifier = .array, .data = .{ .array = arr_ty } };

    const val = Value.bytes(try p.arena.dupe(u8, slice));
    const str_lit = try p.addNode(.{ .tag = .string_literal_expr, .ty = ty, .data = undefined });
    if (!p.in_macro) try p.value_map.put(str_lit, val);

    return Result{ .ty = ty, .node = try p.addNode(.{
        .tag = .implicit_static_var,
        .ty = ty,
        .data = .{ .decl = .{ .name = p.tok_i, .node = str_lit } },
    }) };
}

fn stringLiteral(p: *Parser) Error!Result {
    var start = p.tok_i;
    // use 1 for wchar_t
    var width: ?u8 = null;
    while (true) {
        switch (p.tok_ids[p.tok_i]) {
            .string_literal => {},
            .string_literal_utf_16 => if (width) |some| {
                if (some != 16) try p.err(.unsupported_str_cat);
            } else {
                width = 16;
            },
            .string_literal_utf_8 => if (width) |some| {
                if (some != 8) try p.err(.unsupported_str_cat);
            } else {
                width = 8;
            },
            .string_literal_utf_32 => if (width) |some| {
                if (some != 32) try p.err(.unsupported_str_cat);
            } else {
                width = 32;
            },
            .string_literal_wide => if (width) |some| {
                if (some != 1) try p.err(.unsupported_str_cat);
            } else {
                width = 1;
            },
            else => break,
        }
        p.tok_i += 1;
    }
    if (width == null) width = 8;
    if (width.? != 8) return p.todo("unicode string literals");
    p.strings.items.len = 0;
    while (start < p.tok_i) : (start += 1) {
        var slice = p.tokSlice(start);
        slice = slice[0 .. slice.len - 1];
        var i = mem.indexOf(u8, slice, "\"").? + 1;
        try p.strings.ensureUnusedCapacity(slice.len);
        while (i < slice.len) : (i += 1) {
            switch (slice[i]) {
                '\\' => {
                    i += 1;
                    switch (slice[i]) {
                        '\n' => i += 1,
                        '\r' => i += 2,
                        '\'', '\"', '\\', '?' => |c| p.strings.appendAssumeCapacity(c),
                        'n' => p.strings.appendAssumeCapacity('\n'),
                        'r' => p.strings.appendAssumeCapacity('\r'),
                        't' => p.strings.appendAssumeCapacity('\t'),
                        'a' => p.strings.appendAssumeCapacity(0x07),
                        'b' => p.strings.appendAssumeCapacity(0x08),
                        'e' => p.strings.appendAssumeCapacity(0x1B),
                        'f' => p.strings.appendAssumeCapacity(0x0C),
                        'v' => p.strings.appendAssumeCapacity(0x0B),
                        'x' => p.strings.appendAssumeCapacity(try p.parseNumberEscape(start, 16, slice, &i)),
                        '0'...'7' => p.strings.appendAssumeCapacity(try p.parseNumberEscape(start, 8, slice, &i)),
                        'u' => try p.parseUnicodeEscape(start, 4, slice, &i),
                        'U' => try p.parseUnicodeEscape(start, 8, slice, &i),
                        else => unreachable,
                    }
                },
                else => |c| p.strings.appendAssumeCapacity(c),
            }
        }
    }
    try p.strings.append(0);
    const slice = p.strings.items;

    const arr_ty = try p.arena.create(Type.Array);
    arr_ty.* = .{ .elem = .{ .specifier = .char }, .len = slice.len };
    var res: Result = .{
        .ty = .{
            .specifier = .array,
            .data = .{ .array = arr_ty },
        },
        .val = Value.bytes(try p.arena.dupe(u8, slice)),
    };
    res.node = try p.addNode(.{ .tag = .string_literal_expr, .ty = res.ty, .data = undefined });
    if (!p.in_macro) try p.value_map.put(res.node, res.val);
    return res;
}

fn parseNumberEscape(p: *Parser, tok: TokenIndex, base: u8, slice: []const u8, i: *usize) !u8 {
    if (base == 16) i.* += 1; // skip x
    var char: u8 = 0;
    var reported = false;
    while (i.* < slice.len) : (i.* += 1) {
        const val = std.fmt.charToDigit(slice[i.*], base) catch break; // validated by Tokenizer
        if (@mulWithOverflow(u8, char, base, &char) and !reported) {
            try p.errExtra(.escape_sequence_overflow, tok, .{ .unsigned = i.* });
            reported = true;
        }
        char += val;
    }
    i.* -= 1;
    return char;
}

fn parseUnicodeEscape(p: *Parser, tok: TokenIndex, count: u8, slice: []const u8, i: *usize) !void {
    const c = std.fmt.parseInt(u21, slice[i.* + 1 ..][0..count], 16) catch 0x110000; // count validated by tokenizer
    i.* += count + 1;
    if (!std.unicode.utf8ValidCodepoint(c) or (c < 0xa0 and c != '$' and c != '@' and c != '`')) {
        try p.errExtra(.invalid_universal_character, tok, .{ .unsigned = i.* - count - 2 });
        return;
    }
    var buf: [4]u8 = undefined;
    const to_write = std.unicode.utf8Encode(c, &buf) catch unreachable; // validated above
    p.strings.appendSliceAssumeCapacity(buf[0..to_write]);
}

fn charLiteral(p: *Parser) Error!Result {
    defer p.tok_i += 1;
    const ty: Type = switch (p.tok_ids[p.tok_i]) {
        .char_literal => .{ .specifier = .int },
        .char_literal_wide => p.pp.comp.types.wchar,
        .char_literal_utf_16 => .{ .specifier = .ushort },
        .char_literal_utf_32 => .{ .specifier = .ulong },
        else => unreachable,
    };
    const max: u32 = switch (p.tok_ids[p.tok_i]) {
        .char_literal => std.math.maxInt(u8),
        .char_literal_wide => std.math.maxInt(u32), // TODO correct
        .char_literal_utf_16 => std.math.maxInt(u16),
        .char_literal_utf_32 => std.math.maxInt(u32),
        else => unreachable,
    };
    var multichar: u8 = switch (p.tok_ids[p.tok_i]) {
        .char_literal => 0,
        .char_literal_wide => 4,
        .char_literal_utf_16 => 2,
        .char_literal_utf_32 => 2,
        else => unreachable,
    };

    var val: u32 = 0;
    var overflow_reported = false;
    var slice = p.tokSlice(p.tok_i);
    slice = slice[0 .. slice.len - 1];
    var i = mem.indexOf(u8, slice, "\'").? + 1;
    while (i < slice.len) : (i += 1) {
        var c: u32 = slice[i];
        switch (c) {
            '\\' => {
                i += 1;
                switch (slice[i]) {
                    '\n' => i += 1,
                    '\r' => i += 2,
                    '\'', '\"', '\\', '?' => c = slice[i],
                    'n' => c = '\n',
                    'r' => c = '\r',
                    't' => c = '\t',
                    'a' => c = 0x07,
                    'b' => c = 0x08,
                    'e' => c = 0x1B,
                    'f' => c = 0x0C,
                    'v' => c = 0x0B,
                    'x' => c = try p.parseNumberEscape(p.tok_i, 16, slice, &i),
                    '0'...'7' => c = try p.parseNumberEscape(p.tok_i, 8, slice, &i),
                    'u', 'U' => return p.todo("unicode escapes in char literals"),
                    else => unreachable,
                }
            },
            // These are safe since the source is checked to be valid utf8.
            0b1100_0000...0b1101_1111 => {
                c &= 0b00011111;
                c <<= 6;
                c |= slice[i + 1] & 0b00111111;
                i += 1;
            },
            0b1110_0000...0b1110_1111 => {
                c &= 0b00001111;
                c <<= 6;
                c |= slice[i + 1] & 0b00111111;
                c <<= 6;
                c |= slice[i + 2] & 0b00111111;
                i += 2;
            },
            0b1111_0000...0b1111_0111 => {
                c &= 0b00000111;
                c <<= 6;
                c |= slice[i + 1] & 0b00111111;
                c <<= 6;
                c |= slice[i + 2] & 0b00111111;
                c <<= 6;
                c |= slice[i + 3] & 0b00111111;
                i += 3;
            },
            else => {},
        }
        if (c > max) try p.err(.char_too_large);
        switch (multichar) {
            0, 2, 4 => multichar += 1,
            1 => {
                multichar = 99;
                try p.err(.multichar_literal);
            },
            3 => {
                try p.err(.unicode_multichar_literal);
                return error.ParsingFailed;
            },
            5 => {
                try p.err(.wide_multichar_literal);
                val = 0;
                multichar = 6;
            },
            6 => val = 0,
            else => {},
        }
        if (@mulWithOverflow(u32, val, max, &val) and !overflow_reported) {
            try p.errExtra(.char_lit_too_wide, p.tok_i, .{ .unsigned = i });
            overflow_reported = true;
        }
        val += c;
    }

    var res = Result{
        .ty = ty,
        .val = Value.int(val),
        .node = try p.addNode(.{ .tag = .char_literal, .ty = ty, .data = undefined }),
    };
    if (!p.in_macro) try p.value_map.put(res.node, res.val);
    return res;
}

fn parseFloat(p: *Parser, tok: TokenIndex, comptime T: type) Error!T {
    var bytes = p.tokSlice(tok);
    switch (p.tok_ids[tok]) {
        .float_literal => {},
        .imaginary_literal, .float_literal_f, .float_literal_l => bytes = bytes[0 .. bytes.len - 1],
        .imaginary_literal_f, .imaginary_literal_l => bytes = bytes[0 .. bytes.len - 2],
        else => unreachable,
    }
    if (bytes.len > 2 and (bytes[1] == 'x' or bytes[1] == 'X')) {
        assert(bytes[0] == '0'); // validated by Tokenizer
        return std.fmt.parseHexFloat(T, bytes) catch |e| switch (e) {
            error.InvalidCharacter => unreachable, // validated by Tokenizer
            error.Overflow => p.todo("what to do with hex floats too big"),
        };
    } else {
        return std.fmt.parseFloat(T, bytes) catch |e| switch (e) {
            error.InvalidCharacter => unreachable, // validated by Tokenizer
        };
    }
}

fn integerLiteral(p: *Parser) Error!Result {
    const id = p.tok_ids[p.tok_i];
    var slice = p.tokSlice(p.tok_i);
    defer p.tok_i += 1;
    var base: u8 = 10;
    if (std.ascii.startsWithIgnoreCase(slice, "0x")) {
        slice = slice[2..];
        base = 16;
    } else if (std.ascii.startsWithIgnoreCase(slice, "0b")) {
        try p.err(.binary_integer_literal);
        slice = slice[2..];
        base = 2;
    } else if (slice[0] == '0') {
        base = 8;
    }
    switch (id) {
        .integer_literal_u, .integer_literal_l => slice = slice[0 .. slice.len - 1],
        .integer_literal_lu, .integer_literal_ll => slice = slice[0 .. slice.len - 2],
        .integer_literal_llu => slice = slice[0 .. slice.len - 3],
        else => {},
    }

    var val: u64 = 0;
    var overflow = false;
    for (slice) |c| {
        const digit: u64 = switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => unreachable,
        };

        if (val != 0 and @mulWithOverflow(u64, val, base, &val)) overflow = true;
        if (@addWithOverflow(u64, val, digit, &val)) overflow = true;
    }
    if (overflow) {
        try p.err(.int_literal_too_big);
        var res: Result = .{ .ty = .{ .specifier = .ulong_long }, .val = Value.int(val) };
        res.node = try p.addNode(.{ .tag = .int_literal, .ty = res.ty, .data = undefined });
        if (!p.in_macro) try p.value_map.put(res.node, res.val);
        return res;
    }
    switch (id) {
        .integer_literal, .integer_literal_l, .integer_literal_ll => {
            if (val > std.math.maxInt(i64)) {
                try p.err(.implicitly_unsigned_literal);
            }
        },
        else => {},
    }

    if (base == 10) {
        switch (id) {
            .integer_literal => return p.castInt(val, &.{ .int, .long, .long_long }),
            .integer_literal_u => return p.castInt(val, &.{ .uint, .ulong, .ulong_long }),
            .integer_literal_l => return p.castInt(val, &.{ .long, .long_long }),
            .integer_literal_lu => return p.castInt(val, &.{ .ulong, .ulong_long }),
            .integer_literal_ll => return p.castInt(val, &.{.long_long}),
            .integer_literal_llu => return p.castInt(val, &.{.ulong_long}),
            else => unreachable,
        }
    } else {
        switch (id) {
            .integer_literal => return p.castInt(val, &.{ .int, .uint, .long, .ulong, .long_long, .ulong_long }),
            .integer_literal_u => return p.castInt(val, &.{ .uint, .ulong, .ulong_long }),
            .integer_literal_l => return p.castInt(val, &.{ .long, .ulong, .long_long, .ulong_long }),
            .integer_literal_lu => return p.castInt(val, &.{ .ulong, .ulong_long }),
            .integer_literal_ll => return p.castInt(val, &.{ .long_long, .ulong_long }),
            .integer_literal_llu => return p.castInt(val, &.{.ulong_long}),
            else => unreachable,
        }
    }
}

fn castInt(p: *Parser, val: u64, specs: []const Type.Specifier) Error!Result {
    var res: Result = .{ .val = Value.int(val) };
    for (specs) |spec| {
        const ty = Type{ .specifier = spec };
        const unsigned = ty.isUnsignedInt(p.pp.comp);
        const size = ty.sizeof(p.pp.comp).?;
        res.ty = ty;

        if (unsigned) {
            switch (size) {
                2 => if (val <= std.math.maxInt(u16)) break,
                4 => if (val <= std.math.maxInt(u32)) break,
                8 => if (val <= std.math.maxInt(u64)) break,
                else => unreachable,
            }
        } else {
            switch (size) {
                2 => if (val <= std.math.maxInt(i16)) break,
                4 => if (val <= std.math.maxInt(i32)) break,
                8 => if (val <= std.math.maxInt(i64)) break,
                else => unreachable,
            }
        }
    } else {
        res.ty = .{ .specifier = .ulong_long };
    }
    res.node = try p.addNode(.{ .tag = .int_literal, .ty = res.ty, .data = .{ .int = val } });
    if (!p.in_macro) try p.value_map.put(res.node, res.val);
    return res;
}

/// Run a parser function but do not evaluate the result
fn parseNoEval(p: *Parser, func: fn (*Parser) Error!Result) Error!Result {
    const no_eval = p.no_eval;
    defer p.no_eval = no_eval;
    p.no_eval = true;
    const parsed = try func(p);
    try parsed.expect(p);
    return parsed;
}

/// genericSelection : keyword_generic '(' assignExpr ',' genericAssoc (',' genericAssoc)* ')'
/// genericAssoc
///  : typeName ':' assignExpr
///  | keyword_default ':' assignExpr
fn genericSelection(p: *Parser) Error!Result {
    p.tok_i += 1;
    const l_paren = try p.expectToken(.l_paren);
    const controlling = try p.parseNoEval(assignExpr);
    _ = try p.expectToken(.comma);

    const list_buf_top = p.list_buf.items.len;
    defer p.list_buf.items.len = list_buf_top;
    try p.list_buf.append(controlling.node);

    var default_tok: ?TokenIndex = null;
    // TODO actually choose
    var chosen: Result = .{};
    while (true) {
        const start = p.tok_i;
        if (try p.typeName()) |ty| {
            if (ty.anyQual()) {
                try p.errTok(.generic_qual_type, start);
            }
            _ = try p.expectToken(.colon);
            chosen = try p.assignExpr();
            try chosen.expect(p);
            try chosen.saveValue(p);
            try p.list_buf.append(try p.addNode(.{
                .tag = .generic_association_expr,
                .ty = ty,
                .data = .{ .un = chosen.node },
            }));
        } else if (p.eatToken(.keyword_default)) |tok| {
            if (default_tok) |prev| {
                try p.errTok(.generic_duplicate_default, tok);
                try p.errTok(.previous_case, prev);
            }
            default_tok = tok;
            _ = try p.expectToken(.colon);
            chosen = try p.assignExpr();
            try chosen.expect(p);
            try chosen.saveValue(p);
            try p.list_buf.append(try p.addNode(.{
                .tag = .generic_default_expr,
                .data = .{ .un = chosen.node },
            }));
        } else {
            if (p.list_buf.items.len == list_buf_top + 1) {
                try p.err(.expected_type);
                return error.ParsingFailed;
            }
            break;
        }
        if (p.eatToken(.comma) == null) break;
    }
    try p.expectClosing(l_paren, .r_paren);

    var generic_node: Tree.Node = .{
        .tag = .generic_expr_one,
        .ty = chosen.ty,
        .data = .{ .bin = .{ .lhs = controlling.node, .rhs = chosen.node } },
    };
    const associations = p.list_buf.items[list_buf_top..];
    if (associations.len > 2) { // associations[0] == controlling.node
        generic_node.tag = .generic_expr;
        generic_node.data = .{ .range = try p.addList(associations) };
    }
    chosen.node = try p.addNode(generic_node);
    return chosen;
}
