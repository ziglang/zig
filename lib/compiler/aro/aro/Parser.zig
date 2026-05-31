const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const big = std.math.big;

const Attribute = @import("Attribute.zig");
const Builtins = @import("Builtins.zig");
const evalBuiltin = @import("Builtins/eval.zig").eval;
const char_info = @import("char_info.zig");
const Compilation = @import("Compilation.zig");
const Diagnostics = @import("Diagnostics.zig");
const InitList = @import("InitList.zig");
const Preprocessor = @import("Preprocessor.zig");
const record_layout = @import("record_layout.zig");
const Source = @import("Source.zig");
const StringId = @import("StringInterner.zig").StringId;
const SymbolStack = @import("SymbolStack.zig");
const Symbol = SymbolStack.Symbol;
const text_literal = @import("text_literal.zig");
const Tokenizer = @import("Tokenizer.zig");
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const NumberPrefix = Token.NumberPrefix;
const NumberSuffix = Token.NumberSuffix;
const TokenIndex = Tree.TokenIndex;
const Node = Tree.Node;
const TypeStore = @import("TypeStore.zig");
const Type = TypeStore.Type;
const QualType = TypeStore.QualType;
const Value = @import("Value.zig");

const NodeList = std.ArrayList(Node.Index);
const Switch = struct {
    default: ?TokenIndex = null,
    ranges: std.ArrayList(Range) = .empty,
    qt: QualType,
    comp: *const Compilation,

    const Range = struct {
        first: Value,
        last: Value,
        tok: TokenIndex,
    };

    fn add(s: *Switch, first: Value, last: Value, tok: TokenIndex) !?Range {
        for (s.ranges.items) |range| {
            if (last.compare(.gte, range.first, s.comp) and first.compare(.lte, range.last, s.comp)) {
                return range; // They overlap.
            }
        }
        try s.ranges.append(s.comp.gpa, .{
            .first = first,
            .last = last,
            .tok = tok,
        });
        return null;
    }
};

const Label = union(enum) {
    unresolved_goto: TokenIndex,
    label: TokenIndex,
};

const InitContext = enum {
    /// inits do not need to be compile-time constants
    runtime,
    /// constexpr variable, could be any scope but inits must be compile-time constants
    constexpr,
    /// static and global variables, inits must be compile-time constants
    static,
};

pub const Error = Compilation.Error || error{ParsingFailed};

/// An attribute that has been parsed but not yet validated in its context
const TentativeAttribute = struct {
    attr: Attribute,
    tok: TokenIndex,
    seen: bool = false,
};

/// How the parser handles const int decl references when it is expecting an integer
/// constant expression.
const ConstDeclFoldingMode = enum {
    /// fold const decls as if they were literals
    fold_const_decls,
    /// fold const decls as if they were literals and issue GNU extension diagnostic
    gnu_folding_extension,
    /// fold const decls as if they were literals and issue VLA diagnostic
    gnu_vla_folding_extension,
    /// folding const decls is prohibited; return an unavailable value
    no_const_decl_folding,
};

const Parser = @This();

// values from preprocessor
pp: *Preprocessor,
comp: *Compilation,
diagnostics: *Diagnostics,
tok_ids: []const Token.Id,
tok_i: TokenIndex = 0,

/// The AST being constructed.
tree: Tree,

// buffers used during compilation
syms: SymbolStack = .{},
strings: std.array_list.Aligned(u8, .@"4") = .empty,
labels: std.ArrayList(Label) = .empty,
list_buf: NodeList = .empty,
decl_buf: NodeList = .empty,
/// Function type parameters, also used for generic selection association
/// duplicate checking.
param_buf: std.ArrayList(Type.Func.Param) = .empty,
/// Enum type fields.
enum_buf: std.ArrayList(Type.Enum.Field) = .empty,
/// Record type fields.
record_buf: std.ArrayList(Type.Record.Field) = .empty,
/// Attributes that have been parsed but not yet validated or applied.
attr_buf: std.MultiArrayList(TentativeAttribute) = .empty,
/// Used to store validated attributes before they are applied to types.
attr_application_buf: std.ArrayList(Attribute) = .empty,
/// type name -> variable name location for tentative definitions (top-level defs with thus-far-incomplete types)
/// e.g. `struct Foo bar;` where `struct Foo` is not defined yet.
/// The key is the StringId of `Foo` and the value is the TokenIndex of `bar`
/// Items are removed if the type is subsequently completed with a definition.
/// We only store the first tentative definition that uses a given type because this map is only used
/// for issuing an error message, and correcting the first error for a type will fix all of them for that type.
tentative_defs: std.AutoHashMapUnmanaged(StringId, TokenIndex) = .empty,

// configuration and miscellaneous info
no_eval: bool = false,
in_macro: bool = false,
extension_suppressed: bool = false,
contains_address_of_label: bool = false,
label_count: u32 = 0,
const_decl_folding: ConstDeclFoldingMode = .fold_const_decls,
/// location of first computed goto in function currently being parsed
/// if a computed goto is used, the function must contain an
/// address-of-label expression (tracked with contains_address_of_label)
computed_goto_tok: ?TokenIndex = null,

/// __auto_type may only be used with a single declarator. Keep track of the name
/// so that it is not used in its own initializer.
auto_type_decl_name: StringId = .empty,

init_context: InitContext = .runtime,

/// Various variables that are different for each function.
func: struct {
    /// null if not in function, will always be plain func
    qt: ?QualType = null,
    name: TokenIndex = 0,
    ident: ?Result = null,
    pretty_ident: ?Result = null,
} = .{},

/// Various variables that are different for each record.
record: struct {
    // invalid means we're not parsing a record
    kind: Token.Id = .invalid,
    flexible_field: ?TokenIndex = null,
    start: usize = 0,

    fn addField(r: @This(), p: *Parser, name: StringId, tok: TokenIndex) Error!void {
        var i = p.record_members.items.len;
        while (i > r.start) {
            i -= 1;
            if (p.record_members.items[i].name == name) {
                try p.err(tok, .duplicate_member, .{p.tokSlice(tok)});
                try p.err(p.record_members.items[i].tok, .previous_definition, .{});
                break;
            }
        }
        try p.record_members.append(p.comp.gpa, .{ .name = name, .tok = tok });
    }

    fn addFieldsFromAnonymous(r: @This(), p: *Parser, record_ty: Type.Record) Error!void {
        for (record_ty.fields) |f| {
            if (f.name_tok == 0) {
                if (f.qt.getRecord(p.comp)) |field_record_ty| {
                    try r.addFieldsFromAnonymous(p, field_record_ty);
                }
            } else {
                try r.addField(p, f.name, f.name_tok);
            }
        }
    }
} = .{},
record_members: std.ArrayList(struct { tok: TokenIndex, name: StringId }) = .empty,

@"switch": ?*Switch = null,
in_loop: bool = false,
pragma_pack: ?u8 = null,
string_ids: struct {
    declspec_id: StringId,
    main_id: StringId,
    file: StringId,
    jmp_buf: StringId,
    sigjmp_buf: StringId,
    ucontext_t: StringId,
},

/// Checks codepoint for various pedantic warnings
/// Returns true if diagnostic issued
fn checkIdentifierCodepointWarnings(p: *Parser, codepoint: u21, loc: Source.Location) Compilation.Error!bool {
    assert(codepoint >= 0x80);

    const prev_total = p.diagnostics.total;
    var sf = std.heap.stackFallback(1024, p.comp.gpa);
    var allocating: std.Io.Writer.Allocating = .init(sf.get());
    defer allocating.deinit();

    if (!char_info.isC99IdChar(codepoint)) {
        const diagnostic: Diagnostic = .c99_compat;
        try p.diagnostics.add(.{
            .kind = diagnostic.kind,
            .text = diagnostic.fmt,
            .extension = diagnostic.extension,
            .opt = diagnostic.opt,
            .location = loc.expand(p.comp),
        });
    }
    if (char_info.isInvisible(codepoint)) {
        const diagnostic: Diagnostic = .unicode_zero_width;
        p.formatArgs(&allocating.writer, diagnostic.fmt, .{Codepoint.init(codepoint)}) catch return error.OutOfMemory;

        try p.diagnostics.add(.{
            .kind = diagnostic.kind,
            .text = allocating.written(),
            .extension = diagnostic.extension,
            .opt = diagnostic.opt,
            .location = loc.expand(p.comp),
        });
    }
    if (char_info.homoglyph(codepoint)) |resembles| {
        const diagnostic: Diagnostic = .unicode_homoglyph;
        p.formatArgs(&allocating.writer, diagnostic.fmt, .{ Codepoint.init(codepoint), resembles }) catch return error.OutOfMemory;

        try p.diagnostics.add(.{
            .kind = diagnostic.kind,
            .text = allocating.written(),
            .extension = diagnostic.extension,
            .opt = diagnostic.opt,
            .location = loc.expand(p.comp),
        });
    }
    return p.diagnostics.total != prev_total;
}

/// Issues diagnostics for the current extended identifier token
/// Return value indicates whether the token should be considered an identifier
/// true means consider the token to actually be an identifier
/// false means it is not
fn validateExtendedIdentifier(p: *Parser) !bool {
    assert(p.tok_ids[p.tok_i] == .extended_identifier);

    const slice = p.tokSlice(p.tok_i);
    const view = std.unicode.Utf8View.init(slice) catch {
        try p.err(p.tok_i, .invalid_utf8, .{});
        return error.FatalError;
    };
    var it = view.iterator();

    var valid_identifier = true;
    var warned = false;
    var len: usize = 0;
    var invalid_char: u21 = undefined;
    var loc = p.pp.tokens.items(.loc)[p.tok_i];

    var normalized = true;
    var last_canonical_class: char_info.CanonicalCombiningClass = .not_reordered;
    const standard = p.comp.langopts.standard;
    while (it.nextCodepoint()) |codepoint| {
        defer {
            len += 1;
            loc.byte_offset += std.unicode.utf8CodepointSequenceLength(codepoint) catch unreachable;
        }
        if (codepoint == '$') {
            warned = true;
            if (p.comp.langopts.dollars_in_identifiers) {
                const diagnostic: Diagnostic = .dollar_in_identifier_extension;
                try p.diagnostics.add(.{
                    .kind = diagnostic.kind,
                    .text = diagnostic.fmt,
                    .extension = diagnostic.extension,
                    .opt = diagnostic.opt,
                    .location = loc.expand(p.comp),
                });
            }
        }

        if (codepoint <= 0x7F) continue;
        if (!valid_identifier) continue;

        const allowed = standard.codepointAllowedInIdentifier(codepoint, len == 0);
        if (!allowed) {
            invalid_char = codepoint;
            valid_identifier = false;
            continue;
        }

        if (!warned) {
            warned = try p.checkIdentifierCodepointWarnings(codepoint, loc);
        }

        // Check NFC normalization.
        if (!normalized) continue;
        const canonical_class = char_info.getCanonicalClass(codepoint);
        if (@intFromEnum(last_canonical_class) > @intFromEnum(canonical_class) and
            canonical_class != .not_reordered)
        {
            normalized = false;
            try p.err(p.tok_i, .identifier_not_normalized, .{slice});
            continue;
        }
        if (char_info.isNormalized(codepoint) != .yes) {
            normalized = false;
            try p.err(p.tok_i, .identifier_not_normalized, .{Normalized.init(slice)});
        }
        last_canonical_class = canonical_class;
    }

    if (!valid_identifier) {
        if (len == 1) {
            try p.err(p.tok_i, .unexpected_character, .{Codepoint.init(invalid_char)});
            return false;
        } else {
            try p.err(p.tok_i, .invalid_identifier_start_char, .{Codepoint.init(invalid_char)});
        }
    }

    return true;
}

fn eatIdentifier(p: *Parser) !?TokenIndex {
    switch (p.tok_ids[p.tok_i]) {
        .identifier => {},
        .extended_identifier => {
            if (!try p.validateExtendedIdentifier()) {
                p.tok_i += 1;
                return null;
            }
        },
        else => return null,
    }
    p.tok_i += 1;

    // Handle illegal '$' characters in identifiers
    if (!p.comp.langopts.dollars_in_identifiers) {
        if (p.tok_ids[p.tok_i] == .invalid and p.tokSlice(p.tok_i)[0] == '$') {
            try p.err(p.tok_i, .dollars_in_identifiers, .{});
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

    return (try p.eatIdentifier()) orelse error.ParsingFailed;
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

pub fn tokSlice(p: *Parser, tok: TokenIndex) []const u8 {
    if (p.tok_ids[tok].lexeme()) |some| return some;
    const loc = p.pp.tokens.items(.loc)[tok];
    var tmp_tokenizer: Tokenizer = .{
        .buf = p.comp.getSource(loc.id).buf,
        .langopts = p.comp.langopts,
        .index = loc.byte_offset,
        .source = .generated,
        .splice_locs = &.{},
    };
    const res = tmp_tokenizer.next();
    return tmp_tokenizer.buf[res.start..res.end];
}

fn expectClosing(p: *Parser, opening: TokenIndex, id: Token.Id) Error!void {
    _ = p.expectToken(id) catch |e| {
        if (e == error.ParsingFailed) {
            try p.err(opening, switch (id) {
                .r_paren => .to_match_paren,
                .r_brace => .to_match_brace,
                .r_bracket => .to_match_brace,
                else => unreachable,
            }, .{});
        }
        return e;
    };
}

pub const Diagnostic = @import("Parser/Diagnostic.zig");

pub fn err(p: *Parser, tok_i: TokenIndex, diagnostic: Diagnostic, args: anytype) Compilation.Error!void {
    if (p.extension_suppressed) {
        if (diagnostic.extension and diagnostic.kind == .off) return;
    }
    if (diagnostic.suppress_version) |some| if (p.comp.langopts.standard.atLeast(some)) return;
    if (diagnostic.suppress_unless_version) |some| if (!p.comp.langopts.standard.atLeast(some)) return;
    if (p.diagnostics.effectiveKind(diagnostic) == .off) return;

    var sf = std.heap.stackFallback(1024, p.comp.gpa);
    var allocating: std.Io.Writer.Allocating = .init(sf.get());
    defer allocating.deinit();

    p.formatArgs(&allocating.writer, diagnostic.fmt, args) catch return error.OutOfMemory;

    const tok = p.pp.tokens.get(tok_i);
    var loc = tok.loc;
    if (tok_i != 0 and tok.id == .eof) {
        // if the token is EOF, point at the end of the previous token instead
        const prev = p.pp.tokens.get(tok_i - 1);
        loc = prev.loc;
        loc.byte_offset += @intCast(p.tokSlice(tok_i - 1).len);
    }
    try p.diagnostics.addWithLocation(p.comp, .{
        .kind = diagnostic.kind,
        .text = allocating.written(),
        .opt = diagnostic.opt,
        .extension = diagnostic.extension,
        .location = loc.expand(p.comp),
    }, p.pp.expansionSlice(tok_i), true);
}

fn formatArgs(p: *Parser, w: *std.Io.Writer, fmt: []const u8, args: anytype) !void {
    var i: usize = 0;
    inline for (std.meta.fields(@TypeOf(args))) |arg_info| {
        const arg = @field(args, arg_info.name);
        i += switch (@TypeOf(arg)) {
            []const u8 => try Diagnostics.formatString(w, fmt[i..], arg),
            Tree.Token.Id => try formatTokenId(w, fmt[i..], arg),
            QualType => try p.formatQualType(w, fmt[i..], arg),
            text_literal.Ascii => try arg.format(w, fmt[i..]),
            Result => try p.formatResult(w, fmt[i..], arg),
            *Result => try p.formatResult(w, fmt[i..], arg.*),
            Enumerator, *Enumerator => try p.formatResult(w, fmt[i..], .{
                .node = undefined,
                .val = arg.val,
                .qt = arg.qt,
            }),
            Codepoint => try arg.format(w, fmt[i..]),
            Normalized => try arg.format(w, fmt[i..]),
            Escaped => try arg.format(w, fmt[i..]),
            else => switch (@typeInfo(@TypeOf(arg))) {
                .int, .comptime_int => try Diagnostics.formatInt(w, fmt[i..], arg),
                .pointer => try Diagnostics.formatString(w, fmt[i..], arg),
                else => comptime unreachable,
            },
        };
    }
    try w.writeAll(fmt[i..]);
}

fn formatTokenId(w: *std.Io.Writer, fmt: []const u8, tok_id: Tree.Token.Id) !usize {
    const i = Diagnostics.templateIndex(w, fmt, "{tok_id}");
    try w.writeAll(tok_id.symbol());
    return i;
}

fn formatQualType(p: *Parser, w: *std.Io.Writer, fmt: []const u8, qt: QualType) !usize {
    const i = Diagnostics.templateIndex(w, fmt, "{qt}");
    try w.writeByte('\'');
    try qt.print(p.comp, w);
    try w.writeByte('\'');

    if (qt.isC23Auto()) return i;
    if (qt.get(p.comp, .vector)) |vector_ty| {
        try w.print(" (vector of {d} '", .{vector_ty.len});
        try vector_ty.elem.printDesugared(p.comp, w);
        try w.writeAll("' values)");
    } else if (qt.shouldDesugar(p.comp)) {
        try w.writeAll(" (aka '");
        try qt.printDesugared(p.comp, w);
        try w.writeAll("')");
    }
    return i;
}

fn formatResult(p: *Parser, w: *std.Io.Writer, fmt: []const u8, res: Result) !usize {
    const i = Diagnostics.templateIndex(w, fmt, "{value}");
    switch (res.val.opt_ref) {
        .none => try w.writeAll("(none)"),
        .null => try w.writeAll("nullptr_t"),
        else => if (try res.val.print(res.qt, p.comp, w)) |nested| switch (nested) {
            .pointer => |ptr| {
                const ptr_node: Node.Index = @enumFromInt(ptr.node);
                const decl_name = p.tree.tokSlice(ptr_node.tok(&p.tree));
                try ptr.offset.printPointer(decl_name, p.comp, w);
            },
        },
    }
    return i;
}

const Normalized = struct {
    str: []const u8,

    fn init(str: []const u8) Normalized {
        return .{ .str = str };
    }

    pub fn format(ctx: Normalized, w: *std.Io.Writer, fmt: []const u8) !usize {
        const i = Diagnostics.templateIndex(w, fmt, "{normalized}");
        var it: std.unicode.Utf8Iterator = .{
            .bytes = ctx.str,
            .i = 0,
        };
        while (it.nextCodepoint()) |codepoint| {
            if (codepoint < 0x7F) {
                try w.writeByte(@intCast(codepoint));
            } else if (codepoint < 0xFFFF) {
                try w.writeAll("\\u");
                try w.printInt(codepoint, 16, .upper, .{
                    .fill = '0',
                    .width = 4,
                });
            } else {
                try w.writeAll("\\U");
                try w.printInt(codepoint, 16, .upper, .{
                    .fill = '0',
                    .width = 8,
                });
            }
        }
        return i;
    }
};

const Codepoint = struct {
    codepoint: u21,

    fn init(codepoint: u21) Codepoint {
        return .{ .codepoint = codepoint };
    }

    pub fn format(ctx: Codepoint, w: *std.Io.Writer, fmt: []const u8) !usize {
        const i = Diagnostics.templateIndex(w, fmt, "{codepoint}");
        try w.print("{X:0>4}", .{ctx.codepoint});
        return i;
    }
};

const Escaped = struct {
    str: []const u8,

    fn init(str: []const u8) Escaped {
        return .{ .str = str };
    }

    pub fn format(ctx: Escaped, w: *std.Io.Writer, fmt: []const u8) !usize {
        const i = Diagnostics.templateIndex(w, fmt, "{s}");
        try std.zig.stringEscape(ctx.str, w);
        return i;
    }
};

pub fn todo(p: *Parser, msg: []const u8) Error {
    try p.err(p.tok_i, .todo, .{msg});
    return error.ParsingFailed;
}

pub fn removeNull(p: *Parser, str: Value) !Value {
    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;
    {
        const bytes = p.comp.interner.get(str.ref()).bytes;
        try p.strings.appendSlice(p.comp.gpa, bytes[0 .. bytes.len - 1]);
    }
    return Value.intern(p.comp, .{ .bytes = p.strings.items[strings_top..] });
}

pub fn errValueChanged(p: *Parser, tok_i: TokenIndex, diagnostic: Diagnostic, res: Result, old_val: Value, int_qt: QualType) !void {
    const zero_str = if (res.val.isZero(p.comp)) "non-zero " else "";
    const old_res: Result = .{
        .node = undefined,
        .val = old_val,
        .qt = res.qt,
    };
    const new_res: Result = .{
        .node = undefined,
        .val = res.val,
        .qt = int_qt,
    };
    try p.err(tok_i, diagnostic, .{ res.qt, int_qt, zero_str, old_res, new_res });
}

fn checkDeprecatedUnavailable(p: *Parser, ty: QualType, usage_tok: TokenIndex, decl_tok: TokenIndex) !void {
    if (ty.getAttribute(p.comp, .@"error")) |@"error"| {
        const msg_str = p.comp.interner.get(@"error".msg.ref()).bytes;
        try p.err(usage_tok, .error_attribute, .{ p.tokSlice(@"error".__name_tok), Escaped.init(msg_str) });
    }
    if (ty.getAttribute(p.comp, .warning)) |warning| {
        const msg_str = p.comp.interner.get(warning.msg.ref()).bytes;
        try p.err(usage_tok, .warning_attribute, .{ p.tokSlice(warning.__name_tok), Escaped.init(msg_str) });
    }
    if (ty.getAttribute(p.comp, .unavailable)) |unavailable| {
        try p.errDeprecated(usage_tok, .unavailable, unavailable.msg);
        try p.err(unavailable.__name_tok, .unavailable_note, .{p.tokSlice(decl_tok)});
        return error.ParsingFailed;
    }
    if (ty.getAttribute(p.comp, .deprecated)) |deprecated| {
        try p.errDeprecated(usage_tok, .deprecated_declarations, deprecated.msg);
        try p.err(deprecated.__name_tok, .deprecated_note, .{p.tokSlice(decl_tok)});
    }
}

fn errDeprecated(p: *Parser, tok_i: TokenIndex, diagnostic: Diagnostic, msg: ?Value) Compilation.Error!void {
    const colon_str: []const u8 = if (msg != null) ": " else "";
    const msg_str: []const u8 = if (msg) |m| p.comp.interner.get(m.ref()).bytes else "";
    return p.err(tok_i, diagnostic, .{ p.tokSlice(tok_i), colon_str, Escaped.init(msg_str) });
}

fn addNode(p: *Parser, node: Tree.Node) Allocator.Error!Node.Index {
    if (p.in_macro) return undefined;
    return p.tree.addNode(node);
}

fn errExpectedToken(p: *Parser, expected: Token.Id, actual: Token.Id) Error {
    switch (actual) {
        .invalid => try p.err(p.tok_i, .expected_invalid, .{expected}),
        .eof => try p.err(p.tok_i, .expected_eof, .{expected}),
        else => try p.err(p.tok_i, .expected_token, .{ expected, actual }),
    }
    return error.ParsingFailed;
}

fn addList(p: *Parser, nodes: []const Node.Index) Allocator.Error!Tree.Node.Range {
    if (p.in_macro) return Tree.Node.Range{ .start = 0, .end = 0 };
    const start: u32 = @intCast(p.data.items.len);
    try p.data.appendSlice(nodes);
    const end: u32 = @intCast(p.data.items.len);
    return Tree.Node.Range{ .start = start, .end = end };
}

/// Recursively sets the defintion field of `tentative_decl` to `definition`.
pub fn setTentativeDeclDefinition(p: *Parser, tentative_decl: Node.Index, definition: Node.Index) void {
    const node_data = &p.tree.nodes.items(.data)[@intFromEnum(tentative_decl)];
    switch (p.tree.nodes.items(.tag)[@intFromEnum(tentative_decl)]) {
        .fn_proto => {},
        .variable => {},
        else => return,
    }

    const prev: Node.OptIndex = @enumFromInt(node_data[2]);

    node_data[2] = @intFromEnum(definition);
    if (prev.unpack()) |some| {
        p.setTentativeDeclDefinition(some, definition);
    }
}

/// Clears the defintion field of declarations that were not defined so that
/// the field always contains a _def if present.
fn clearNonTentativeDefinitions(p: *Parser) void {
    const tags = p.tree.nodes.items(.tag);
    const data = p.tree.nodes.items(.data);
    for (p.tree.root_decls.items) |root_decl| {
        switch (tags[@intFromEnum(root_decl)]) {
            .fn_proto => {
                const node_data = &data[@intFromEnum(root_decl)];
                if (node_data[2] != @intFromEnum(Node.OptIndex.null)) {
                    if (tags[node_data[2]] != .fn_def) {
                        node_data[2] = @intFromEnum(Node.OptIndex.null);
                    }
                }
            },
            .variable => {
                const node_data = &data[@intFromEnum(root_decl)];
                if (node_data[2] != @intFromEnum(Node.OptIndex.null)) {
                    if (tags[node_data[2]] != .variable_def) {
                        node_data[2] = @intFromEnum(Node.OptIndex.null);
                    }
                }
            },
            else => {},
        }
    }
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

fn nodeIs(p: *Parser, node: Node.Index, comptime tag: std.meta.Tag(Tree.Node)) bool {
    return p.getNode(node, tag) != null;
}

pub fn getDecayedStringLiteral(p: *Parser, node: Node.Index) ?Value {
    var cur = node;
    while (true) {
        switch (cur.get(&p.tree)) {
            .paren_expr => |un| cur = un.operand,
            .string_literal_expr => return p.tree.value_map.get(cur),
            .cast => |cast| switch (cast.kind) {
                .no_op, .bitcast, .array_to_pointer => cur = cast.operand,
                else => return null,
            },
            else => return null,
        }
    }
}

fn getNode(p: *Parser, node: Node.Index, comptime tag: std.meta.Tag(Tree.Node)) ?@FieldType(Node, @tagName(tag)) {
    loop: switch (node.get(&p.tree)) {
        .paren_expr => |un| continue :loop un.operand.get(&p.tree),
        tag => |data| return data,
        else => return null,
    }
}

fn pragma(p: *Parser) Compilation.Error!bool {
    var found_pragma = false;
    while (p.eatToken(.keyword_pragma)) |_| {
        found_pragma = true;

        const name_tok = p.tok_i;
        const name = p.tokSlice(name_tok);

        const end_idx = mem.indexOfScalarPos(Token.Id, p.tok_ids, p.tok_i, .nl).?;
        const pragma_len = @as(TokenIndex, @intCast(end_idx)) - p.tok_i;
        defer p.tok_i += pragma_len + 1; // skip past .nl as well
        if (p.comp.getPragma(name)) |prag| {
            try prag.parserCB(p, p.tok_i);
        }
    }
    return found_pragma;
}

/// Issue errors for top-level definitions whose type was never completed.
fn diagnoseIncompleteDefinitions(p: *Parser) !void {
    @branchHint(.cold);

    for (p.decl_buf.items) |decl_index| {
        const node = decl_index.get(&p.tree);
        const forward = switch (node) {
            .struct_forward_decl, .union_forward_decl, .enum_forward_decl => |forward| forward,
            else => continue,
        };

        const decl_type_name = switch (forward.container_qt.base(p.comp).type) {
            .@"struct", .@"union" => |record_ty| record_ty.name,
            .@"enum" => |enum_ty| enum_ty.name,
            else => unreachable,
        };

        const tentative_def_tok = p.tentative_defs.get(decl_type_name) orelse continue;
        try p.err(tentative_def_tok, .tentative_definition_incomplete, .{forward.container_qt});
        try p.err(forward.name_or_kind_tok, .forward_declaration_here, .{forward.container_qt});
    }
}

/// root : (decl | assembly ';' | staticAssert)*
pub fn parse(pp: *Preprocessor) Compilation.Error!Tree {
    const gpa = pp.comp.gpa;
    assert(pp.linemarkers == .none);
    pp.comp.pragmaEvent(.before_parse);

    const expected_implicit_typedef_max = 7;
    try pp.tokens.ensureUnusedCapacity(gpa, expected_implicit_typedef_max);

    var p: Parser = .{
        .pp = pp,
        .comp = pp.comp,
        .diagnostics = pp.diagnostics,
        .tree = .{
            .comp = pp.comp,
            .tokens = undefined, // Set after implicit typedefs
        },
        .tok_ids = pp.tokens.items(.id),
        .string_ids = .{
            .declspec_id = try pp.comp.internString("__declspec"),
            .main_id = try pp.comp.internString("main"),
            .file = try pp.comp.internString("FILE"),
            .jmp_buf = try pp.comp.internString("jmp_buf"),
            .sigjmp_buf = try pp.comp.internString("sigjmp_buf"),
            .ucontext_t = try pp.comp.internString("ucontext_t"),
        },
    };
    errdefer p.tree.deinit();
    defer {
        p.labels.deinit(gpa);
        p.strings.deinit(gpa);
        p.syms.deinit(gpa);
        p.list_buf.deinit(gpa);
        p.decl_buf.deinit(gpa);
        p.param_buf.deinit(gpa);
        p.enum_buf.deinit(gpa);
        p.record_buf.deinit(gpa);
        p.record_members.deinit(gpa);
        p.attr_buf.deinit(gpa);
        p.attr_application_buf.deinit(gpa);
        p.tentative_defs.deinit(gpa);
    }

    try p.syms.pushScope(&p);
    defer p.syms.popScope();

    {
        if (p.comp.langopts.hasChar8_T()) {
            try p.addImplicitTypedef("char8_t", .uchar);
        }
        try p.addImplicitTypedef("__int128_t", .int128);
        try p.addImplicitTypedef("__uint128_t", .uint128);

        try p.addImplicitTypedef("__builtin_ms_va_list", .char_pointer);

        const va_list_qt = pp.comp.type_store.va_list;
        try p.addImplicitTypedef("__builtin_va_list", va_list_qt);
        pp.comp.type_store.va_list = try va_list_qt.decay(pp.comp);

        try p.addImplicitTypedef("__NSConstantString", pp.comp.type_store.ns_constant_string);

        if (p.comp.float80Type()) |float80_ty| {
            try p.addImplicitTypedef("__float80", float80_ty);
        }

        // Set here so that the newly generated tokens are included.
        p.tree.tokens = p.pp.tokens.slice();
    }
    const implicit_typedef_count = p.decl_buf.items.len;
    assert(implicit_typedef_count <= expected_implicit_typedef_max);

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
                .keyword_c23_static_assert,
                .keyword_pragma,
                .keyword_extension,
                .keyword_asm,
                .keyword_asm1,
                .keyword_asm2,
                => {},
                else => try p.err(p.tok_i, .expected_external_decl, .{}),
            }
            continue;
        }
        if (p.assembly(.global) catch |er| switch (er) {
            error.ParsingFailed => {
                p.nextExternDecl();
                continue;
            },
            else => |e| return e,
        }) |node| {
            try p.decl_buf.append(gpa, node);
            continue;
        }
        if (p.eatToken(.semicolon)) |tok| {
            try p.err(tok, .extra_semi, .{});
            const empty = try p.tree.addNode(.{ .empty_decl = .{
                .semicolon = tok,
            } });
            try p.decl_buf.append(gpa, empty);
            continue;
        }
        try p.err(p.tok_i, .expected_external_decl, .{});
        p.nextExternDecl();
    }
    if (p.tentative_defs.count() > 0) {
        try p.diagnoseIncompleteDefinitions();
    }

    p.tree.root_decls = p.decl_buf;
    p.decl_buf = .empty;

    if (p.tree.root_decls.items.len == implicit_typedef_count) {
        try p.err(p.tok_i - 1, .empty_translation_unit, .{});
    }
    pp.comp.pragmaEvent(.after_parse);

    p.clearNonTentativeDefinitions();

    return p.tree;
}

fn addImplicitTypedef(p: *Parser, name: []const u8, qt: QualType) !void {
    const gpa = p.comp.gpa;
    const start = p.comp.generated_buf.items.len;
    try p.comp.generated_buf.ensureUnusedCapacity(gpa, name.len + 1);
    p.comp.generated_buf.appendSliceAssumeCapacity(name);
    p.comp.generated_buf.appendAssumeCapacity('\n');

    const name_tok: u32 = @intCast(p.pp.tokens.len);
    p.pp.tokens.appendAssumeCapacity(.{ .id = .identifier, .loc = .{
        .id = .generated,
        .byte_offset = @intCast(start),
        .line = p.pp.generated_line,
    } });
    p.pp.generated_line += 1;

    const node = try p.addNode(.{
        .typedef = .{
            .name_tok = name_tok,
            .qt = qt,
            .implicit = true,
        },
    });

    const interned_name = try p.comp.internString(name);
    const typedef_qt = (try p.comp.type_store.put(gpa, .{ .typedef = .{
        .base = qt,
        .name = interned_name,
        .decl_node = node,
    } })).withQualifiers(qt);
    try p.syms.defineTypedef(p, interned_name, typedef_qt, name_tok, node);
    try p.decl_buf.append(gpa, node);
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
            .r_paren, .r_brace, .r_bracket => parens -|= 1,
            .keyword_typedef,
            .keyword_extern,
            .keyword_static,
            .keyword_auto,
            .keyword_register,
            .keyword_thread_local,
            .keyword_c23_thread_local,
            .keyword_inline,
            .keyword_inline1,
            .keyword_inline2,
            .keyword_noreturn,
            .keyword_void,
            .keyword_bool,
            .keyword_c23_bool,
            .keyword_char,
            .keyword_short,
            .keyword_int,
            .keyword_long,
            .keyword_signed,
            .keyword_signed1,
            .keyword_signed2,
            .keyword_unsigned,
            .keyword_float,
            .keyword_double,
            .keyword_complex,
            .keyword_atomic,
            .keyword_enum,
            .keyword_struct,
            .keyword_union,
            .keyword_alignas,
            .keyword_c23_alignas,
            .identifier,
            .extended_identifier,
            .keyword_typeof,
            .keyword_typeof1,
            .keyword_typeof2,
            .keyword_typeof_unqual,
            .keyword_extension,
            .keyword_bit_int,
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

/// Called after a typedef is defined
fn typedefDefined(p: *Parser, name: StringId, ty: QualType) void {
    if (name == p.string_ids.file) {
        p.comp.type_store.file = ty;
    } else if (name == p.string_ids.jmp_buf) {
        p.comp.type_store.jmp_buf = ty;
    } else if (name == p.string_ids.sigjmp_buf) {
        p.comp.type_store.sigjmp_buf = ty;
    } else if (name == p.string_ids.ucontext_t) {
        p.comp.type_store.ucontext_t = ty;
    }
}

// ====== declarations ======

/// decl
///  : declSpec (initDeclarator ( ',' initDeclarator)*)? ';'
///  | declSpec declarator decl* compoundStmt
fn decl(p: *Parser) Error!bool {
    const gpa = p.comp.gpa;
    _ = try p.pragma();
    const first_tok = p.tok_i;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;

    try p.attributeSpecifier();

    var decl_spec = (try p.declSpec()) orelse blk: {
        if (p.func.qt != null) {
            p.tok_i = first_tok;
            return false;
        }
        switch (p.tok_ids[first_tok]) {
            .asterisk, .l_paren => {},
            .identifier, .extended_identifier => switch (p.tok_ids[first_tok + 1]) {
                .identifier, .extended_identifier => {
                    // The most likely reason for `identifier identifier` is
                    // an unknown type name.
                    try p.err(p.tok_i, .unknown_type_name, .{p.tokSlice(p.tok_i)});
                    p.tok_i += 1;
                    break :blk DeclSpec{ .qt = .invalid };
                },
                else => {},
            },
            else => if (p.tok_i != first_tok) {
                try p.err(p.tok_i, .expected_ident_or_l_paren, .{});
                return error.ParsingFailed;
            } else return false,
        }
        var builder: TypeStore.Builder = .{ .parser = p };
        break :blk DeclSpec{ .qt = try builder.finish() };
    };
    if (decl_spec.noreturn) |tok| {
        const attr = Attribute{ .tag = .noreturn, .args = .{ .noreturn = .{} }, .syntax = .keyword };
        try p.attr_buf.append(gpa, .{ .attr = attr, .tok = tok });
    }

    var decl_node = try p.tree.addNode(.{ .empty_decl = .{
        .semicolon = first_tok,
    } });
    var init_d = (try p.initDeclarator(&decl_spec, attr_buf_top, decl_node)) orelse {
        _ = try p.expectToken(.semicolon);

        missing_decl: {
            if (decl_spec.qt.type(p.comp) == .typeof) {
                // we follow GCC and clang's behavior here
                try p.err(first_tok, .missing_declaration, .{});
                return true;
            }
            switch (decl_spec.qt.base(p.comp).type) {
                .@"enum" => break :missing_decl,
                .@"struct", .@"union" => |record_ty| if (!record_ty.isAnonymous(p.comp)) break :missing_decl,
                else => {},
            }

            try p.err(first_tok, .missing_declaration, .{});
            return true;
        }

        const attrs = p.attr_buf.items(.attr)[attr_buf_top..];
        const toks = p.attr_buf.items(.tok)[attr_buf_top..];
        for (attrs, toks) |attr, tok| {
            try p.err(tok, .ignored_record_attr, .{
                @tagName(attr.tag), @tagName(decl_spec.qt.base(p.comp).type),
            });
        }
        return true;
    };

    // Check for function definition.
    if (init_d.d.declarator_type == .func and init_d.initializer == null) fn_def: {
        switch (p.tok_ids[p.tok_i]) {
            .comma, .semicolon => break :fn_def,
            .l_brace => {},
            else => if (init_d.d.old_style_func == null) {
                try p.err(p.tok_i - 1, .expected_fn_body, .{});
                return true;
            },
        }
        if (p.func.qt != null) try p.err(p.tok_i, .func_not_in_root, .{});

        const interned_declarator_name = try p.comp.internString(p.tokSlice(init_d.d.name));
        try p.syms.defineSymbol(p, interned_declarator_name, init_d.d.qt, init_d.d.name, decl_node, .{}, false);
        const func = p.func;
        p.func = .{
            .qt = init_d.d.qt,
            .name = init_d.d.name,
        };
        defer p.func = func;

        // Check return type of 'main' function.
        if (interned_declarator_name == p.string_ids.main_id) {
            const func_ty = init_d.d.qt.get(p.comp, .func).?;
            const int_ty = func_ty.return_type.get(p.comp, .int);
            if (int_ty == null or int_ty.? != .int) {
                try p.err(init_d.d.name, .main_return_type, .{});
            }
        }

        try p.syms.pushScope(p);
        defer p.syms.popScope();

        // Collect old style parameter declarations.
        if (init_d.d.old_style_func != null) {
            const param_buf_top = p.param_buf.items.len;
            defer p.param_buf.items.len = param_buf_top;

            // We cannot refer to the function type here because the pointer to
            // type_store.extra might get invalidated while parsing the param decls.
            const func_qt = init_d.d.qt.base(p.comp).qt;
            const params_len = func_qt.get(p.comp, .func).?.params.len;

            const new_params = try p.param_buf.addManyAsSlice(gpa, params_len);
            for (new_params) |*new_param| {
                new_param.name = .empty;
            }

            param_loop: while (true) {
                const param_decl_spec = (try p.declSpec()) orelse break;
                if (p.eatToken(.semicolon)) |semi| {
                    try p.err(semi, .missing_declaration, .{});
                    continue :param_loop;
                }

                while (true) {
                    const attr_buf_top_declarator = p.attr_buf.len;
                    defer p.attr_buf.len = attr_buf_top_declarator;

                    var param_d = (try p.declarator(param_decl_spec.qt, .param)) orelse {
                        try p.err(first_tok, .missing_declaration, .{});
                        _ = try p.expectToken(.semicolon);
                        continue :param_loop;
                    };
                    try p.attributeSpecifier();

                    if (param_d.qt.hasIncompleteSize(p.comp)) {
                        if (param_d.qt.is(p.comp, .void)) {
                            try p.err(param_d.name, .invalid_void_param, .{});
                        } else {
                            try p.err(param_d.name, .parameter_incomplete_ty, .{param_d.qt});
                        }
                    } else {
                        // Decay params declared as functions or arrays to pointer.
                        param_d.qt = try param_d.qt.decay(p.comp);
                    }

                    const attributed_qt = try Attribute.applyParameterAttributes(p, param_d.qt, attr_buf_top_declarator, .alignas_on_param);

                    try param_decl_spec.validateParam(p);
                    const param_node = try p.addNode(.{
                        .param = .{
                            .name_tok = param_d.name,
                            .qt = attributed_qt,
                            .storage_class = switch (param_decl_spec.storage_class) {
                                .none => .auto,
                                .register => .register,
                                else => .auto, // Error reported in `validateParam`
                            },
                        },
                    });

                    const name_str = p.tokSlice(param_d.name);
                    const interned_name = try p.comp.internString(name_str);
                    try p.syms.defineParam(p, interned_name, attributed_qt, param_d.name, param_node);

                    // find and correct parameter types
                    for (func_qt.get(p.comp, .func).?.params, new_params) |param, *new_param| {
                        if (param.name == interned_name) {
                            new_param.* = .{
                                .qt = attributed_qt,
                                .name = param.name,
                                .node = .pack(param_node),
                                .name_tok = param.name_tok,
                            };
                            break;
                        }
                    } else {
                        try p.err(param_d.name, .parameter_missing, .{name_str});
                    }

                    if (p.eatToken(.comma) == null) break;
                }
                _ = try p.expectToken(.semicolon);
            }

            const func_ty = func_qt.get(p.comp, .func).?;
            for (func_ty.params, new_params) |param, *new_param| {
                if (new_param.name == .empty) {
                    try p.err(param.name_tok, .param_not_declared, .{param.name.lookup(p.comp)});
                    new_param.* = .{
                        .name = param.name,
                        .name_tok = param.name_tok,
                        .node = param.node,
                        .qt = .int,
                    };
                }
            }
            // Update the functio type to contain the declared parameters.
            p.func.qt = try p.comp.type_store.put(gpa, .{ .func = .{
                .kind = .normal,
                .params = new_params,
                .return_type = func_ty.return_type,
            } });
        } else if (init_d.d.qt.get(p.comp, .func)) |func_ty| {
            for (func_ty.params) |param| {
                if (param.name == .empty) {
                    try p.err(param.name_tok, .omitting_parameter_name, .{});
                    continue;
                }

                // bypass redefinition check to avoid duplicate errors
                try p.syms.define(gpa, .{
                    .kind = .def,
                    .name = param.name,
                    .tok = param.name_tok,
                    .qt = param.qt,
                    .val = .{},
                    .node = param.node,
                });
                if (param.qt.isInvalid()) continue;

                if (param.qt.get(p.comp, .pointer)) |pointer_ty| {
                    if (pointer_ty.decayed) |decayed_qt| {
                        if (decayed_qt.get(p.comp, .array)) |array_ty| {
                            if (array_ty.len == .unspecified_variable) {
                                try p.err(param.name_tok, .unbound_vla, .{});
                            }
                        }
                    }
                }
                if (param.qt.hasIncompleteSize(p.comp) and !param.qt.is(p.comp, .void)) {
                    try p.err(param.name_tok, .parameter_incomplete_ty, .{param.qt});
                }
            }
        }

        const body = (try p.compoundStmt(true, null)) orelse {
            assert(init_d.d.old_style_func != null);
            try p.err(p.tok_i, .expected_fn_body, .{});
            return true;
        };

        try decl_spec.validateFnDef(p);
        try p.tree.setNode(.{ .function = .{
            .name_tok = init_d.d.name,
            .@"inline" = decl_spec.@"inline" != null,
            .static = decl_spec.storage_class == .static,
            .qt = p.func.qt.?,
            .body = body,
            .definition = null,
        } }, @intFromEnum(decl_node));

        try p.decl_buf.append(gpa, decl_node);

        // check gotos
        if (func.qt == null) {
            for (p.labels.items) |item| {
                if (item == .unresolved_goto)
                    try p.err(item.unresolved_goto, .undeclared_label, .{p.tokSlice(item.unresolved_goto)});
            }
            if (p.computed_goto_tok) |goto_tok| {
                if (!p.contains_address_of_label) try p.err(goto_tok, .invalid_computed_goto, .{});
            }
            p.labels.items.len = 0;
            p.label_count = 0;
            p.contains_address_of_label = false;
            p.computed_goto_tok = null;
        }
        return true;
    }

    // Declare all variable/typedef declarators.
    var warned_auto = false;
    while (true) {
        if (init_d.d.old_style_func) |tok_i| try p.err(tok_i, .invalid_old_style_params, .{});

        if (decl_spec.storage_class == .typedef) {
            try decl_spec.validateDecl(p);
            try p.tree.setNode(.{ .typedef = .{
                .name_tok = init_d.d.name,
                .qt = init_d.d.qt,
                .implicit = false,
            } }, @intFromEnum(decl_node));
        } else if (init_d.d.declarator_type == .func or init_d.d.qt.is(p.comp, .func)) {
            try decl_spec.validateFnDecl(p);
            try p.tree.setNode(.{ .function = .{
                .name_tok = init_d.d.name,
                .qt = init_d.d.qt,
                .static = decl_spec.storage_class == .static,
                .@"inline" = decl_spec.@"inline" != null,
                .body = null,
                .definition = null,
            } }, @intFromEnum(decl_node));
        } else {
            try decl_spec.validateDecl(p);
            var node_qt = init_d.d.qt;
            if (p.func.qt == null and decl_spec.storage_class != .@"extern") {
                if (node_qt.get(p.comp, .array)) |array_ty| {
                    if (array_ty.len == .incomplete) {
                        // Create tentative array node with fixed type.
                        node_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                            .elem = array_ty.elem,
                            .len = .{ .fixed = 1 },
                        } });
                    }
                }
            }

            try p.tree.setNode(.{
                .variable = .{
                    .name_tok = init_d.d.name,
                    .qt = node_qt,
                    .thread_local = decl_spec.thread_local != null,
                    .implicit = false,
                    .storage_class = switch (decl_spec.storage_class) {
                        .auto => .auto,
                        .register => .register,
                        .static => .static,
                        .@"extern" => if (init_d.initializer == null) .@"extern" else .auto,
                        else => .auto, // Error reported in `validate`
                    },
                    .initializer = if (init_d.initializer) |some| some.node else null,
                    .definition = null,
                },
            }, @intFromEnum(decl_node));
        }
        try p.decl_buf.append(gpa, decl_node);

        const interned_name = try p.comp.internString(p.tokSlice(init_d.d.name));
        if (decl_spec.storage_class == .typedef) {
            const typedef_qt = if (init_d.d.qt.isInvalid())
                init_d.d.qt
            else
                (try p.comp.type_store.put(gpa, .{ .typedef = .{
                    .base = init_d.d.qt,
                    .name = interned_name,
                    .decl_node = decl_node,
                } })).withQualifiers(init_d.d.qt);
            try p.syms.defineTypedef(p, interned_name, typedef_qt, init_d.d.name, decl_node);
            p.typedefDefined(interned_name, typedef_qt);
        } else if (init_d.initializer) |init| {
            // TODO validate global variable/constexpr initializer comptime known
            try p.syms.defineSymbol(
                p,
                interned_name,
                init_d.d.qt,
                init_d.d.name,
                decl_node,
                if (init_d.d.qt.@"const" or decl_spec.constexpr != null) init.val else .{},
                decl_spec.constexpr != null,
            );
        } else if (init_d.d.qt.is(p.comp, .func)) {
            try p.syms.declareSymbol(p, interned_name, init_d.d.qt, init_d.d.name, decl_node);
        } else if (p.func.qt != null and decl_spec.storage_class != .@"extern") {
            try p.syms.defineSymbol(p, interned_name, init_d.d.qt, init_d.d.name, decl_node, .{}, false);
        } else {
            try p.syms.declareSymbol(p, interned_name, init_d.d.qt, init_d.d.name, decl_node);
        }

        if (p.eatToken(.comma) == null) break;

        const attr_buf_top_declarator = p.attr_buf.len;
        defer p.attr_buf.len = attr_buf_top_declarator;

        try p.attributeSpecifierGnu();

        if (!warned_auto) {
            // TODO these are warnings in clang
            if (decl_spec.auto_type) |tok_i| {
                try p.err(tok_i, .auto_type_requires_single_declarator, .{});
                warned_auto = true;
            }
            if (decl_spec.c23_auto) |tok_i| {
                try p.err(tok_i, .c23_auto_single_declarator, .{});
                warned_auto = true;
            }
        }

        decl_node = try p.tree.addNode(.{ .empty_decl = .{
            .semicolon = p.tok_i - 1,
        } });
        init_d = (try p.initDeclarator(&decl_spec, attr_buf_top, decl_node)) orelse {
            try p.err(p.tok_i, .expected_ident_or_l_paren, .{});
            continue;
        };
    }

    _ = try p.expectToken(.semicolon);
    return true;
}

fn staticAssertMessage(p: *Parser, cond_node: Node.Index, maybe_message: ?Result, allocating: *std.Io.Writer.Allocating) !?[]const u8 {
    const w = &allocating.writer;

    const cond = cond_node.get(&p.tree);
    if (cond == .builtin_types_compatible_p) {
        try w.writeAll("'__builtin_types_compatible_p(");

        const lhs_ty = cond.builtin_types_compatible_p.lhs;
        try lhs_ty.print(p.comp, w);
        try w.writeAll(", ");

        const rhs_ty = cond.builtin_types_compatible_p.rhs;
        try rhs_ty.print(p.comp, w);

        try w.writeAll(")'");
    } else if (maybe_message == null) return null;

    if (maybe_message) |message| {
        assert(message.node.get(&p.tree) == .string_literal_expr);
        if (allocating.written().len > 0) {
            try w.writeByte(' ');
        }
        const bytes = p.comp.interner.get(message.val.ref()).bytes;
        try Value.printString(bytes, message.qt, p.comp, w);
    }
    return allocating.written();
}

/// staticAssert
///    : keyword_static_assert '(' integerConstExpr (',' STRING_LITERAL)? ')' ';'
///    | keyword_c23_static_assert '(' integerConstExpr (',' STRING_LITERAL)? ')' ';'
fn staticAssert(p: *Parser) Error!bool {
    const gpa = p.comp.gpa;
    const static_assert = p.eatToken(.keyword_static_assert) orelse p.eatToken(.keyword_c23_static_assert) orelse return false;
    const l_paren = try p.expectToken(.l_paren);
    const res_token = p.tok_i;
    var res = try p.constExpr(.gnu_folding_extension);
    const res_node = res.node;
    const str = if (p.eatToken(.comma) != null)
        switch (p.tok_ids[p.tok_i]) {
            .string_literal,
            .string_literal_utf_16,
            .string_literal_utf_8,
            .string_literal_utf_32,
            .string_literal_wide,
            .unterminated_string_literal,
            => try p.stringLiteral(),
            else => {
                try p.err(p.tok_i, .expected_str_literal, .{});
                return error.ParsingFailed;
            },
        }
    else
        null;
    try p.expectClosing(l_paren, .r_paren);
    _ = try p.expectToken(.semicolon);
    if (str == null) {
        try p.err(static_assert, .static_assert_missing_message, .{});
        try p.err(static_assert, .pre_c23_compat, .{"'_Static_assert' with no message"});
    }

    const is_int_expr = res.qt.isInvalid() or res.qt.isInt(p.comp);
    try res.castToBool(p, .bool, res_token);
    if (!is_int_expr) {
        res.val = .{};
    }
    if (res.val.opt_ref == .none) {
        if (!res.qt.isInvalid()) {
            try p.err(res_token, .static_assert_not_constant, .{});
        }
    } else {
        if (!res.val.toBool(p.comp)) {
            var sf = std.heap.stackFallback(1024, gpa);
            var allocating: std.Io.Writer.Allocating = .init(sf.get());
            defer allocating.deinit();

            if (p.staticAssertMessage(res_node, str, &allocating) catch return error.OutOfMemory) |message| {
                try p.err(static_assert, .static_assert_failure_message, .{message});
            } else {
                try p.err(static_assert, .static_assert_failure, .{});
            }
        }
    }

    const node = try p.addNode(.{
        .static_assert = .{
            .assert_tok = static_assert,
            .cond = res.node,
            .message = if (str) |some| some.node else null,
        },
    });
    try p.decl_buf.append(gpa, node);
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
    constexpr: ?TokenIndex = null,
    @"inline": ?TokenIndex = null,
    noreturn: ?TokenIndex = null,
    auto_type: ?TokenIndex = null,
    c23_auto: ?TokenIndex = null,
    qt: QualType,

    fn validateParam(d: DeclSpec, p: *Parser) Error!void {
        switch (d.storage_class) {
            .none, .register => {},
            .auto, .@"extern", .static, .typedef => |tok_i| try p.err(tok_i, .invalid_storage_on_param, .{}),
        }
        if (d.thread_local) |tok_i| try p.err(tok_i, .threadlocal_non_var, .{});
        if (d.@"inline") |tok_i| try p.err(tok_i, .func_spec_non_func, .{"inline"});
        if (d.noreturn) |tok_i| try p.err(tok_i, .func_spec_non_func, .{"_Noreturn"});
        if (d.constexpr) |tok_i| try p.err(tok_i, .invalid_storage_on_param, .{});
    }

    fn validateFnDef(d: DeclSpec, p: *Parser) Error!void {
        switch (d.storage_class) {
            .none, .@"extern", .static => {},
            .auto, .register, .typedef => |tok_i| try p.err(tok_i, .illegal_storage_on_func, .{}),
        }
        if (d.thread_local) |tok_i| try p.err(tok_i, .threadlocal_non_var, .{});
        if (d.constexpr) |tok_i| try p.err(tok_i, .illegal_storage_on_func, .{});
    }

    fn validateFnDecl(d: DeclSpec, p: *Parser) Error!void {
        switch (d.storage_class) {
            .none, .@"extern" => {},
            .static => |tok_i| if (p.func.qt != null) try p.err(tok_i, .static_func_not_global, .{}),
            .typedef => unreachable,
            .auto, .register => |tok_i| try p.err(tok_i, .illegal_storage_on_func, .{}),
        }
        if (d.thread_local) |tok_i| try p.err(tok_i, .threadlocal_non_var, .{});
        if (d.constexpr) |tok_i| try p.err(tok_i, .illegal_storage_on_func, .{});
    }

    fn validateDecl(d: DeclSpec, p: *Parser) Error!void {
        if (d.@"inline") |tok_i| try p.err(tok_i, .func_spec_non_func, .{"inline"});
        // TODO move to attribute validation
        if (d.noreturn) |tok_i| try p.err(tok_i, .func_spec_non_func, .{"_Noreturn"});
        switch (d.storage_class) {
            .auto => std.debug.assert(!p.comp.langopts.standard.atLeast(.c23)),
            .register => if (p.func.qt == null) try p.err(p.tok_i, .illegal_storage_on_global, .{}),
            else => {},
        }
    }

    fn initContext(d: DeclSpec, p: *Parser) InitContext {
        if (d.constexpr != null) return .constexpr;
        if (p.func.qt == null or d.storage_class == .static) return .static;
        return .runtime;
    }
};

/// typeof
///   : keyword_typeof '(' typeName ')'
///   | keyword_typeof '(' expr ')'
fn typeof(p: *Parser) Error!?QualType {
    const gpa = p.comp.gpa;
    var unqual = false;
    switch (p.tok_ids[p.tok_i]) {
        .keyword_typeof, .keyword_typeof1, .keyword_typeof2 => p.tok_i += 1,
        .keyword_typeof_unqual => {
            p.tok_i += 1;
            unqual = true;
        },
        else => return null,
    }
    const l_paren = try p.expectToken(.l_paren);
    if (try p.typeName()) |qt| {
        try p.expectClosing(l_paren, .r_paren);
        if (qt.isInvalid()) return null;

        return (try p.comp.type_store.put(gpa, .{ .typeof = .{
            .base = qt,
            .expr = null,
        } })).withQualifiers(qt);
    }
    const typeof_expr = try p.parseNoEval(expr);
    try p.expectClosing(l_paren, .r_paren);
    if (typeof_expr.qt.isInvalid()) return null;

    const typeof_qt = try p.comp.type_store.put(gpa, .{ .typeof = .{
        .base = typeof_expr.qt,
        .expr = typeof_expr.node,
    } });
    if (unqual) return typeof_qt;
    return typeof_qt.withQualifiers(typeof_expr.qt);
}

/// declSpec: (storageClassSpec | typeSpec | funcSpec | autoTypeSpec)+
/// funcSpec : keyword_inline | keyword_noreturn
/// autoTypeSpec : keyword_auto_type
fn declSpec(p: *Parser) Error!?DeclSpec {
    var d: DeclSpec = .{ .qt = .invalid };
    var builder: TypeStore.Builder = .{ .parser = p };

    const start = p.tok_i;
    while (true) {
        const id = p.tok_ids[p.tok_i];
        switch (id) {
            .keyword_inline, .keyword_inline1, .keyword_inline2 => {
                if (d.@"inline" != null) {
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"inline"});
                }
                d.@"inline" = p.tok_i;
                p.tok_i += 1;
                continue;
            },
            .keyword_noreturn => {
                if (d.noreturn != null) {
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"_Noreturn"});
                }
                d.noreturn = p.tok_i;
                p.tok_i += 1;
                continue;
            },
            .keyword_auto_type => {
                try p.err(p.tok_i, .auto_type_extension, .{});
                try builder.combine(.auto_type, p.tok_i);
                if (builder.type == .auto_type) d.auto_type = p.tok_i;
                p.tok_i += 1;
                continue;
            },
            .keyword_auto => if (p.comp.langopts.standard.atLeast(.c23)) {
                try builder.combine(.c23_auto, p.tok_i);
                if (builder.type == .c23_auto) d.c23_auto = p.tok_i;
                p.tok_i += 1;
                continue;
            },
            .keyword_forceinline, .keyword_forceinline2 => {
                try p.attr_buf.append(p.comp.gpa, .{
                    .attr = .{ .tag = .always_inline, .args = .{ .always_inline = .{} }, .syntax = .keyword },
                    .tok = p.tok_i,
                });
                p.tok_i += 1;
                continue;
            },
            else => {},
        }

        if (try p.storageClassSpec(&d)) continue;
        if (try p.typeSpec(&builder)) continue;
        if (p.tok_i == start) return null;

        d.qt = try builder.finish();
        return d;
    }
}

/// storageClassSpec:
///  : keyword_typedef
///  | keyword_extern
///  | keyword_static
///  | keyword_threadlocal
///  | keyword_auto
///  | keyword_register
fn storageClassSpec(p: *Parser, d: *DeclSpec) Error!bool {
    const start = p.tok_i;
    while (true) {
        const id = p.tok_ids[p.tok_i];
        switch (id) {
            .keyword_typedef,
            .keyword_extern,
            .keyword_static,
            .keyword_auto,
            .keyword_register,
            => {
                if (d.storage_class != .none) {
                    try p.err(p.tok_i, .multiple_storage_class, .{@tagName(d.storage_class)});
                    return error.ParsingFailed;
                }
                if (d.thread_local != null) {
                    switch (id) {
                        .keyword_extern, .keyword_static => {},
                        else => try p.err(p.tok_i, .cannot_combine_spec, .{id.lexeme().?}),
                    }
                    if (d.constexpr) |tok| try p.err(p.tok_i, .cannot_combine_spec, .{p.tok_ids[tok].lexeme().?});
                }
                if (d.constexpr != null) {
                    switch (id) {
                        .keyword_auto, .keyword_register, .keyword_static => {},
                        else => try p.err(p.tok_i, .cannot_combine_spec, .{id.lexeme().?}),
                    }
                    if (d.thread_local) |tok| try p.err(p.tok_i, .cannot_combine_spec, .{p.tok_ids[tok].lexeme().?});
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
            .keyword_thread_local,
            .keyword_c23_thread_local,
            => {
                if (d.thread_local != null) {
                    try p.err(p.tok_i, .duplicate_decl_spec, .{id.lexeme().?});
                }
                if (d.constexpr) |tok| try p.err(p.tok_i, .cannot_combine_spec, .{p.tok_ids[tok].lexeme().?});
                switch (d.storage_class) {
                    .@"extern", .none, .static => {},
                    else => try p.err(p.tok_i, .cannot_combine_spec, .{@tagName(d.storage_class)}),
                }
                d.thread_local = p.tok_i;
            },
            .keyword_constexpr => {
                if (d.constexpr != null) {
                    try p.err(p.tok_i, .duplicate_decl_spec, .{id.lexeme().?});
                }
                if (d.thread_local) |tok| try p.err(p.tok_i, .cannot_combine_spec, .{p.tok_ids[tok].lexeme().?});
                switch (d.storage_class) {
                    .auto, .register, .none, .static => {},
                    else => try p.err(p.tok_i, .cannot_combine_spec, .{@tagName(d.storage_class)}),
                }
                d.constexpr = p.tok_i;
            },
            else => break,
        }
        p.tok_i += 1;
    }
    return p.tok_i != start;
}

const InitDeclarator = struct { d: Declarator, initializer: ?Result = null };

/// attribute
///  : attrIdentifier
///  | attrIdentifier '(' identifier ')'
///  | attrIdentifier '(' identifier (',' expr)+ ')'
///  | attrIdentifier '(' (expr (',' expr)*)? ')'
fn attribute(p: *Parser, kind: Attribute.Kind, namespace: ?[]const u8) Error!?TentativeAttribute {
    const name_tok = p.tok_i;
    if (!p.tok_ids[p.tok_i].isMacroIdentifier()) {
        return p.errExpectedToken(.identifier, p.tok_ids[p.tok_i]);
    }
    _ = (try p.eatIdentifier()) orelse {
        p.tok_i += 1;
    };
    const name = p.tokSlice(name_tok);

    const attr = Attribute.fromString(kind, namespace, name) orelse {
        try p.err(name_tok, if (kind == .declspec) .declspec_attr_not_supported else .unknown_attribute, .{name});
        if (p.eatToken(.l_paren)) |_| p.skipTo(.r_paren);
        return null;
    };
    if (attr == .availability) {
        // TODO parse introduced=10.4 etc
        if (p.eatToken(.l_paren)) |_| p.skipTo(.r_paren);
        return null;
    }

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
                    if (try Attribute.diagnoseIdent(attr, &arguments, ident, p)) {
                        p.skipTo(.r_paren);
                        return error.ParsingFailed;
                    }
                } else {
                    try p.err(name_tok, .attribute_requires_identifier, .{name});
                    return error.ParsingFailed;
                }
            } else {
                const arg_start = p.tok_i;
                const first_expr = try p.expect(assignExpr);
                if (try p.diagnose(attr, &arguments, arg_idx, first_expr, arg_start)) {
                    p.skipTo(.r_paren);
                    return error.ParsingFailed;
                }
            }
            arg_idx += 1;
            while (p.eatToken(.r_paren) == null) : (arg_idx += 1) {
                _ = try p.expectToken(.comma);

                const arg_start = p.tok_i;
                const arg_expr = try p.expect(assignExpr);
                if (try p.diagnose(attr, &arguments, arg_idx, arg_expr, arg_start)) {
                    p.skipTo(.r_paren);
                    return error.ParsingFailed;
                }
            }
        },
        else => {},
    }
    if (arg_idx < required_count) {
        try p.err(name_tok, .attribute_not_enough_args, .{
            @tagName(attr), required_count,
        });
        return error.ParsingFailed;
    }
    return TentativeAttribute{ .attr = .{ .tag = attr, .args = arguments, .syntax = kind.toSyntax() }, .tok = name_tok };
}

fn diagnose(p: *Parser, attr: Attribute.Tag, arguments: *Attribute.Arguments, arg_idx: u32, res: Result, arg_start: TokenIndex) !bool {
    if (Attribute.wantsAlignment(attr, arg_idx)) {
        return Attribute.diagnoseAlignment(attr, arguments, arg_idx, res, arg_start, p);
    }
    return Attribute.diagnose(attr, arguments, arg_idx, res, arg_start, res.node.get(&p.tree), p);
}

/// attributeList : (attribute (',' attribute)*)?
fn gnuAttributeList(p: *Parser) Error!void {
    if (p.tok_ids[p.tok_i] == .r_paren) return;
    const gpa = p.comp.gpa;

    if (try p.attribute(.gnu, null)) |attr| try p.attr_buf.append(gpa, attr);
    while (p.tok_ids[p.tok_i] != .r_paren) {
        _ = try p.expectToken(.comma);
        if (try p.attribute(.gnu, null)) |attr| try p.attr_buf.append(gpa, attr);
    }
}

fn c23AttributeList(p: *Parser) Error!void {
    while (p.tok_ids[p.tok_i] != .r_bracket) {
        const namespace_tok = try p.expectIdentifier();
        var namespace: ?[]const u8 = null;
        if (p.eatToken(.colon_colon)) |_| {
            namespace = p.tokSlice(namespace_tok);
        } else {
            p.tok_i -= 1;
        }
        if (try p.attribute(.c23, namespace)) |attr| try p.attr_buf.append(p.comp.gpa, attr);
        _ = p.eatToken(.comma);
    }
}

fn msvcAttributeList(p: *Parser) Error!void {
    while (p.tok_ids[p.tok_i] != .r_paren) {
        if (try p.attribute(.declspec, null)) |attr| try p.attr_buf.append(p.comp.gpa, attr);
        _ = p.eatToken(.comma);
    }
}

fn c23Attribute(p: *Parser) !bool {
    if (!p.comp.langopts.standard.atLeast(.c23)) return false;
    const bracket1 = p.eatToken(.l_bracket) orelse return false;
    const bracket2 = p.eatToken(.l_bracket) orelse {
        p.tok_i -= 1;
        return false;
    };

    try p.c23AttributeList();

    _ = try p.expectClosing(bracket2, .r_bracket);
    _ = try p.expectClosing(bracket1, .r_bracket);

    return true;
}

fn msvcAttribute(p: *Parser) !bool {
    _ = p.eatToken(.keyword_declspec) orelse return false;
    const l_paren = try p.expectToken(.l_paren);
    try p.msvcAttributeList();
    _ = try p.expectClosing(l_paren, .r_paren);

    return true;
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

fn attributeSpecifierGnu(p: *Parser) Error!void {
    while (true) {
        if (try p.gnuAttribute()) continue;

        const tok = p.tok_i;
        const attr_buf_top_declarator = p.attr_buf.len;
        defer p.attr_buf.len = attr_buf_top_declarator;

        if (try p.c23Attribute()) {
            try p.err(tok, .invalid_attribute_location, .{"an attribute list"});
            continue;
        }
        if (try p.msvcAttribute()) {
            try p.err(tok, .invalid_attribute_location, .{"a declspec attribute"});
            continue;
        }
        break;
    }
}

fn attributeSpecifier(p: *Parser) Error!void {
    return attributeSpecifierExtra(p, null);
}

/// attributeSpecifier : (keyword_attribute '( '(' attributeList ')' ')')*
fn attributeSpecifierExtra(p: *Parser, declarator_name: ?TokenIndex) Error!void {
    while (true) {
        if (try p.gnuAttribute()) continue;
        if (try p.c23Attribute()) continue;
        const maybe_declspec_tok = p.tok_i;
        const attr_buf_top = p.attr_buf.len;
        if (try p.msvcAttribute()) {
            if (declarator_name) |name_tok| {
                try p.err(maybe_declspec_tok, .declspec_not_allowed_after_declarator, .{});
                try p.err(name_tok, .declarator_name_tok, .{});
                p.attr_buf.len = attr_buf_top;
            }
            continue;
        }
        break;
    }
}

/// initDeclarator : declarator assembly? attributeSpecifier? ('=' initializer)?
fn initDeclarator(p: *Parser, decl_spec: *DeclSpec, attr_buf_top: usize, decl_node: Node.Index) Error!?InitDeclarator {
    const this_attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = this_attr_buf_top;
    const gpa = p.comp.gpa;

    var init_d = InitDeclarator{
        .d = (try p.declarator(decl_spec.qt, .normal)) orelse return null,
    };

    try p.attributeSpecifierExtra(init_d.d.name);
    _ = try p.assembly(.decl_label);
    try p.attributeSpecifierExtra(init_d.d.name);

    switch (init_d.d.declarator_type) {
        .func => {
            if (decl_spec.auto_type) |tok_i| {
                try p.err(tok_i, .auto_type_not_allowed, .{"function return type"});
                init_d.d.qt = .invalid;
            } else if (decl_spec.c23_auto) |tok_i| {
                try p.err(tok_i, .c23_auto_not_allowed, .{"function return type"});
                init_d.d.qt = .invalid;
            }
        },
        .array => {
            if (decl_spec.auto_type) |tok_i| {
                try p.err(tok_i, .auto_type_array, .{p.tokSlice(init_d.d.name)});
                init_d.d.qt = .invalid;
            } else if (decl_spec.c23_auto) |tok_i| {
                try p.err(tok_i, .c23_auto_array, .{p.tokSlice(init_d.d.name)});
                init_d.d.qt = .invalid;
            }
        },
        .pointer => {
            if (decl_spec.auto_type != null or decl_spec.c23_auto != null) {
                // TODO this is not a hard error in clang
                try p.err(p.tok_i, .auto_type_requires_plain_declarator, .{});
                init_d.d.qt = .invalid;
            }
        },
        .other => if (decl_spec.storage_class == .typedef) {
            if (decl_spec.auto_type) |tok_i| {
                try p.err(tok_i, .auto_type_not_allowed, .{"typedef"});
                init_d.d.qt = .invalid;
            } else if (decl_spec.c23_auto) |tok_i| {
                try p.err(tok_i, .c23_auto_not_allowed, .{"typedef"});
                init_d.d.qt = .invalid;
            }
        },
    }

    var apply_var_attributes = false;
    if (decl_spec.storage_class == .typedef) {
        init_d.d.qt = try Attribute.applyTypeAttributes(p, init_d.d.qt, attr_buf_top, null);
    } else if (init_d.d.declarator_type == .func or init_d.d.qt.is(p.comp, .func)) {
        init_d.d.qt = try Attribute.applyFunctionAttributes(p, init_d.d.qt, attr_buf_top);
    } else {
        apply_var_attributes = true;
    }

    if (p.eatToken(.equal)) |eq| {
        if (decl_spec.storage_class == .typedef or
            (init_d.d.declarator_type == .func and init_d.d.qt.is(p.comp, .func)))
        {
            try p.err(eq, .illegal_initializer, .{});
        } else if (init_d.d.qt.get(p.comp, .array)) |array_ty| {
            if (array_ty.len == .variable) try p.err(eq, .vla_init, .{});
        } else if (decl_spec.storage_class == .@"extern") {
            try p.err(p.tok_i, .extern_initializer, .{});
            decl_spec.storage_class = .none;
        }

        incomplete: {
            if (init_d.d.qt.isInvalid()) break :incomplete;
            if (init_d.d.qt.isC23Auto()) break :incomplete;
            if (init_d.d.qt.isAutoType()) break :incomplete;
            if (!init_d.d.qt.hasIncompleteSize(p.comp)) break :incomplete;
            if (init_d.d.qt.get(p.comp, .array)) |array_ty| {
                if (array_ty.len == .incomplete) break :incomplete;
            }
            try p.err(init_d.d.name, .variable_incomplete_ty, .{init_d.d.qt});
            init_d.d.qt = .invalid;
        }

        try p.syms.pushScope(p);
        defer p.syms.popScope();

        const interned_name = try p.comp.internString(p.tokSlice(init_d.d.name));
        try p.syms.declareSymbol(p, interned_name, init_d.d.qt, init_d.d.name, decl_node);

        // TODO this should be a stack of auto type names because of statement expressions.
        if (init_d.d.qt.isAutoType() or init_d.d.qt.isC23Auto()) {
            p.auto_type_decl_name = interned_name;
        }
        defer p.auto_type_decl_name = .empty;

        const init_context = p.init_context;
        defer p.init_context = init_context;
        p.init_context = decl_spec.initContext(p);
        var init_list_expr = try p.initializer(init_d.d.qt);
        init_d.initializer = init_list_expr;

        // Set incomplete array length if possible.
        if (init_d.d.qt.get(p.comp, .array)) |base_array_ty| {
            if (base_array_ty.len == .incomplete) if (init_list_expr.qt.get(p.comp, .array)) |init_array_ty| {
                switch (init_array_ty.len) {
                    .fixed, .static => |len| {
                        init_d.d.qt = (try p.comp.type_store.put(gpa, .{ .array = .{
                            .elem = base_array_ty.elem,
                            .len = .{ .fixed = len },
                        } })).withQualifiers(init_d.d.qt);
                    },
                    else => {},
                }
            };
        }
    }

    const name = init_d.d.name;
    if (init_d.d.qt.isAutoType() or init_d.d.qt.isC23Auto()) {
        if (init_d.initializer) |some| {
            init_d.d.qt = some.qt.withQualifiers(init_d.d.qt);
        } else {
            if (init_d.d.qt.isC23Auto()) {
                try p.err(name, .c23_auto_requires_initializer, .{});
            } else {
                try p.err(name, .auto_type_requires_initializer, .{p.tokSlice(name)});
            }
            init_d.d.qt = .invalid;
            return init_d;
        }
    }
    if (apply_var_attributes) {
        init_d.d.qt = try Attribute.applyVariableAttributes(p, init_d.d.qt, attr_buf_top, null);
    }

    incomplete: {
        if (decl_spec.storage_class == .typedef) break :incomplete;
        if (init_d.d.qt.isInvalid()) break :incomplete;
        if (!init_d.d.qt.hasIncompleteSize(p.comp)) break :incomplete;

        const init_type = init_d.d.qt.base(p.comp).type;
        if (decl_spec.storage_class == .@"extern") switch (init_type) {
            .@"struct", .@"union", .@"enum" => break :incomplete,
            .array => |array_ty| if (array_ty.len == .incomplete) break :incomplete,
            else => {},
        };
        // if there was an initializer expression it must have contained an error
        if (init_d.initializer != null) break :incomplete;

        if (p.func.qt == null) {
            switch (init_type) {
                .array => |array_ty| if (array_ty.len == .incomplete) {
                    // TODO properly check this after finishing parsing
                    try p.err(name, .tentative_array, .{});
                    break :incomplete;
                },
                .@"struct", .@"union" => |record_ty| {
                    _ = try p.tentative_defs.getOrPutValue(gpa, record_ty.name, init_d.d.name);
                    break :incomplete;
                },
                .@"enum" => |enum_ty| {
                    _ = try p.tentative_defs.getOrPutValue(gpa, enum_ty.name, init_d.d.name);
                    break :incomplete;
                },
                else => {},
            }
        }
        try p.err(name, .variable_incomplete_ty, .{init_d.d.qt});
        init_d.d.qt = .invalid;
    }
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
///  | keyword_signed1
///  | keyword_signed2
///  | keyword_unsigned
///  | keyword_bool
///  | keyword_c23_bool
///  | keyword_complex
///  | keyword_atomic '(' typeName ')'
///  | recordSpec
///  | enumSpec
///  | typedef  // IDENTIFIER
///  | typeof
///  | keyword_bit_int '(' integerConstExpr ')'
///  | typeQual
///  | keyword_alignas '(' typeName ')'
///  | keyword_alignas '(' integerConstExpr ')'
///  | keyword_c23_alignas '(' typeName ')'
///  | keyword_c23_alignas '(' integerConstExpr ')'
fn typeSpec(p: *Parser, builder: *TypeStore.Builder) Error!bool {
    const start = p.tok_i;
    while (true) {
        try p.attributeSpecifier();

        if (try p.typeof()) |typeof_qt| {
            try builder.combineFromTypeof(typeof_qt, start);
            continue;
        }
        if (try p.typeQual(builder, true)) continue;
        switch (p.tok_ids[p.tok_i]) {
            .keyword_void => try builder.combine(.void, p.tok_i),
            .keyword_bool, .keyword_c23_bool => try builder.combine(.bool, p.tok_i),
            .keyword_int8, .keyword_int8_2, .keyword_char => try builder.combine(.char, p.tok_i),
            .keyword_int16, .keyword_int16_2, .keyword_short => try builder.combine(.short, p.tok_i),
            .keyword_int32, .keyword_int32_2, .keyword_int => try builder.combine(.int, p.tok_i),
            .keyword_long => try builder.combine(.long, p.tok_i),
            .keyword_int64, .keyword_int64_2 => try builder.combine(.long_long, p.tok_i),
            .keyword_int128 => try builder.combine(.int128, p.tok_i),
            .keyword_signed, .keyword_signed1, .keyword_signed2 => try builder.combine(.signed, p.tok_i),
            .keyword_unsigned => try builder.combine(.unsigned, p.tok_i),
            .keyword_fp16 => try builder.combine(.fp16, p.tok_i),
            .keyword_bf16 => try builder.combine(.bf16, p.tok_i),
            .keyword_float16 => try builder.combine(.float16, p.tok_i),
            .keyword_float32 => try builder.combine(.float32, p.tok_i),
            .keyword_float64 => try builder.combine(.float64, p.tok_i),
            .keyword_float32x => try builder.combine(.float32x, p.tok_i),
            .keyword_float64x => try builder.combine(.float64x, p.tok_i),
            .keyword_float128x => {
                try p.err(p.tok_i, .type_not_supported_on_target, .{p.tok_ids[p.tok_i].lexeme().?});
                return error.ParsingFailed;
            },
            .keyword_dfloat32 => try builder.combine(.dfloat32, p.tok_i),
            .keyword_dfloat64 => try builder.combine(.dfloat64, p.tok_i),
            .keyword_dfloat128 => try builder.combine(.dfloat128, p.tok_i),
            .keyword_dfloat64x => try builder.combine(.dfloat64x, p.tok_i),
            .keyword_float => try builder.combine(.float, p.tok_i),
            .keyword_double => try builder.combine(.double, p.tok_i),
            .keyword_complex => try builder.combine(.complex, p.tok_i),
            .keyword_float128, .keyword_float128_1 => {
                if (!p.comp.hasFloat128()) {
                    try p.err(p.tok_i, .type_not_supported_on_target, .{p.tok_ids[p.tok_i].lexeme().?});
                }
                try builder.combine(.float128, p.tok_i);
            },
            .keyword_atomic => {
                const atomic_tok = p.tok_i;
                p.tok_i += 1;
                const l_paren = p.eatToken(.l_paren) orelse {
                    // _Atomic qualifier not _Atomic(typeName)
                    p.tok_i = atomic_tok;
                    break;
                };
                const base_qt = (try p.typeName()) orelse {
                    try p.err(p.tok_i, .expected_type, .{});
                    return error.ParsingFailed;
                };
                try p.expectClosing(l_paren, .r_paren);

                if (base_qt.isQualified() and !base_qt.isInvalid()) {
                    try p.err(atomic_tok, .atomic_qualified, .{base_qt});
                    builder.type = .{ .other = .invalid };
                    continue;
                }

                try builder.combineAtomic(base_qt, atomic_tok);
                continue;
            },
            .keyword_alignas,
            .keyword_c23_alignas,
            => {
                const align_tok = p.tok_i;
                p.tok_i += 1;
                const gpa = p.comp.gpa;
                const l_paren = try p.expectToken(.l_paren);
                const typename_start = p.tok_i;
                if (try p.typeName()) |inner_qt| {
                    if (!inner_qt.alignable(p.comp)) {
                        try p.err(typename_start, .invalid_alignof, .{inner_qt});
                    }
                    const alignment = Attribute.Alignment{ .requested = inner_qt.alignof(p.comp) };
                    try p.attr_buf.append(gpa, .{
                        .attr = .{ .tag = .aligned, .args = .{
                            .aligned = .{ .alignment = alignment, .__name_tok = align_tok },
                        }, .syntax = .keyword },
                        .tok = align_tok,
                    });
                } else {
                    const arg_start = p.tok_i;
                    const res = try p.integerConstExpr(.no_const_decl_folding);
                    if (!res.val.isZero(p.comp)) {
                        var args = Attribute.initArguments(.aligned, align_tok);
                        if (try p.diagnose(.aligned, &args, 0, res, arg_start)) {
                            p.skipTo(.r_paren);
                            return error.ParsingFailed;
                        }
                        args.aligned.alignment.?.node = .pack(res.node);
                        try p.attr_buf.append(gpa, .{
                            .attr = .{ .tag = .aligned, .args = args, .syntax = .keyword },
                            .tok = align_tok,
                        });
                    }
                }
                try p.expectClosing(l_paren, .r_paren);
                continue;
            },
            .keyword_struct, .keyword_union => {
                const tag_tok = p.tok_i;
                const record_ty = try p.recordSpec();
                try builder.combine(.{ .other = record_ty }, tag_tok);
                continue;
            },
            .keyword_enum => {
                const tag_tok = p.tok_i;
                const enum_ty = try p.enumSpec();
                try builder.combine(.{ .other = enum_ty }, tag_tok);
                continue;
            },
            .identifier, .extended_identifier => {
                var interned_name = try p.comp.internString(p.tokSlice(p.tok_i));
                var declspec_found = false;

                if (interned_name == p.string_ids.declspec_id) {
                    try p.err(p.tok_i, .declspec_not_enabled, .{});
                    p.tok_i += 1;
                    if (p.eatToken(.l_paren)) |_| {
                        p.skipTo(.r_paren);
                        continue;
                    }
                    declspec_found = true;
                }
                if (declspec_found) {
                    interned_name = try p.comp.internString(p.tokSlice(p.tok_i));
                }
                const typedef = (try p.syms.findTypedef(p, interned_name, p.tok_i, builder.type != .none)) orelse break;
                if (!builder.combineTypedef(typedef.qt)) break;
            },
            .keyword_bit_int => {
                try p.err(p.tok_i, .bit_int, .{});
                const bit_int_tok = p.tok_i;
                p.tok_i += 1;
                const l_paren = try p.expectToken(.l_paren);
                const res = try p.integerConstExpr(.gnu_folding_extension);
                try p.expectClosing(l_paren, .r_paren);

                var bits: u64 = undefined;
                if (res.val.opt_ref == .none) {
                    try p.err(bit_int_tok, .expected_integer_constant_expr, .{});
                    return error.ParsingFailed;
                } else if (res.val.compare(.lte, .zero, p.comp)) {
                    bits = 0;
                } else {
                    bits = res.val.toInt(u64, p.comp) orelse std.math.maxInt(u64);
                }

                try builder.combine(.{ .bit_int = bits }, bit_int_tok);
                continue;
            },
            else => break,
        }
        // consume single token specifiers here
        p.tok_i += 1;
    }
    return p.tok_i != start;
}

fn getAnonymousName(p: *Parser, kind_tok: TokenIndex) !StringId {
    const loc = p.pp.tokens.items(.loc)[kind_tok];
    const source = p.comp.getSource(loc.id);
    const line_col = source.lineCol(loc);

    const kind_str = switch (p.tok_ids[kind_tok]) {
        .keyword_struct, .keyword_union, .keyword_enum => p.tokSlice(kind_tok),
        else => "record field",
    };

    var arena = p.comp.type_store.anon_name_arena.promote(p.comp.gpa);
    defer p.comp.type_store.anon_name_arena = arena.state;
    const str = try std.fmt.allocPrint(
        arena.allocator(),
        "(anonymous {s} at {s}:{d}:{d})",
        .{ kind_str, source.path, line_col.line_no, line_col.col },
    );
    return p.comp.internString(str);
}

/// recordSpec
///  : (keyword_struct | keyword_union) IDENTIFIER? { recordDecls }
///  | (keyword_struct | keyword_union) IDENTIFIER
fn recordSpec(p: *Parser) Error!QualType {
    const gpa = p.comp.gpa;
    const starting_pragma_pack = p.pragma_pack;
    const kind_tok = p.tok_i;
    const is_struct = p.tok_ids[kind_tok] == .keyword_struct;
    p.tok_i += 1;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier();

    const reserved_index = try p.tree.nodes.addOne(gpa);

    const maybe_ident = try p.eatIdentifier();
    const l_brace = p.eatToken(.l_brace) orelse {
        const ident = maybe_ident orelse {
            try p.err(p.tok_i, .ident_or_l_brace, .{});
            return error.ParsingFailed;
        };
        // check if this is a reference to a previous type
        const interned_name = try p.comp.internString(p.tokSlice(ident));
        if (try p.syms.findTag(p, interned_name, p.tok_ids[kind_tok], ident, p.tok_ids[p.tok_i])) |prev| {
            return prev.qt;
        } else {
            // this is a forward declaration, create a new record type.
            const record_ty: Type.Record = .{
                .name = interned_name,
                .layout = null,
                .decl_node = @enumFromInt(reserved_index),
                .fields = &.{},
            };
            const record_qt = try p.comp.type_store.put(gpa, if (is_struct)
                .{ .@"struct" = record_ty }
            else
                .{ .@"union" = record_ty });

            const attributed_qt = try Attribute.applyTypeAttributes(p, record_qt, attr_buf_top, null);
            try p.syms.define(gpa, .{
                .kind = if (is_struct) .@"struct" else .@"union",
                .name = interned_name,
                .tok = ident,
                .qt = attributed_qt,
                .val = .{},
            });

            const fw: Node.ContainerForwardDecl = .{
                .name_or_kind_tok = ident,
                .container_qt = attributed_qt,
                .definition = null,
            };
            try p.tree.setNode(if (is_struct)
                .{ .struct_forward_decl = fw }
            else
                .{ .union_forward_decl = fw }, reserved_index);
            try p.decl_buf.append(gpa, @enumFromInt(reserved_index));
            return attributed_qt;
        }
    };

    var done = false;
    errdefer if (!done) p.skipTo(.r_brace);

    // Get forward declared type or create a new one
    var record_ty: Type.Record, const qt: QualType = blk: {
        const interned_name = if (maybe_ident) |ident| interned: {
            const ident_str = p.tokSlice(ident);
            const interned_name = try p.comp.internString(ident_str);
            if (try p.syms.defineTag(p, interned_name, p.tok_ids[kind_tok], ident)) |prev| {
                const record_ty = prev.qt.getRecord(p.comp).?;
                if (record_ty.layout != null) {
                    // if the record isn't incomplete, this is a redefinition
                    try p.err(ident, .redefinition, .{ident_str});
                    try p.err(prev.tok, .previous_definition, .{});
                } else {
                    break :blk .{ record_ty, prev.qt };
                }
            }
            break :interned interned_name;
        } else try p.getAnonymousName(kind_tok);

        // Initially create ty as a regular non-attributed type, since attributes for a record
        // can be specified after the closing rbrace, which we haven't encountered yet.
        const record_ty: Type.Record = .{
            .name = interned_name,
            .decl_node = @enumFromInt(reserved_index),
            .layout = null,
            .fields = &.{},
        };
        const record_qt = try p.comp.type_store.put(gpa, if (is_struct)
            .{ .@"struct" = record_ty }
        else
            .{ .@"union" = record_ty });

        // declare a symbol for the type
        // We need to replace the symbol's type if it has attributes
        if (maybe_ident != null) {
            try p.syms.define(gpa, .{
                .kind = if (is_struct) .@"struct" else .@"union",
                .name = record_ty.name,
                .tok = maybe_ident.?,
                .qt = record_qt,
                .val = .{},
            });
        }

        break :blk .{ record_ty, record_qt };
    };

    try p.decl_buf.append(gpa, @enumFromInt(reserved_index));
    const decl_buf_top = p.decl_buf.items.len;
    const record_buf_top = p.record_buf.items.len;
    errdefer p.decl_buf.items.len = decl_buf_top - 1;
    defer {
        p.decl_buf.items.len = decl_buf_top;
        p.record_buf.items.len = record_buf_top;
    }

    const old_record = p.record;
    const old_members = p.record_members.items.len;
    p.record = .{
        .kind = p.tok_ids[kind_tok],
        .start = p.record_members.items.len,
    };
    defer p.record = old_record;
    defer p.record_members.items.len = old_members;

    try p.recordDecls();

    const fields = p.record_buf.items[record_buf_top..];

    if (p.record.flexible_field) |some| {
        if (fields.len == 1 and is_struct) {
            if (p.comp.langopts.emulate == .msvc) {
                try p.err(some, .flexible_in_empty_msvc, .{});
            } else {
                try p.err(some, .flexible_in_empty, .{});
            }
        }
    }

    if (p.record_buf.items.len == record_buf_top) {
        try p.err(kind_tok, .empty_record, .{p.tokSlice(kind_tok)});
        try p.err(kind_tok, .empty_record_size, .{p.tokSlice(kind_tok)});
    }
    try p.expectClosing(l_brace, .r_brace);
    done = true;
    try p.attributeSpecifier();

    const any_incomplete = blk: {
        for (fields) |field| {
            if (field.qt.hasIncompleteSize(p.comp) and !field.qt.is(p.comp, .array)) break :blk true;
        }
        // Set fields and a dummy layout before addign attributes.
        record_ty.fields = fields;
        record_ty.layout = .{
            .size_bits = 8,
            .field_alignment_bits = 8,
            .pointer_alignment_bits = 8,
            .required_alignment_bits = 8,
        };
        record_ty.decl_node = @enumFromInt(reserved_index);

        const base_type = qt.base(p.comp);
        if (is_struct) {
            std.debug.assert(base_type.type.@"struct".name == record_ty.name);
            try p.comp.type_store.set(gpa, .{ .@"struct" = record_ty }, @intFromEnum(base_type.qt._index));
        } else {
            std.debug.assert(base_type.type.@"union".name == record_ty.name);
            try p.comp.type_store.set(gpa, .{ .@"union" = record_ty }, @intFromEnum(base_type.qt._index));
        }
        break :blk false;
    };

    const attributed_qt = try Attribute.applyTypeAttributes(p, qt, attr_buf_top, null);

    // Make sure the symbol for this record points to the attributed type.
    if (attributed_qt != qt and maybe_ident != null) {
        const ident_str = p.tokSlice(maybe_ident.?);
        const interned_name = try p.comp.internString(ident_str);
        const ptr = p.syms.getPtr(interned_name, .tags);
        ptr.qt = attributed_qt;
    }

    if (!any_incomplete) {
        const pragma_pack_value = switch (p.comp.langopts.emulate) {
            .clang => starting_pragma_pack,
            .gcc => p.pragma_pack,
            // TODO: msvc considers `#pragma pack` on a per-field basis
            .msvc => p.pragma_pack,
        };
        if (record_layout.compute(fields, attributed_qt, p.comp, pragma_pack_value)) |layout| {
            record_ty.fields = fields;
            record_ty.layout = layout;
        } else |er| switch (er) {
            error.Overflow => try p.err(maybe_ident orelse kind_tok, .record_too_large, .{qt}),
        }

        // Override previous incomplete layout and fields.
        const base_qt = qt.base(p.comp).qt;
        const ts = &p.comp.type_store;
        var extra_index = ts.types.items(.data)[@intFromEnum(base_qt._index)][1];

        const layout_size = 5;
        comptime std.debug.assert(@sizeOf(Type.Record.Layout) == @sizeOf(u32) * layout_size);
        const field_size = 10;
        comptime std.debug.assert(@sizeOf(Type.Record.Field) == @sizeOf(u32) * field_size);

        extra_index += 1; // For decl_node
        const casted_layout: *const [layout_size]u32 = @ptrCast(&record_ty.layout);
        ts.extra.items[extra_index..][0..layout_size].* = casted_layout.*;
        extra_index += layout_size;
        extra_index += 1; // For field length

        for (record_ty.fields) |*field| {
            const casted: *const [field_size]u32 = @ptrCast(field);
            ts.extra.items[extra_index..][0..field_size].* = casted.*;
            extra_index += field_size;
        }
    }

    // finish by creating a node
    const cd: Node.ContainerDecl = .{
        .name_or_kind_tok = maybe_ident orelse kind_tok,
        .container_qt = attributed_qt,
        .fields = p.decl_buf.items[decl_buf_top..],
    };
    try p.tree.setNode(if (is_struct) .{ .struct_decl = cd } else .{ .union_decl = cd }, reserved_index);
    if (p.func.qt == null) {
        _ = p.tentative_defs.remove(record_ty.name);
    }
    return attributed_qt;
}

/// recordDecls : (keyword_extension? recordDecl | staticAssert)*
fn recordDecls(p: *Parser) Error!void {
    while (true) {
        if (try p.pragma()) continue;
        if (try p.parseOrNextDecl(staticAssert)) continue;
        if (p.eatToken(.keyword_extension)) |_| {
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            if (try p.parseOrNextDecl(recordDecl)) continue;
            try p.err(p.tok_i, .expected_type, .{});
            p.nextExternDecl();
            continue;
        }
        if (try p.parseOrNextDecl(recordDecl)) continue;
        break;
    }
}

/// recordDecl : typeSpec+ (recordDeclarator (',' recordDeclarator)*)?
/// recordDeclarator : declarator (':' integerConstExpr)?
fn recordDecl(p: *Parser) Error!bool {
    const gpa = p.comp.gpa;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;

    const base_qt: QualType = blk: {
        const start = p.tok_i;
        var builder: TypeStore.Builder = .{ .parser = p };
        while (true) {
            if (try p.typeSpec(&builder)) continue;
            const id = p.tok_ids[p.tok_i];
            switch (id) {
                .keyword_auto => {
                    if (!p.comp.langopts.standard.atLeast(.c23)) break;

                    try p.err(p.tok_i, .c23_auto_not_allowed, .{if (p.record.kind == .keyword_struct) "struct member" else "union member"});
                    try builder.combine(.c23_auto, p.tok_i);
                },
                .keyword_auto_type => {
                    try p.err(p.tok_i, .auto_type_extension, .{});
                    try p.err(p.tok_i, .auto_type_not_allowed, .{if (p.record.kind == .keyword_struct) "struct member" else "union member"});
                    try builder.combine(.auto_type, p.tok_i);
                },
                .identifier, .extended_identifier => {
                    if (builder.type != .none) break;
                    try p.err(p.tok_i, .unknown_type_name, .{p.tokSlice(p.tok_i)});
                    builder.type = .{ .other = .invalid };
                },
                else => break,
            }
            p.tok_i += 1;
            break;
        }
        if (p.tok_i == start) return false;
        break :blk switch (builder.type) {
            .auto_type, .c23_auto => .invalid,
            else => try builder.finish(),
        };
    };

    try p.attributeSpecifier(); // .record
    var error_on_unnamed = false;
    while (true) {
        const this_decl_top = p.attr_buf.len;
        defer p.attr_buf.len = this_decl_top;

        try p.attributeSpecifier();

        // 0 means unnamed
        var name_tok: TokenIndex = 0;
        var qt = base_qt;
        var bits_node: ?Node.Index = null;
        var bits: ?u32 = null;
        const first_tok = p.tok_i;
        if (try p.declarator(qt, .record)) |d| {
            name_tok = d.name;
            qt = d.qt;
            error_on_unnamed = true;
        }

        if (p.eatToken(.colon)) |_| bits: {
            const bits_tok = p.tok_i;
            const res = try p.integerConstExpr(.gnu_folding_extension);
            if (!qt.isInvalid() and !qt.isRealInt(p.comp)) {
                try p.err(first_tok, .non_int_bitfield, .{qt});
                break :bits;
            }

            if (res.val.opt_ref == .none) {
                try p.err(bits_tok, .expected_integer_constant_expr, .{});
                break :bits;
            } else if (res.val.compare(.lt, .zero, p.comp)) {
                try p.err(first_tok, .negative_bitwidth, .{res});
                break :bits;
            }

            // incomplete size error is reported later
            const bit_size = qt.bitSizeofOrNull(p.comp) orelse break :bits;
            const bits_unchecked = res.val.toInt(u32, p.comp) orelse std.math.maxInt(u32);
            if (bits_unchecked > bit_size) {
                try p.err(name_tok, .bitfield_too_big, .{});
                break :bits;
            } else if (bits_unchecked == 0 and name_tok != 0) {
                try p.err(name_tok, .zero_width_named_field, .{});
                break :bits;
            }

            bits = bits_unchecked;
            bits_node = res.node;
        }

        try p.attributeSpecifier(); // .record

        const to_append = try Attribute.applyFieldAttributes(p, &qt, attr_buf_top);

        const attr_index: u32 = @intCast(p.comp.type_store.attributes.items.len);
        const attr_len: u32 = @intCast(to_append.len);
        try p.comp.type_store.attributes.appendSlice(gpa, to_append);

        qt = try Attribute.applyTypeAttributes(p, qt, attr_buf_top, null);
        @memset(p.attr_buf.items(.seen)[attr_buf_top..], false);

        if (name_tok == 0 and bits == null) unnamed: {
            var is_typedef = false;
            if (!qt.isInvalid()) loop: switch (qt.type(p.comp)) {
                .attributed => |attributed_ty| continue :loop attributed_ty.base.type(p.comp),
                .typedef => |typedef_ty| {
                    is_typedef = true;
                    continue :loop typedef_ty.base.type(p.comp);
                },
                // typeof intentionally ignored here
                .@"enum" => break :unnamed,
                .@"struct", .@"union" => |record_ty| if ((record_ty.isAnonymous(p.comp) and !is_typedef) or
                    (p.comp.langopts.ms_extensions and is_typedef))
                {
                    if (!(record_ty.isAnonymous(p.comp) and !is_typedef)) {
                        try p.err(first_tok, .anonymous_struct, .{});
                    }
                    // An anonymous record appears as indirect fields on the parent
                    try p.record_buf.append(gpa, .{
                        .name = try p.getAnonymousName(first_tok),
                        .qt = qt,
                        ._attr_index = attr_index,
                        ._attr_len = attr_len,
                    });

                    const node = try p.addNode(.{
                        .record_field = .{
                            .name_or_first_tok = name_tok,
                            .qt = qt,
                            .bit_width = null,
                        },
                    });
                    try p.decl_buf.append(gpa, node);
                    try p.record.addFieldsFromAnonymous(p, record_ty);
                    break; // must be followed by a semicolon
                },
                else => {},
            };
            if (error_on_unnamed) {
                try p.err(first_tok, .expected_member_name, .{});
            } else {
                try p.err(p.tok_i, .missing_declaration, .{});
            }
            if (p.eatToken(.comma) == null) break;
            continue;
        } else {
            const interned_name = if (name_tok != 0) try p.comp.internString(p.tokSlice(name_tok)) else try p.getAnonymousName(first_tok);
            try p.record_buf.append(gpa, .{
                .name = interned_name,
                .qt = qt,
                .name_tok = name_tok,
                .bit_width = if (bits) |some| @enumFromInt(some) else .null,
                ._attr_index = attr_index,
                ._attr_len = attr_len,
            });
            if (name_tok != 0) try p.record.addField(p, interned_name, name_tok);
            const node = try p.addNode(.{
                .record_field = .{
                    .name_or_first_tok = name_tok,
                    .qt = qt,
                    .bit_width = bits_node,
                },
            });
            try p.decl_buf.append(gpa, node);
        }

        if (!qt.isInvalid()) {
            const field_type = qt.base(p.comp);
            switch (field_type.type) {
                .func => {
                    try p.err(first_tok, .func_field, .{});
                    qt = .invalid;
                },
                .array => |array_ty| switch (array_ty.len) {
                    .static, .unspecified_variable => unreachable,
                    .variable => {
                        try p.err(first_tok, .vla_field, .{});
                        qt = .invalid;
                    },
                    .fixed => {},
                    .incomplete => {
                        if (p.record.kind == .keyword_union) {
                            if (p.comp.langopts.emulate == .msvc) {
                                try p.err(first_tok, .flexible_in_union_msvc, .{});
                            } else {
                                try p.err(first_tok, .flexible_in_union, .{});
                                qt = .invalid;
                            }
                        }
                        if (p.record.flexible_field) |some| {
                            if (p.record.kind == .keyword_struct) {
                                try p.err(some, .flexible_non_final, .{});
                            }
                        }
                        p.record.flexible_field = first_tok;
                    },
                },
                else => if (field_type.qt.hasIncompleteSize(p.comp)) {
                    try p.err(first_tok, .field_incomplete_ty, .{qt});
                } else if (p.record.flexible_field) |some| {
                    std.debug.assert(some != first_tok);
                    if (p.record.kind == .keyword_struct) try p.err(some, .flexible_non_final, .{});
                },
            }
        }

        if (p.eatToken(.comma) == null) break;
        error_on_unnamed = true;
    }

    if (p.eatToken(.semicolon) == null) {
        const tok_id = p.tok_ids[p.tok_i];
        if (tok_id == .r_brace) {
            try p.err(p.tok_i, .missing_semicolon, .{});
        } else {
            return p.errExpectedToken(.semicolon, tok_id);
        }
    }

    return true;
}

/// specQual : typeSpec+
fn specQual(p: *Parser) Error!?QualType {
    var builder: TypeStore.Builder = .{ .parser = p };
    if (try p.typeSpec(&builder)) {
        return try builder.finish();
    }
    return null;
}

/// enumSpec
///  : keyword_enum IDENTIFIER? (: typeName)? { enumerator (',' enumerator)? ',') }
///  | keyword_enum IDENTIFIER (: typeName)?
fn enumSpec(p: *Parser) Error!QualType {
    const gpa = p.comp.gpa;
    const enum_tok = p.tok_i;
    p.tok_i += 1;
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier();

    const maybe_ident = try p.eatIdentifier();
    const fixed_qt: ?QualType = if (p.eatToken(.colon)) |colon| fixed: {
        const ty_start = p.tok_i;
        const fixed = (try p.specQual()) orelse {
            if (p.record.kind != .invalid) {
                // This is a bit field.
                p.tok_i -= 1;
                break :fixed null;
            }
            try p.err(p.tok_i, .expected_type, .{});
            try p.err(colon, .enum_fixed, .{});
            break :fixed .int;
        };

        var final = fixed;
        while (true) {
            switch (final.base(p.comp).type) {
                .int => {
                    try p.err(colon, .enum_fixed, .{});
                    if (final.isQualified()) try p.err(ty_start, .enum_qualifiers_ignored, .{});
                    break :fixed final.unqualified();
                },
                .atomic => |atomic| {
                    try p.err(ty_start, .enum_atomic_ignored, .{});
                    final = atomic.withQualifiers(final);
                },
                else => {
                    try p.err(ty_start, .enum_invalid_underlying_type, .{fixed});
                    break :fixed .int;
                },
            }
        }
    } else null;

    const reserved_index = try p.tree.nodes.addOne(gpa);

    const l_brace = p.eatToken(.l_brace) orelse {
        const ident = maybe_ident orelse {
            try p.err(p.tok_i, .ident_or_l_brace, .{});
            return error.ParsingFailed;
        };
        // check if this is a reference to a previous type
        const interned_name = try p.comp.internString(p.tokSlice(ident));
        if (try p.syms.findTag(p, interned_name, p.tok_ids[enum_tok], ident, p.tok_ids[p.tok_i])) |prev| {
            // only check fixed underlying type in forward declarations and not in references.
            if (p.tok_ids[p.tok_i] == .semicolon)
                try p.checkEnumFixedTy(fixed_qt, ident, prev);
            return prev.qt;
        } else {
            if (fixed_qt == null) try p.err(ident, .enum_forward_declaration, .{});

            const enum_qt = try p.comp.type_store.put(gpa, .{ .@"enum" = .{
                .name = interned_name,
                .tag = fixed_qt,
                .fixed = fixed_qt != null,
                .incomplete = true,
                .decl_node = @enumFromInt(reserved_index),
                .fields = &.{},
            } });

            const attributed_qt = try Attribute.applyTypeAttributes(p, enum_qt, attr_buf_top, null);
            try p.syms.define(gpa, .{
                .kind = .@"enum",
                .name = interned_name,
                .tok = ident,
                .qt = attributed_qt,
                .val = .{},
            });

            try p.decl_buf.append(gpa, try p.addNode(.{ .enum_forward_decl = .{
                .name_or_kind_tok = ident,
                .container_qt = attributed_qt,
                .definition = null,
            } }));
            return attributed_qt;
        }
    };

    var done = false;
    errdefer if (!done) p.skipTo(.r_brace);

    // Get forward declared type or create a new one
    var defined = false;
    var enum_ty: Type.Enum, const qt: QualType = blk: {
        const interned_name = if (maybe_ident) |ident| interned: {
            const ident_str = p.tokSlice(ident);
            const interned_name = try p.comp.internString(ident_str);
            if (try p.syms.defineTag(p, interned_name, p.tok_ids[enum_tok], ident)) |prev| {
                const enum_ty = prev.qt.get(p.comp, .@"enum").?;
                if (!enum_ty.incomplete) {
                    // if the record isn't incomplete, this is a redefinition
                    try p.err(ident, .redefinition, .{ident_str});
                    try p.err(prev.tok, .previous_definition, .{});
                } else {
                    try p.checkEnumFixedTy(fixed_qt, ident, prev);
                    defined = true;
                    break :blk .{ enum_ty, prev.qt };
                }
            }
            break :interned interned_name;
        } else try p.getAnonymousName(enum_tok);

        // Initially create ty as a regular non-attributed type, since attributes for a record
        // can be specified after the closing rbrace, which we haven't encountered yet.
        const enum_ty: Type.Enum = .{
            .name = interned_name,
            .decl_node = @enumFromInt(reserved_index),
            .tag = fixed_qt,
            .incomplete = true,
            .fixed = fixed_qt != null,
            .fields = &.{},
        };
        const enum_qt = try p.comp.type_store.put(gpa, .{ .@"enum" = enum_ty });
        break :blk .{ enum_ty, enum_qt };
    };

    // reserve space for this enum
    try p.decl_buf.append(gpa, @enumFromInt(reserved_index));
    const decl_buf_top = p.decl_buf.items.len;
    const list_buf_top = p.list_buf.items.len;
    const enum_buf_top = p.enum_buf.items.len;
    errdefer p.decl_buf.items.len = decl_buf_top - 1;
    defer {
        p.decl_buf.items.len = decl_buf_top;
        p.list_buf.items.len = list_buf_top;
        p.enum_buf.items.len = enum_buf_top;
    }

    var e = Enumerator.init(fixed_qt);
    while (try p.enumerator(&e)) |field_and_node| {
        try p.enum_buf.append(gpa, field_and_node.field);
        try p.list_buf.append(gpa, field_and_node.node);
        if (p.eatToken(.comma) == null) break;
    }

    if (p.enum_buf.items.len == enum_buf_top) try p.err(p.tok_i, .empty_enum, .{});
    try p.expectClosing(l_brace, .r_brace);
    done = true;
    try p.attributeSpecifier();

    const attributed_qt = try Attribute.applyTypeAttributes(p, qt, attr_buf_top, null);
    if (!enum_ty.fixed) {
        enum_ty.tag = try e.getTypeSpecifier(p, attributed_qt.enumIsPacked(p.comp), maybe_ident orelse enum_tok);
    }

    const enum_fields = p.enum_buf.items[enum_buf_top..];
    const field_nodes = p.list_buf.items[list_buf_top..];

    if (fixed_qt == null) {
        // Coerce all fields to final type.
        const tag_qt = enum_ty.tag.?;
        const keep_int = e.num_positive_bits < Type.Int.int.bits(p.comp);
        for (enum_fields, field_nodes) |*field, field_node| {
            const sym = p.syms.get(field.name, .vars) orelse continue;
            if (sym.kind != .enumeration) continue; // already an error

            var res: Result = .{ .node = undefined, .qt = field.qt, .val = sym.val };
            const dest_qt: QualType = if (keep_int and try res.intFitsInType(p, .int))
                .int
            else
                tag_qt;
            if (field.qt.eql(dest_qt, p.comp)) continue;

            const symbol = p.syms.getPtr(field.name, .vars);
            _ = try symbol.val.intCast(dest_qt, p.comp);
            try p.tree.value_map.put(gpa, field_node, symbol.val);

            symbol.qt = dest_qt;
            field.qt = dest_qt;
            res.qt = dest_qt;

            // Create a new enum_field node with the correct type.
            var new_field_node = field_node.get(&p.tree);
            new_field_node.enum_field.qt = dest_qt;

            if (new_field_node.enum_field.init) |some| {
                res.node = some;
                try res.implicitCast(p, .int_cast, some.tok(&p.tree));
                new_field_node.enum_field.init = res.node;
            }

            try p.tree.setNode(new_field_node, @intFromEnum(field_node));
        }
    }

    { // Override previous incomplete type
        enum_ty.fields = enum_fields;
        enum_ty.incomplete = false;
        enum_ty.decl_node = @enumFromInt(reserved_index);
        const base_type = attributed_qt.base(p.comp);
        std.debug.assert(base_type.type.@"enum".name == enum_ty.name);
        try p.comp.type_store.set(gpa, .{ .@"enum" = enum_ty }, @intFromEnum(base_type.qt._index));
    }

    // declare a symbol for the type
    if (maybe_ident != null and !defined) {
        try p.syms.define(gpa, .{
            .kind = .@"enum",
            .name = enum_ty.name,
            .qt = attributed_qt,
            .tok = maybe_ident.?,
            .val = .{},
        });
    }

    // finish by creating a node
    try p.tree.setNode(.{ .enum_decl = .{
        .name_or_kind_tok = maybe_ident orelse enum_tok,
        .container_qt = attributed_qt,
        .fields = field_nodes,
    } }, reserved_index);

    if (p.func.qt == null) {
        _ = p.tentative_defs.remove(enum_ty.name);
    }
    return attributed_qt;
}

fn checkEnumFixedTy(p: *Parser, fixed_qt: ?QualType, ident_tok: TokenIndex, prev: Symbol) !void {
    const enum_ty = prev.qt.get(p.comp, .@"enum").?;
    if (fixed_qt) |some| {
        if (!enum_ty.fixed) {
            try p.err(ident_tok, .enum_prev_nonfixed, .{});
            try p.err(prev.tok, .previous_definition, .{});
            return error.ParsingFailed;
        }

        if (!enum_ty.tag.?.eql(some, p.comp)) {
            try p.err(ident_tok, .enum_different_explicit_ty, .{ some, enum_ty.tag.? });
            try p.err(prev.tok, .previous_definition, .{});
            return error.ParsingFailed;
        }
    } else if (enum_ty.fixed) {
        try p.err(ident_tok, .enum_prev_fixed, .{});
        try p.err(prev.tok, .previous_definition, .{});
        return error.ParsingFailed;
    }
}

const Enumerator = struct {
    val: Value = .{},
    qt: QualType,
    num_positive_bits: usize = 0,
    num_negative_bits: usize = 0,
    fixed: bool,

    fn init(fixed_ty: ?QualType) Enumerator {
        return .{
            .qt = fixed_ty orelse .int,
            .fixed = fixed_ty != null,
        };
    }

    /// Increment enumerator value adjusting type if needed.
    fn incr(e: *Enumerator, p: *Parser, tok: TokenIndex) !void {
        const old_val = e.val;
        if (old_val.opt_ref == .none) {
            // First enumerator, set to 0 fits in all types.
            e.val = .zero;
            return;
        }
        if (try e.val.add(e.val, .one, e.qt, p.comp)) {
            if (e.fixed) {
                try p.err(tok, .enum_not_representable_fixed, .{e.qt});
                return;
            }
            if (p.comp.nextLargestIntSameSign(e.qt)) |larger| {
                try p.err(tok, .enumerator_overflow, .{});
                e.qt = larger;
            } else {
                const signed = e.qt.signedness(p.comp) == .signed;
                const bit_size = e.qt.bitSizeof(p.comp) - @intFromBool(signed);
                try p.err(tok, .enum_not_representable, .{switch (bit_size) {
                    63 => "9223372036854775808",
                    64 => "18446744073709551616",
                    127 => "170141183460469231731687303715884105728",
                    128 => "340282366920938463463374607431768211456",
                    else => unreachable,
                }});
                e.qt = .ulong_long;
            }
            _ = try e.val.add(old_val, .one, e.qt, p.comp);
        }
    }

    /// Set enumerator value to specified value.
    fn set(e: *Enumerator, p: *Parser, res: *Result, tok: TokenIndex) !void {
        if (res.qt.isInvalid()) return;
        if (e.fixed and !res.qt.eql(e.qt, p.comp)) {
            if (!try res.intFitsInType(p, e.qt)) {
                try p.err(tok, .enum_not_representable_fixed, .{e.qt});
                return error.ParsingFailed;
            }
            res.qt = e.qt;
            try res.implicitCast(p, .int_cast, tok);
            e.val = res.val;
        } else {
            try res.castToInt(p, res.qt.promoteInt(p.comp), tok);
            e.qt = res.qt;
            e.val = res.val;
        }
    }

    fn getTypeSpecifier(e: *const Enumerator, p: *Parser, is_packed: bool, tok: TokenIndex) !QualType {
        if (p.comp.fixedEnumTagType()) |tag_specifier| return tag_specifier;

        const char_width = Type.Int.schar.bits(p.comp);
        const short_width = Type.Int.short.bits(p.comp);
        const int_width = Type.Int.int.bits(p.comp);
        if (e.num_negative_bits > 0) {
            if (is_packed and e.num_negative_bits <= char_width and e.num_positive_bits < char_width) {
                return .schar;
            } else if (is_packed and e.num_negative_bits <= short_width and e.num_positive_bits < short_width) {
                return .short;
            } else if (e.num_negative_bits <= int_width and e.num_positive_bits < int_width) {
                return .int;
            }
            const long_width = Type.Int.long.bits(p.comp);
            if (e.num_negative_bits <= long_width and e.num_positive_bits < long_width) {
                return .long;
            }
            const long_long_width = Type.Int.long_long.bits(p.comp);
            if (e.num_negative_bits > long_long_width or e.num_positive_bits >= long_long_width) {
                try p.err(tok, .enum_too_large, .{});
            }
            return .long_long;
        }
        if (is_packed and e.num_positive_bits <= char_width) {
            return .uchar;
        } else if (is_packed and e.num_positive_bits <= short_width) {
            return .ushort;
        } else if (e.num_positive_bits <= int_width) {
            return .uint;
        } else if (e.num_positive_bits <= Type.Int.long.bits(p.comp)) {
            return .ulong;
        }
        return .ulong_long;
    }
};

const EnumFieldAndNode = struct { field: Type.Enum.Field, node: Node.Index };

/// enumerator : IDENTIFIER ('=' integerConstExpr)
fn enumerator(p: *Parser, e: *Enumerator) Error!?EnumFieldAndNode {
    _ = try p.pragma();
    const name_tok = (try p.eatIdentifier()) orelse {
        if (p.tok_ids[p.tok_i] == .r_brace) return null;
        try p.err(p.tok_i, .expected_identifier, .{});
        p.skipTo(.r_brace);
        return error.ParsingFailed;
    };
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier();

    const prev_total = p.diagnostics.total;
    const field_init = if (p.eatToken(.equal)) |_| blk: {
        var specified = try p.integerConstExpr(.gnu_folding_extension);
        if (specified.val.opt_ref == .none) {
            try p.err(name_tok + 2, .enum_val_unavailable, .{});
            try e.incr(p, name_tok);
            break :blk null;
        } else {
            try e.set(p, &specified, name_tok);
            break :blk specified.node;
        }
    } else blk: {
        try e.incr(p, name_tok);
        break :blk null;
    };

    if (e.qt.signedness(p.comp) == .unsigned or e.val.compare(.gte, .zero, p.comp)) {
        e.num_positive_bits = @max(e.num_positive_bits, e.val.minUnsignedBits(p.comp));
    } else {
        e.num_negative_bits = @max(e.num_negative_bits, e.val.minSignedBits(p.comp));
    }

    if (prev_total == p.diagnostics.total) {
        // only do these warnings if we didn't already warn about overflow or non-representable values
        if (e.val.compare(.lt, .zero, p.comp)) {
            const min_val = try Value.minInt(.int, p.comp);
            if (e.val.compare(.lt, min_val, p.comp)) {
                try p.err(name_tok, .enumerator_too_small, .{e});
            }
        } else {
            const max_val = try Value.maxInt(.int, p.comp);
            if (e.val.compare(.gt, max_val, p.comp)) {
                try p.err(name_tok, .enumerator_too_large, .{e});
            }
        }
    }

    const attributed_qt = try Attribute.applyEnumeratorAttributes(p, e.qt, attr_buf_top);
    const node = try p.addNode(.{
        .enum_field = .{
            .name_tok = name_tok,
            .qt = attributed_qt,
            .init = field_init,
        },
    });
    try p.tree.value_map.put(p.comp.gpa, node, e.val);

    const interned_name = try p.comp.internString(p.tokSlice(name_tok));
    try p.syms.defineEnumeration(p, interned_name, attributed_qt, name_tok, e.val, node);

    return .{ .field = .{
        .name = interned_name,
        .qt = attributed_qt,
        .name_tok = name_tok,
    }, .node = node };
}

/// typeQual : keyword_const | keyword_restrict | keyword_volatile | keyword_atomic
fn typeQual(p: *Parser, b: *TypeStore.Builder, allow_attr: bool) Error!bool {
    var any = false;
    while (true) {
        if (allow_attr and try p.msTypeAttribute()) continue;
        if (allow_attr) try p.attributeSpecifier();
        switch (p.tok_ids[p.tok_i]) {
            .keyword_restrict, .keyword_restrict1, .keyword_restrict2 => {
                if (b.restrict != null)
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"restrict"})
                else
                    b.restrict = p.tok_i;
            },
            .keyword_const, .keyword_const1, .keyword_const2 => {
                if (b.@"const" != null)
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"const"})
                else
                    b.@"const" = p.tok_i;
            },
            .keyword_volatile, .keyword_volatile1, .keyword_volatile2 => {
                if (b.@"volatile" != null)
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"volatile"})
                else
                    b.@"volatile" = p.tok_i;
            },
            .keyword_atomic => {
                // _Atomic(typeName) instead of just _Atomic
                if (p.tok_ids[p.tok_i + 1] == .l_paren) break;
                if (b.atomic != null)
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"atomic"})
                else
                    b.atomic = p.tok_i;
            },
            .keyword_unaligned, .keyword_unaligned2 => {
                if (b.unaligned != null)
                    try p.err(p.tok_i, .duplicate_decl_spec, .{"__unaligned"})
                else
                    b.unaligned = p.tok_i;
            },
            .keyword_nonnull, .keyword_nullable, .keyword_nullable_result, .keyword_null_unspecified => |tok_id| {
                const sym_str = p.tok_ids[p.tok_i].symbol();
                try p.err(p.tok_i, .nullability_extension, .{sym_str});
                const new: @FieldType(TypeStore.Builder, "nullability") = switch (tok_id) {
                    .keyword_nonnull => .{ .nonnull = p.tok_i },
                    .keyword_nullable => .{ .nullable = p.tok_i },
                    .keyword_nullable_result => .{ .nullable_result = p.tok_i },
                    .keyword_null_unspecified => .{ .null_unspecified = p.tok_i },
                    else => unreachable,
                };
                if (std.meta.activeTag(b.nullability) == new) {
                    try p.err(p.tok_i, .duplicate_nullability, .{sym_str});
                } else switch (b.nullability) {
                    .none => {
                        b.nullability = new;
                        try p.attr_buf.append(p.comp.gpa, .{
                            .attr = .{ .tag = .nullability, .args = .{
                                .nullability = .{ .kind = switch (tok_id) {
                                    .keyword_nonnull => .nonnull,
                                    .keyword_nullable => .nullable,
                                    .keyword_nullable_result => .nullable_result,
                                    .keyword_null_unspecified => .unspecified,
                                    else => unreachable,
                                } },
                            }, .syntax = .keyword },
                            .tok = p.tok_i,
                        });
                    },
                    .nonnull,
                    .nullable,
                    .nullable_result,
                    .null_unspecified,
                    => |prev| try p.err(p.tok_i, .conflicting_nullability, .{ p.tok_ids[p.tok_i], p.tok_ids[prev] }),
                }
            },
            else => break,
        }
        p.tok_i += 1;
        any = true;
    }
    return any;
}

fn msTypeAttribute(p: *Parser) !bool {
    var any = false;
    while (true) {
        switch (p.tok_ids[p.tok_i]) {
            .keyword_stdcall,
            .keyword_stdcall2,
            .keyword_thiscall,
            .keyword_thiscall2,
            .keyword_vectorcall,
            .keyword_vectorcall2,
            .keyword_fastcall,
            .keyword_fastcall2,
            .keyword_regcall,
            .keyword_cdecl,
            .keyword_cdecl2,
            => {
                try p.attr_buf.append(p.comp.gpa, .{
                    .attr = .{ .tag = .calling_convention, .args = .{
                        .calling_convention = .{ .cc = switch (p.tok_ids[p.tok_i]) {
                            .keyword_stdcall,
                            .keyword_stdcall2,
                            => .stdcall,
                            .keyword_thiscall,
                            .keyword_thiscall2,
                            => .thiscall,
                            .keyword_vectorcall,
                            .keyword_vectorcall2,
                            => .vectorcall,
                            .keyword_fastcall,
                            .keyword_fastcall2,
                            => .fastcall,
                            .keyword_regcall,
                            => .regcall,
                            .keyword_cdecl,
                            .keyword_cdecl2,
                            => .c,
                            else => unreachable,
                        } },
                    }, .syntax = .keyword },
                    .tok = p.tok_i,
                });
                any = true;
                p.tok_i += 1;
            },
            else => break,
        }
    }
    return any;
}

const Declarator = struct {
    name: TokenIndex,
    qt: QualType,
    old_style_func: ?TokenIndex = null,

    /// What kind of a type did this declarator declare?
    /// Used redundantly with `qt` in case it was set to `.invalid` by `validate`.
    declarator_type: enum { other, func, array, pointer } = .other,

    const Kind = enum { normal, abstract, param, record };

    fn validate(d: *Declarator, p: *Parser, source_tok: TokenIndex) Parser.Error!void {
        switch (try validateExtra(p, d.qt, source_tok)) {
            .normal => return,
            .nested_invalid => if (d.declarator_type == .func) return,
            .nested_auto => {
                if (d.declarator_type == .func) return;
                if (d.qt.isAutoType() or d.qt.isC23Auto()) return;
            },
            .declarator_combine => return,
        }
        d.qt = .invalid;
    }

    const ValidationResult = enum {
        nested_invalid,
        nested_auto,
        declarator_combine,
        normal,
    };

    fn validateExtra(p: *Parser, cur: QualType, source_tok: TokenIndex) Parser.Error!ValidationResult {
        if (cur.isInvalid()) return .nested_invalid;
        if (cur.isAutoType()) return .nested_auto;
        if (cur.isC23Auto()) return .nested_auto;
        if (cur._index == .declarator_combine) return .declarator_combine;

        switch (cur.type(p.comp)) {
            .pointer => |pointer_ty| {
                return validateExtra(p, pointer_ty.child, source_tok);
            },
            .atomic => |atomic_ty| {
                return validateExtra(p, atomic_ty, source_tok);
            },
            .array => |array_ty| {
                const elem_qt = array_ty.elem;
                const child_res = try validateExtra(p, elem_qt, source_tok);
                if (child_res != .normal) return child_res;

                if (elem_qt.hasIncompleteSize(p.comp)) {
                    try p.err(source_tok, .array_incomplete_elem, .{elem_qt});
                    return .nested_invalid;
                }
                switch (array_ty.len) {
                    .fixed, .static => |len| {
                        const elem_size = elem_qt.sizeofOrNull(p.comp) orelse 1;
                        const max_elems = p.comp.maxArrayBytes() / @max(1, elem_size);
                        if (len > max_elems) {
                            try p.err(source_tok, .array_too_large, .{});
                            return .nested_invalid;
                        }
                    },
                    else => {},
                }

                if (elem_qt.is(p.comp, .func)) {
                    try p.err(source_tok, .array_func_elem, .{});
                    return .nested_invalid;
                }
                if (elem_qt.get(p.comp, .array)) |elem_array_ty| {
                    if (elem_array_ty.len == .static) {
                        try p.err(source_tok, .static_non_outermost_array, .{});
                    }
                    if (elem_qt.isQualified()) {
                        try p.err(source_tok, .qualifier_non_outermost_array, .{});
                    }
                }
                return .normal;
            },
            .func => |func_ty| {
                const ret_qt = func_ty.return_type;
                const child_res = try validateExtra(p, ret_qt, source_tok);
                if (child_res != .normal) return child_res;

                if (ret_qt.is(p.comp, .array)) try p.err(source_tok, .func_cannot_return_array, .{});
                if (ret_qt.is(p.comp, .func)) try p.err(source_tok, .func_cannot_return_func, .{});
                if (ret_qt.@"const") {
                    try p.err(source_tok, .qual_on_ret_type, .{"const"});
                }
                if (ret_qt.@"volatile") {
                    try p.err(source_tok, .qual_on_ret_type, .{"volatile"});
                }
                if (ret_qt.get(p.comp, .float)) |float| {
                    if (float == .fp16 and !p.comp.hasHalfPrecisionFloatABI()) {
                        try p.err(source_tok, .suggest_pointer_for_invalid_fp16, .{"function return value"});
                    }
                }
                return .normal;
            },
            else => return .normal,
        }
    }
};

/// declarator : pointer? (IDENTIFIER | '(' declarator ')') directDeclarator*
/// abstractDeclarator
/// : pointer? ('(' abstractDeclarator ')')? directAbstractDeclarator*
/// pointer : '*' typeQual* pointer?
fn declarator(
    p: *Parser,
    base_qt: QualType,
    kind: Declarator.Kind,
) Error!?Declarator {
    var d = Declarator{ .name = 0, .qt = base_qt };

    // Parse potential pointer declarators first.
    while (p.eatToken(.asterisk)) |_| {
        d.declarator_type = .pointer;
        var builder: TypeStore.Builder = .{ .parser = p };
        _ = try p.typeQual(&builder, true);

        const pointer_qt = try p.comp.type_store.put(p.comp.gpa, .{ .pointer = .{
            .child = d.qt,
            .decayed = null,
        } });
        d.qt = try builder.finishQuals(pointer_qt);
    }

    const maybe_ident = p.tok_i;
    if (kind != .abstract and (try p.eatIdentifier()) != null) {
        d.name = maybe_ident;
        const combine_tok = p.tok_i;
        d.qt = try p.directDeclarator(&d, kind);
        try d.validate(p, combine_tok);
        return d;
    } else if (p.eatToken(.l_paren)) |l_paren| blk: {
        // C23 and declspec attributes are not allowed here
        try p.attributeSpecifierGnu();

        // Parse Microsoft keyword type attributes.
        _ = try p.msTypeAttribute();

        const special_marker: QualType = .{ ._index = .declarator_combine };
        var res = (try p.declarator(special_marker, kind)) orelse {
            p.tok_i = l_paren;
            break :blk;
        };
        try p.expectClosing(l_paren, .r_paren);
        const suffix_start = p.tok_i;
        const outer = try p.directDeclarator(&d, kind);

        // Correct the base type now that it is known.
        // If res.qt is the special marker there was no inner type.
        if (res.qt._index == .declarator_combine) {
            res.qt = outer;
            res.declarator_type = d.declarator_type;
        } else if (outer.isInvalid() or res.qt.isInvalid()) {
            res.qt = outer;
        } else {
            var cur = res.qt;
            while (true) {
                switch (cur.type(p.comp)) {
                    .pointer => |pointer_ty| if (pointer_ty.child._index != .declarator_combine) {
                        cur = pointer_ty.child;
                        continue;
                    },
                    .atomic => |atomic_ty| if (atomic_ty._index != .declarator_combine) {
                        cur = atomic_ty;
                        continue;
                    },
                    .array => |array_ty| if (array_ty.elem._index != .declarator_combine) {
                        cur = array_ty.elem;
                        continue;
                    },
                    .func => |func_ty| if (func_ty.return_type._index != .declarator_combine) {
                        cur = func_ty.return_type;
                        continue;
                    },
                    else => unreachable,
                }
                // Child type is always stored in repr.data[0]
                p.comp.type_store.types.items(.data)[@intFromEnum(cur._index)][0] = @bitCast(outer);
                break;
            }
        }

        try res.validate(p, suffix_start);
        return res;
    }

    const expected_ident = p.tok_i;

    d.qt = try p.directDeclarator(&d, kind);
    if (kind == .normal) {
        var cur = d.qt;
        while (true) {
            // QualType.base inlined here because of potential
            // .declarator_combine.
            if (cur._index == .declarator_combine) break;
            switch (cur.type(p.comp)) {
                .typeof => |typeof_ty| cur = typeof_ty.base,
                .typedef => |typedef_ty| cur = typedef_ty.base,
                .attributed => |attributed_ty| cur = attributed_ty.base,
                else => |ty| switch (ty) {
                    .@"enum", .@"struct", .@"union" => break,
                    else => {
                        try p.err(expected_ident, .expected_ident_or_l_paren, .{});
                        return error.ParsingFailed;
                    },
                },
            }
        }
    }
    try d.validate(p, expected_ident);
    if (d.qt == base_qt) return null;
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
fn directDeclarator(
    p: *Parser,
    base_declarator: *Declarator,
    kind: Declarator.Kind,
) Error!QualType {
    const gpa = p.comp.gpa;
    if (p.eatToken(.l_bracket)) |l_bracket| {
        // Check for C23 attribute
        if (p.tok_ids[p.tok_i] == .l_bracket) {
            switch (kind) {
                .normal, .record => if (p.comp.langopts.standard.atLeast(.c23)) {
                    p.tok_i -= 1;
                    return base_declarator.qt;
                },
                .param, .abstract => {},
            }
            try p.err(p.tok_i, .expected_expr, .{});
            return error.ParsingFailed;
        }

        var builder: TypeStore.Builder = .{ .parser = p };

        var got_quals = try p.typeQual(&builder, false);
        var static = p.eatToken(.keyword_static);
        if (static != null and !got_quals) got_quals = try p.typeQual(&builder, false);
        var star = p.eatToken(.asterisk);
        const size_tok = p.tok_i;

        const const_decl_folding = p.const_decl_folding;
        p.const_decl_folding = .gnu_vla_folding_extension;
        const opt_size = if (star) |_| null else try p.assignExpr();
        p.const_decl_folding = const_decl_folding;

        try p.expectClosing(l_bracket, .r_bracket);

        if (star != null and static != null) {
            try p.err(static.?, .invalid_static_star, .{});
            static = null;
        }
        if (kind != .param) {
            if (static != null)
                try p.err(l_bracket, .static_non_param, .{})
            else if (got_quals)
                try p.err(l_bracket, .array_qualifiers, .{});
            if (star) |some| try p.err(some, .star_non_param, .{});
            static = null;
            builder = .{ .parser = p };
            star = null;
        }
        if (static) |_| _ = try p.expectResult(opt_size);

        const outer = try p.directDeclarator(base_declarator, kind);

        // Set after call to `directDeclarator` since we will return an
        // array type from here.
        base_declarator.declarator_type = .array;

        if (opt_size != null and !opt_size.?.qt.isInvalid() and !opt_size.?.qt.isRealInt(p.comp)) {
            try p.err(size_tok, .array_size_non_int, .{opt_size.?.qt});
            return error.ParsingFailed;
        }

        if (opt_size) |size| {
            if (size.val.opt_ref == .none) {
                try p.err(size_tok, .vla, .{});
                if (p.func.qt == null and kind != .param and p.record.kind == .invalid) {
                    try p.err(base_declarator.name, .variable_len_array_file_scope, .{});
                }

                const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                    .elem = outer,
                    .len = .{ .variable = size.node },
                } });

                if (static) |some| try p.err(some, .useless_static, .{});
                return builder.finishQuals(array_qt);
            } else {
                if (size.val.isZero(p.comp)) {
                    try p.err(l_bracket, .zero_length_array, .{});
                } else if (size.val.compare(.lt, .zero, p.comp)) {
                    try p.err(l_bracket, .negative_array_size, .{});
                    return error.ParsingFailed;
                }

                const len = size.val.toInt(u64, p.comp) orelse std.math.maxInt(u64);
                const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                    .elem = outer,
                    .len = if (static != null)
                        .{ .static = len }
                    else
                        .{ .fixed = len },
                } });
                return builder.finishQuals(array_qt);
            }
        } else if (star) |_| {
            const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                .elem = outer,
                .len = .unspecified_variable,
            } });
            return builder.finishQuals(array_qt);
        } else {
            const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                .elem = outer,
                .len = .incomplete,
            } });
            return builder.finishQuals(array_qt);
        }
    } else if (p.eatToken(.l_paren)) |l_paren| {
        var func_ty: Type.Func = .{
            .kind = undefined,
            .return_type = undefined,
            .params = &.{},
        };

        if (p.eatToken(.ellipsis)) |_| {
            try p.err(p.tok_i, .param_before_var_args, .{});
            try p.expectClosing(l_paren, .r_paren);
            func_ty.kind = .variadic;

            func_ty.return_type = try p.directDeclarator(base_declarator, kind);

            // Set after call to `directDeclarator` since we will return
            // a function type from here.
            base_declarator.declarator_type = .func;
            return p.comp.type_store.put(gpa, .{ .func = func_ty });
        }

        // Set here so the call to directDeclarator for the return type
        // doesn't clobber this function type's parameters.
        const param_buf_top = p.param_buf.items.len;
        defer p.param_buf.items.len = param_buf_top;

        if (try p.paramDecls()) |params| {
            func_ty.kind = .normal;
            func_ty.params = params;
            if (p.eatToken(.ellipsis)) |_| func_ty.kind = .variadic;
        } else if (p.tok_ids[p.tok_i] == .r_paren) {
            func_ty.kind = if (p.comp.langopts.standard.atLeast(.c23))
                .normal
            else
                .old_style;
        } else if (p.tok_ids[p.tok_i] == .identifier or p.tok_ids[p.tok_i] == .extended_identifier) {
            base_declarator.old_style_func = p.tok_i;
            try p.syms.pushScope(p);
            defer p.syms.popScope();

            func_ty.kind = .old_style;
            while (true) {
                const name_tok = try p.expectIdentifier();
                const interned_name = try p.comp.internString(p.tokSlice(name_tok));
                try p.syms.defineParam(p, interned_name, undefined, name_tok, null);
                try p.param_buf.append(gpa, .{
                    .name = interned_name,
                    .name_tok = name_tok,
                    .qt = .int,
                    .node = .null,
                });
                if (p.eatToken(.comma) == null) break;
            }
            func_ty.params = p.param_buf.items[param_buf_top..];
        } else {
            try p.err(p.tok_i, .expected_param_decl, .{});
        }

        try p.expectClosing(l_paren, .r_paren);
        func_ty.return_type = try p.directDeclarator(base_declarator, kind);

        // Set after call to `directDeclarator` since we will return
        // a function type from here.
        base_declarator.declarator_type = .func;

        return p.comp.type_store.put(gpa, .{ .func = func_ty });
    } else return base_declarator.qt;
}

/// paramDecls : paramDecl (',' paramDecl)* (',' '...')
/// paramDecl : declSpec (declarator | abstractDeclarator)
fn paramDecls(p: *Parser) Error!?[]Type.Func.Param {
    // TODO warn about visibility of types declared here
    try p.syms.pushScope(p);
    defer p.syms.popScope();

    // Clearing the param buf is handled in directDeclarator.
    const param_buf_top = p.param_buf.items.len;
    const gpa = p.comp.gpa;

    while (true) {
        const attr_buf_top = p.attr_buf.len;
        defer p.attr_buf.len = attr_buf_top;
        const param_decl_spec = if (try p.declSpec()) |some|
            some
        else if (p.comp.langopts.standard.atLeast(.c23) and
            (p.tok_ids[p.tok_i] == .identifier or p.tok_ids[p.tok_i] == .extended_identifier))
        {
            // handle deprecated K&R style parameters
            const identifier = try p.expectIdentifier();
            try p.err(identifier, .unknown_type_name, .{p.tokSlice(identifier)});

            try p.param_buf.append(gpa, .{
                .name = try p.comp.internString(p.tokSlice(identifier)),
                .name_tok = identifier,
                .qt = .int,
                .node = .null,
            });

            if (p.eatToken(.comma) == null) break;
            if (p.tok_ids[p.tok_i] == .ellipsis) break;
            continue;
        } else if (p.param_buf.items.len == param_buf_top) {
            return null;
        } else blk: {
            try p.err(p.tok_i, .missing_type_specifier, .{});
            break :blk DeclSpec{ .qt = .int };
        };

        var name_tok: TokenIndex = 0;
        var interned_name: StringId = .empty;
        const first_tok = p.tok_i;
        var param_qt = param_decl_spec.qt;
        if (param_decl_spec.auto_type) |tok_i| {
            try p.err(tok_i, .auto_type_not_allowed, .{"function prototype"});
            param_qt = .invalid;
        }
        if (param_decl_spec.c23_auto) |tok_i| {
            try p.err(tok_i, .c23_auto_not_allowed, .{"function prototype"});
            param_qt = .invalid;
        }

        if (try p.declarator(param_qt, .param)) |some| {
            if (some.old_style_func) |tok_i| try p.err(tok_i, .invalid_old_style_params, .{});
            try p.attributeSpecifier();
            name_tok = some.name;
            param_qt = some.qt;
        }

        if (param_qt.is(p.comp, .void)) {
            // validate void parameters
            if (p.param_buf.items.len == param_buf_top) {
                if (p.tok_ids[p.tok_i] != .r_paren) {
                    try p.err(p.tok_i, .void_only_param, .{});
                    if (param_qt.isQualified()) try p.err(p.tok_i, .void_param_qualified, .{});
                    return error.ParsingFailed;
                }
                return &.{};
            }
            try p.err(p.tok_i, .void_must_be_first_param, .{});
            return error.ParsingFailed;
        } else {
            // Decay params declared as functions or arrays to pointer.
            param_qt = try param_qt.decay(p.comp);
        }
        try param_decl_spec.validateParam(p);
        param_qt = try Attribute.applyParameterAttributes(p, param_qt, attr_buf_top, .alignas_on_param);

        if (param_qt.get(p.comp, .float)) |float| {
            if (float == .fp16 and !p.comp.hasHalfPrecisionFloatABI()) {
                try p.err(first_tok, .suggest_pointer_for_invalid_fp16, .{"parameters"});
            }
        }

        var param_node: Node.OptIndex = .null;
        if (name_tok != 0) {
            const node = try p.addNode(.{
                .param = .{
                    .name_tok = name_tok,
                    .qt = param_qt,
                    .storage_class = switch (param_decl_spec.storage_class) {
                        .none => .auto,
                        .register => .register,
                        else => .auto, // Error reported in `validateParam`
                    },
                },
            });
            param_node = .pack(node);
            interned_name = try p.comp.internString(p.tokSlice(name_tok));
            try p.syms.defineParam(p, interned_name, param_qt, name_tok, node);
        }

        try p.param_buf.append(gpa, .{
            .name = interned_name,
            .name_tok = if (name_tok == 0) first_tok else name_tok,
            .qt = param_qt,
            .node = param_node,
        });

        if (p.eatToken(.comma) == null) break;
        if (p.tok_ids[p.tok_i] == .ellipsis) break;
    }
    return p.param_buf.items[param_buf_top..];
}

/// typeName : specQual abstractDeclarator
fn typeName(p: *Parser) Error!?QualType {
    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    const ty = (try p.specQual()) orelse return null;
    if (try p.declarator(ty, .abstract)) |some| {
        if (some.old_style_func) |tok_i| try p.err(tok_i, .invalid_old_style_params, .{});
        return try Attribute.applyTypeAttributes(p, some.qt, attr_buf_top, .align_ignored);
    }
    return try Attribute.applyTypeAttributes(p, ty, attr_buf_top, .align_ignored);
}

/// initializer
///  : assignExpr
///  | '{' initializerItems '}'
fn initializer(p: *Parser, init_qt: QualType) Error!Result {
    const l_brace = p.eatToken(.l_brace) orelse {
        // fast path for non-braced initializers
        const tok = p.tok_i;
        var res = try p.expect(assignExpr);
        if (try p.coerceArrayInit(res, tok, init_qt)) return res;
        try p.coerceInit(&res, tok, init_qt);
        return res;
    };

    // We want to parse the initializer even if the target is
    // invalidly inferred.
    var final_init_qt = init_qt;
    if (init_qt.isAutoType()) {
        try p.err(l_brace, .auto_type_with_init_list, .{});
        final_init_qt = .invalid;
    } else if (init_qt.isC23Auto()) {
        try p.err(l_brace, .c23_auto_with_init_list, .{});
        final_init_qt = .invalid;
    }

    var il: InitList = .{};
    defer il.deinit(p.comp.gpa);

    try p.initializerItem(&il, final_init_qt, l_brace);

    const list_node = try p.convertInitList(il, final_init_qt);
    return .{
        .qt = list_node.qt(&p.tree).withQualifiers(final_init_qt),
        .node = list_node,
        .val = p.tree.value_map.get(list_node) orelse .{},
    };
}

const IndexList = std.ArrayList(u64);

/// initializerItems : designation? initializer (',' designation? initializer)* ','?
fn initializerItem(p: *Parser, il: *InitList, init_qt: QualType, l_brace: TokenIndex) Error!void {
    const gpa = p.comp.gpa;
    const is_scalar = !init_qt.isInvalid() and init_qt.scalarKind(p.comp) != .none;

    if (p.eatToken(.r_brace)) |_| {
        try p.err(l_brace, .empty_initializer, .{});
        if (il.tok != 0 and !init_qt.isInvalid()) {
            try p.err(l_brace, .initializer_overrides, .{});
            try p.err(il.tok, .previous_initializer, .{});
        }
        il.node = .null;
        il.tok = l_brace;
        return;
    }

    var index_list: IndexList = .empty;
    defer index_list.deinit(gpa);

    var seen_any = false;
    var warned_excess = init_qt.isInvalid();
    while (true) : (seen_any = true) {
        errdefer p.skipTo(.r_brace);

        const designated = try p.designation(il, init_qt, &index_list);
        if (!designated and init_qt.hasAttribute(p.comp, .designated_init)) {
            try p.err(p.tok_i, .designated_init_needed, .{});
        }

        const first_tok = p.tok_i;
        if (p.eatToken(.l_brace)) |inner_l_brace| {
            if (try p.findBracedInitializer(il, init_qt, first_tok, &index_list)) |item| {
                if (item.il.tok != 0 and !init_qt.isInvalid()) {
                    try p.err(first_tok, .initializer_overrides, .{});
                    try p.err(item.il.tok, .previous_initializer, .{});
                    item.il.deinit(gpa);
                    item.il.* = .{};
                }
                try p.initializerItem(item.il, item.qt, inner_l_brace);
            } else {
                // discard further values
                var tmp_il: InitList = .{};
                defer tmp_il.deinit(gpa);
                try p.initializerItem(&tmp_il, .invalid, inner_l_brace);
                if (!warned_excess) try p.err(first_tok, switch (init_qt.base(p.comp).type) {
                    .array => if (il.node != .null and p.isStringInit(init_qt, il.node.unpack().?))
                        .excess_str_init
                    else
                        .excess_array_init,
                    .@"struct" => .excess_struct_init,
                    .@"union" => .excess_union_init,
                    .vector => .excess_vector_init,
                    else => .excess_scalar_init,
                }, .{});

                warned_excess = true;
            }
        } else if (try p.assignExpr()) |res| {
            if (is_scalar and il.node != .null) {
                if (!warned_excess) try p.err(first_tok, .excess_scalar_init, .{});
                warned_excess = true;
            } else {
                _ = try p.findScalarInitializer(il, init_qt, res, first_tok, &warned_excess, &index_list, 0);
            }
        } else if (designated or (seen_any and p.tok_ids[p.tok_i] != .r_brace)) {
            try p.err(p.tok_i, .expected_expr, .{});
        } else break;

        if (p.eatToken(.comma) == null) break;
    }
    try p.expectClosing(l_brace, .r_brace);

    if (il.tok == 0) il.tok = l_brace;
}

fn setInitializer(p: *Parser, il: *InitList, init_qt: QualType, tok: TokenIndex, res: Result) !void {
    var copy = res;

    const arr = try p.coerceArrayInit(copy, tok, init_qt);
    if (!arr) try p.coerceInit(&copy, tok, init_qt);
    if (il.tok != 0 and !init_qt.isInvalid()) {
        try p.err(tok, .initializer_overrides, .{});
        try p.err(il.tok, .previous_initializer, .{});
    }
    il.node = .pack(copy.node);
    il.tok = tok;
}

/// designation : designator+ '='?
/// designator
///  : '[' integerConstExpr ']'
///  | '.' identifier
fn designation(p: *Parser, il: *InitList, init_qt: QualType, index_list: *IndexList) !bool {
    switch (p.tok_ids[p.tok_i]) {
        .l_bracket, .period => index_list.items.len = 0,
        else => return false,
    }
    const gpa = p.comp.gpa;

    var cur_qt = init_qt;
    var cur_il = il;
    while (true) {
        if (p.eatToken(.l_bracket)) |l_bracket| {
            const array_ty = cur_qt.get(p.comp, .array) orelse {
                try p.err(l_bracket, .invalid_array_designator, .{cur_qt});
                return error.ParsingFailed;
            };
            const expr_tok = p.tok_i;
            const index_res = try p.integerConstExpr(.gnu_folding_extension);
            try p.expectClosing(l_bracket, .r_bracket);
            if (cur_qt.isInvalid()) continue;

            if (index_res.val.opt_ref == .none) {
                try p.err(expr_tok, .expected_integer_constant_expr, .{});
                return error.ParsingFailed;
            } else if (index_res.val.compare(.lt, .zero, p.comp)) {
                try p.err(l_bracket + 1, .negative_array_designator, .{index_res});
                return error.ParsingFailed;
            }

            const max_len = switch (array_ty.len) {
                .fixed, .static => |len| len,
                else => std.math.maxInt(u64),
            };
            const index_int = index_res.val.toInt(u64, p.comp) orelse std.math.maxInt(u64);
            if (index_int >= max_len) {
                try p.err(l_bracket + 1, .oob_array_designator, .{index_res});
                return error.ParsingFailed;
            }

            try index_list.append(gpa, index_int);
            cur_il = try cur_il.find(gpa, index_int);
            cur_qt = array_ty.elem;
        } else if (p.eatToken(.period)) |period| {
            const field_tok = try p.expectIdentifier();
            if (cur_qt.isInvalid()) continue;

            const field_str = p.tokSlice(field_tok);
            const target_name = try p.comp.internString(field_str);
            var record_ty = cur_qt.getRecord(p.comp) orelse {
                try p.err(period, .invalid_field_designator, .{cur_qt});
                return error.ParsingFailed;
            };

            var field_index: u32 = 0;
            while (field_index < record_ty.fields.len) {
                const field = record_ty.fields[field_index];
                if (field.name_tok == 0) if (field.qt.getRecord(p.comp)) |field_record_ty| {
                    // Recurse into anonymous field if it has a field by the name.
                    if (!field_record_ty.hasField(p.comp, target_name)) continue;
                    try index_list.append(gpa, field_index);
                    cur_il = try il.find(gpa, field_index);
                    record_ty = field_record_ty;
                    field_index = 0;
                    continue;
                };
                if (field.name == target_name) {
                    cur_qt = field.qt;
                    try index_list.append(gpa, field_index);
                    cur_il = try cur_il.find(gpa, field_index);
                    break;
                }
                field_index += 1;
            } else {
                try p.err(period, .no_such_field_designator, .{field_str});
                return error.ParsingFailed;
            }
        } else break;
    }

    if (p.eatToken(.equal) == null) {
        try p.err(p.tok_i, .gnu_missing_eq_designator, .{});
    }
    return true;
}

/// Returns true if the item was filled.
fn findScalarInitializer(
    p: *Parser,
    il: *InitList,
    qt: QualType,
    res: Result,
    first_tok: TokenIndex,
    warned_excess: *bool,
    index_list: *IndexList,
    index_list_top: u32,
) Error!bool {
    if (qt.isInvalid()) return false;
    const gpa = p.comp.gpa;
    if (index_list.items.len <= index_list_top) try index_list.append(gpa, 0);
    const index = index_list.items[index_list_top];

    switch (qt.base(p.comp).type) {
        .complex => |complex_ty| {
            if (il.node != .null or index >= 2) {
                if (!warned_excess.*) try p.err(first_tok, .excess_scalar_init, .{});
                warned_excess.* = true;
                return true;
            }
            if (res.qt.eql(qt, p.comp) and il.list.items.len == 0) {
                try p.setInitializer(il, qt, first_tok, res);
                return true;
            }

            const elem_il = try il.find(gpa, index);
            if (try p.setInitializerIfEqual(elem_il, complex_ty, first_tok, res) or
                try p.findScalarInitializer(
                    elem_il,
                    complex_ty,
                    res,
                    first_tok,
                    warned_excess,
                    index_list,
                    index_list_top + 1,
                ))
            {
                const new_index = index + 1;
                index_list.items[index_list_top] = new_index;
                index_list.items.len = index_list_top + 1;
                return new_index >= 2;
            }

            return false;
        },
        .vector => |vector_ty| {
            if (il.node != .null or index >= vector_ty.len) {
                if (!warned_excess.*) try p.err(first_tok, .excess_vector_init, .{});
                warned_excess.* = true;
                return true;
            }
            if (il.list.items.len == 0 and (res.qt.eql(qt, p.comp) or
                (res.qt.is(p.comp, .vector) and res.qt.sizeCompare(qt, p.comp) == .eq)))
            {
                try p.setInitializer(il, qt, first_tok, res);
                return true;
            }

            const elem_il = try il.find(gpa, index);
            if (try p.setInitializerIfEqual(elem_il, vector_ty.elem, first_tok, res) or
                try p.findScalarInitializer(
                    elem_il,
                    vector_ty.elem,
                    res,
                    first_tok,
                    warned_excess,
                    index_list,
                    index_list_top + 1,
                ))
            {
                const new_index = index + 1;
                index_list.items[index_list_top] = new_index;
                index_list.items.len = index_list_top + 1;
                return new_index >= vector_ty.len;
            }

            return false;
        },
        .array => |array_ty| {
            const max_len = switch (array_ty.len) {
                .fixed, .static => |len| len,
                else => std.math.maxInt(u64),
            };
            if (max_len == 0) {
                try p.err(first_tok, .empty_aggregate_init_braces, .{});
                return true;
            }

            if (il.node != .null or index >= max_len) {
                if (!warned_excess.*) {
                    if (il.node.unpack()) |some| if (p.isStringInit(qt, some)) {
                        try p.err(first_tok, .excess_str_init, .{});
                        warned_excess.* = true;
                        return true;
                    };
                    try p.err(first_tok, .excess_array_init, .{});
                }
                warned_excess.* = true;
                return true;
            }
            if (il.list.items.len == 0 and p.isStringInit(qt, res.node) and
                try p.coerceArrayInit(res, first_tok, qt))
            {
                try p.setInitializer(il, qt, first_tok, res);
                return true;
            }

            const elem_il = try il.find(gpa, index);
            if (try p.setInitializerIfEqual(elem_il, array_ty.elem, first_tok, res) or
                try p.findScalarInitializer(
                    elem_il,
                    array_ty.elem,
                    res,
                    first_tok,
                    warned_excess,
                    index_list,
                    index_list_top + 1,
                ))
            {
                const new_index = index + 1;
                index_list.items[index_list_top] = new_index;
                index_list.items.len = index_list_top + 1;
                return new_index >= max_len;
            }

            return false;
        },
        .@"struct" => |struct_ty| {
            if (struct_ty.fields.len == 0) {
                try p.err(first_tok, .empty_aggregate_init_braces, .{});
                return true;
            }

            if (il.node != .null or index >= struct_ty.fields.len) {
                if (!warned_excess.*) try p.err(first_tok, .excess_struct_init, .{});
                warned_excess.* = true;
                return true;
            }

            const field = struct_ty.fields[@intCast(index)];
            const field_il = try il.find(gpa, index);
            if (try p.setInitializerIfEqual(field_il, field.qt, first_tok, res) or
                try p.findScalarInitializer(
                    field_il,
                    field.qt,
                    res,
                    first_tok,
                    warned_excess,
                    index_list,
                    index_list_top + 1,
                ))
            {
                const new_index = index + 1;
                index_list.items[index_list_top] = new_index;
                index_list.items.len = index_list_top + 1;
                return new_index >= struct_ty.fields.len;
            }

            return false;
        },
        .@"union" => |union_ty| {
            if (union_ty.fields.len == 0) {
                try p.err(first_tok, .empty_aggregate_init_braces, .{});
                return true;
            }

            if (il.node != .null or il.list.items.len > 1 or
                (il.list.items.len == 1 and il.list.items[0].index != index))
            {
                if (!warned_excess.*) try p.err(first_tok, .excess_union_init, .{});
                warned_excess.* = true;
                return true;
            }

            const field = union_ty.fields[@intCast(index)];
            const field_il = try il.find(gpa, index);
            if (try p.setInitializerIfEqual(field_il, field.qt, first_tok, res) or
                try p.findScalarInitializer(
                    field_il,
                    field.qt,
                    res,
                    first_tok,
                    warned_excess,
                    index_list,
                    index_list_top + 1,
                ))
            {
                const new_index = index + 1;
                index_list.items[index_list_top] = new_index;
                index_list.items.len = index_list_top + 1;
            }

            return true;
        },
        else => {
            try p.setInitializer(il, qt, first_tok, res);
            return true;
        },
    }
}

fn setInitializerIfEqual(p: *Parser, il: *InitList, init_qt: QualType, tok: TokenIndex, res: Result) !bool {
    if (!res.qt.eql(init_qt, p.comp)) return false;
    try p.setInitializer(il, init_qt, tok, res);
    return true;
}

const InitItem = struct { il: *InitList, qt: QualType };

fn findBracedInitializer(
    p: *Parser,
    il: *InitList,
    qt: QualType,
    first_tok: TokenIndex,
    index_list: *IndexList,
) Error!?InitItem {
    if (qt.isInvalid()) {
        if (il.node != .null) return .{ .il = il, .qt = qt };
        return null;
    }
    const gpa = p.comp.gpa;
    if (index_list.items.len == 0) try index_list.append(gpa, 0);
    const index = index_list.items[0];

    switch (qt.base(p.comp).type) {
        .complex => |complex_ty| {
            if (il.node != .null) return null;

            if (index < 2) {
                index_list.items[0] = index + 1;
                index_list.items.len = 1;
                return .{ .il = try il.find(gpa, index), .qt = complex_ty };
            }
        },
        .vector => |vector_ty| {
            if (il.node != .null) return null;

            if (index < vector_ty.len) {
                index_list.items[0] = index + 1;
                index_list.items.len = 1;
                return .{ .il = try il.find(gpa, index), .qt = vector_ty.elem };
            }
        },
        .array => |array_ty| {
            if (il.node != .null) return null;

            const max_len = switch (array_ty.len) {
                .fixed, .static => |len| len,
                else => std.math.maxInt(u64),
            };
            if (index < max_len) {
                index_list.items[0] = index + 1;
                index_list.items.len = 1;
                return .{ .il = try il.find(gpa, index), .qt = array_ty.elem };
            }
        },
        .@"struct" => |struct_ty| {
            if (il.node != .null) return null;

            if (index < struct_ty.fields.len) {
                index_list.items[0] = index + 1;
                index_list.items.len = 1;
                const field_qt = struct_ty.fields[@intCast(index)].qt;
                return .{ .il = try il.find(gpa, index), .qt = field_qt };
            }
        },
        .@"union" => |union_ty| {
            if (il.node != .null) return null;
            if (union_ty.fields.len == 0) return null;

            if (index < union_ty.fields.len) {
                index_list.items[0] = index + 1;
                index_list.items.len = 1;
                const field_qt = union_ty.fields[@intCast(index)].qt;
                return .{ .il = try il.find(gpa, index), .qt = field_qt };
            }
        },
        else => {
            try p.err(first_tok, .too_many_scalar_init_braces, .{});
            if (il.node == .null) return .{ .il = il, .qt = qt };
        },
    }
    return null;
}

fn coerceArrayInit(p: *Parser, item: Result, tok: TokenIndex, target: QualType) !bool {
    if (target.isInvalid()) return false;
    const target_array_ty = target.get(p.comp, .array) orelse return false;

    const is_str_lit = p.nodeIs(item.node, .string_literal_expr);
    const maybe_item_array_ty = item.qt.get(p.comp, .array);
    if (!is_str_lit and (!p.nodeIs(item.node, .compound_literal_expr) or maybe_item_array_ty == null)) {
        try p.err(tok, .array_init_str, .{});
        return true; // do not do further coercion
    }

    const target_elem = target_array_ty.elem;
    const item_elem = maybe_item_array_ty.?.elem;

    const target_int = target_elem.get(p.comp, .int) orelse .int; // not int; string compat checks below will fail by design
    const item_int = item_elem.get(p.comp, .int) orelse .int; // not int; string compat checks below will fail by design

    const compatible = target_elem.eql(item_elem, p.comp) or
        (is_str_lit and item_int == .char and (target_int == .uchar or target_int == .schar)) or
        (is_str_lit and item_int == .uchar and (target_int == .uchar or target_int == .schar or target_int == .char));
    if (!compatible) {
        try p.err(tok, .incompatible_array_init, .{ target, item.qt });
        return true; // do not do further coercion
    }

    if (target_array_ty.len == .fixed) {
        const target_len = target_array_ty.len.fixed;
        const item_len = switch (maybe_item_array_ty.?.len) {
            .fixed, .static => |len| len,
            else => unreachable,
        };

        if (is_str_lit) {
            // the null byte of a string can be dropped
            if (item_len - 1 > target_len) {
                try p.err(tok, .str_init_too_long, .{});
            }
        } else if (item_len > target_len) {
            try p.err(tok, .arr_init_too_long, .{ target, item.qt });
        }
    }
    return true;
}

fn coerceInit(p: *Parser, item: *Result, tok: TokenIndex, target: QualType) !void {
    if (target.isInvalid()) return;

    const node = item.node;
    if (target.isAutoType() or target.isC23Auto()) {
        if (p.getNode(node, .member_access_expr) orelse p.getNode(node, .member_access_ptr_expr)) |access| {
            if (access.isBitFieldWidth(&p.tree) != null) try p.err(tok, .auto_type_from_bitfield, .{});
        }
        try item.lvalConversion(p, tok);
        return;
    }

    try item.coerce(p, target, tok, .init);
    if (item.val.opt_ref == .none) runtime: {
        const diagnostic: Diagnostic = switch (p.init_context) {
            .runtime => break :runtime,
            .constexpr => .constexpr_requires_const,
            .static => break :runtime, // TODO: set this to .non_constant_initializer once we are capable of saving all valid values
        };
        p.init_context = .runtime; // Suppress further "non-constant initializer" errors
        try p.err(tok, diagnostic, .{});
    }
    if (target.@"const" or p.init_context == .constexpr) {
        return item.putValue(p);
    }
    return item.saveValue(p);
}

fn isStringInit(p: *Parser, init_qt: QualType, node: Node.Index) bool {
    const init_array_ty = init_qt.get(p.comp, .array) orelse return false;
    if (!init_array_ty.elem.is(p.comp, .int)) return false;
    return p.nodeIs(node, .string_literal_expr);
}

/// Convert InitList into an AST
fn convertInitList(p: *Parser, il: InitList, init_qt: QualType) Error!Node.Index {
    if (init_qt.isInvalid()) {
        return try p.addNode(.{ .default_init_expr = .{
            .last_tok = p.tok_i,
            .qt = init_qt,
        } });
    }

    if (il.node.unpack()) |some| return some;

    const gpa = p.comp.gpa;
    switch (init_qt.base(p.comp).type) {
        .complex => |complex_ty| {
            if (il.list.items.len == 0) {
                return p.addNode(.{ .default_init_expr = .{
                    .last_tok = p.tok_i - 1,
                    .qt = init_qt,
                } });
            }
            const first = try p.convertInitList(il.list.items[0].list, complex_ty);
            const second = if (il.list.items.len > 1)
                try p.convertInitList(il.list.items[1].list, complex_ty)
            else
                null;

            if (il.list.items.len == 2) {
                try p.err(il.tok, .complex_component_init, .{});
            }

            const node = try p.addNode(.{ .array_init_expr = .{
                .container_qt = init_qt,
                .items = if (second) |some|
                    &.{ first, some }
                else
                    &.{first},
                .l_brace_tok = il.tok,
            } });
            if (!complex_ty.isFloat(p.comp)) return node;

            const first_node = il.list.items[0].list.node.unpack() orelse return node;
            const second_node = if (il.list.items.len > 1) il.list.items[1].list.node else .null;

            const first_val = p.tree.value_map.get(first_node) orelse return node;
            const second_val = if (second_node.unpack()) |some| p.tree.value_map.get(some) orelse return node else Value.zero;
            const complex_val = try Value.intern(p.comp, switch (complex_ty.bitSizeof(p.comp)) {
                32 => .{ .complex = .{ .cf32 = .{ first_val.toFloat(f32, p.comp), second_val.toFloat(f32, p.comp) } } },
                64 => .{ .complex = .{ .cf64 = .{ first_val.toFloat(f64, p.comp), second_val.toFloat(f64, p.comp) } } },
                80 => .{ .complex = .{ .cf80 = .{ first_val.toFloat(f80, p.comp), second_val.toFloat(f80, p.comp) } } },
                128 => .{ .complex = .{ .cf128 = .{ first_val.toFloat(f128, p.comp), second_val.toFloat(f128, p.comp) } } },
                else => unreachable,
            });
            try p.tree.value_map.put(gpa, node, complex_val);
            return node;
        },
        .vector => |vector_ty| {
            const list_buf_top = p.list_buf.items.len;
            defer p.list_buf.items.len = list_buf_top;

            const elem_ty = init_qt.childType(p.comp);

            const max_len = vector_ty.len;
            var start: u64 = 0;
            for (il.list.items) |*init| {
                if (init.index > start) {
                    const elem = try p.addNode(.{
                        .array_filler_expr = .{
                            .last_tok = p.tok_i - 1,
                            .count = init.index - start,
                            .qt = elem_ty,
                        },
                    });
                    try p.list_buf.append(gpa, elem);
                }
                start = init.index + 1;

                const elem = try p.convertInitList(init.list, elem_ty);
                try p.list_buf.append(gpa, elem);
            }

            if (start < max_len) {
                const elem = try p.addNode(.{
                    .array_filler_expr = .{
                        .last_tok = p.tok_i - 1,
                        .count = max_len - start,
                        .qt = elem_ty,
                    },
                });
                try p.list_buf.append(gpa, elem);
            }

            return p.addNode(.{ .array_init_expr = .{
                .l_brace_tok = il.tok,
                .container_qt = init_qt,
                .items = p.list_buf.items[list_buf_top..],
            } });
        },
        .array => |array_ty| {
            const list_buf_top = p.list_buf.items.len;
            defer p.list_buf.items.len = list_buf_top;

            const elem_ty = init_qt.childType(p.comp);

            const max_len = switch (array_ty.len) {
                .fixed, .static => |len| len,
                // vla invalid, reported earlier
                .variable => return try p.addNode(.{ .default_init_expr = .{
                    .last_tok = p.tok_i,
                    .qt = init_qt,
                } }),
                else => std.math.maxInt(u64),
            };
            var start: u64 = 0;
            for (il.list.items) |*init| {
                if (init.index > start) {
                    const elem = try p.addNode(.{
                        .array_filler_expr = .{
                            .last_tok = p.tok_i - 1,
                            .count = init.index - start,
                            .qt = elem_ty,
                        },
                    });
                    try p.list_buf.append(gpa, elem);
                }
                start = init.index + 1;

                const elem = try p.convertInitList(init.list, elem_ty);
                try p.list_buf.append(gpa, elem);
            }

            const max_elems = p.comp.maxArrayBytes() / (@max(1, elem_ty.sizeofOrNull(p.comp) orelse 1));
            if (start > max_elems) {
                try p.err(il.tok, .array_too_large, .{});
                start = max_elems;
            }

            var arr_init_qt = init_qt;
            if (array_ty.len == .incomplete) {
                arr_init_qt = try p.comp.type_store.put(gpa, .{ .array = .{
                    .elem = array_ty.elem,
                    .len = .{ .fixed = start },
                } });
            } else if (start < max_len) {
                const elem = try p.addNode(.{
                    .array_filler_expr = .{
                        .last_tok = p.tok_i - 1,
                        .count = max_len - start,
                        .qt = elem_ty,
                    },
                });
                try p.list_buf.append(gpa, elem);
            }

            return p.addNode(.{ .array_init_expr = .{
                .l_brace_tok = il.tok,
                .container_qt = arr_init_qt,
                .items = p.list_buf.items[list_buf_top..],
            } });
        },
        .@"struct" => |struct_ty| {
            assert(struct_ty.layout != null);
            const list_buf_top = p.list_buf.items.len;
            defer p.list_buf.items.len = list_buf_top;

            var init_index: usize = 0;
            for (struct_ty.fields, 0..) |field, i| {
                if (init_index < il.list.items.len and il.list.items[init_index].index == i) {
                    const item = try p.convertInitList(il.list.items[init_index].list, field.qt);
                    try p.list_buf.append(gpa, item);
                    init_index += 1;
                } else {
                    const item = try p.addNode(.{
                        .default_init_expr = .{
                            .last_tok = il.tok,
                            .qt = field.qt,
                        },
                    });
                    try p.list_buf.append(gpa, item);
                }
            }

            return p.addNode(.{ .struct_init_expr = .{
                .l_brace_tok = il.tok,
                .container_qt = init_qt,
                .items = p.list_buf.items[list_buf_top..],
            } });
        },
        .@"union" => |union_ty| {
            const init_node, const index = if (union_ty.fields.len == 0)
                // do nothing for empty unions
                .{ null, 0 }
            else if (il.list.items.len == 0)
                .{ try p.addNode(.{ .default_init_expr = .{
                    .last_tok = p.tok_i - 1,
                    .qt = init_qt,
                } }), 0 }
            else blk: {
                const init = il.list.items[0];
                const index: u32 = @truncate(init.index);
                const field_qt = union_ty.fields[index].qt;

                break :blk .{ try p.convertInitList(init.list, field_qt), index };
            };
            return p.addNode(.{ .union_init_expr = .{
                .field_index = index,
                .initializer = init_node,
                .l_brace_tok = il.tok,
                .union_qt = init_qt,
            } });
        },
        // initializer target is invalid, reported earlier
        else => return try p.addNode(.{ .default_init_expr = .{
            .last_tok = p.tok_i,
            .qt = init_qt,
        } }),
    }
}

fn msvcAsmStmt(p: *Parser) Error!?Node.Index {
    return p.todo("MSVC assembly statements");
}

/// asmOperand : ('[' IDENTIFIER ']')? asmStr '(' expr ')'
fn asmOperand(p: *Parser, kind: enum { output, input }) Error!Tree.Node.AsmStmt.Operand {
    const name = if (p.eatToken(.l_bracket)) |l_bracket| name: {
        const ident = (try p.eatIdentifier()) orelse {
            try p.err(p.tok_i, .expected_identifier, .{});
            return error.ParsingFailed;
        };
        try p.expectClosing(l_bracket, .r_bracket);
        break :name ident;
    } else 0;

    const constraint = try p.asmStr();

    const l_paren = p.eatToken(.l_paren) orelse {
        try p.err(p.tok_i, .expected_token, .{ p.tok_ids[p.tok_i], Token.Id.l_paren });
        return error.ParsingFailed;
    };
    const maybe_res = try p.expr();
    try p.expectClosing(l_paren, .r_paren);
    var res = try p.expectResult(maybe_res);
    if (kind == .output and !p.tree.isLval(res.node)) {
        try p.err(l_paren + 1, .invalid_asm_output, .{});
    } else if (kind == .input) {
        try res.lvalConversion(p, l_paren + 1);
    }
    return .{
        .name = name,
        .constraint = constraint.node,
        .expr = res.node,
    };
}

/// gnuAsmStmt
///  : asmStr
///  | asmStr ':' asmOperand*
///  | asmStr ':' asmOperand* ':' asmOperand*
///  | asmStr ':' asmOperand* ':' asmOperand* : asmStr? (',' asmStr)*
///  | asmStr ':' asmOperand* ':' asmOperand* : asmStr? (',' asmStr)* : IDENTIFIER (',' IDENTIFIER)*
fn gnuAsmStmt(p: *Parser, quals: Tree.GNUAssemblyQualifiers, asm_tok: TokenIndex, l_paren: TokenIndex) Error!Node.Index {
    const gpa = p.comp.gpa;
    const asm_str = try p.asmStr();
    try p.checkAsmStr(asm_str.val, l_paren);

    if (p.tok_ids[p.tok_i] == .r_paren) {
        if (quals.goto) try p.err(p.tok_i, .expected_token, .{ Tree.Token.Id.r_paren, p.tok_ids[p.tok_i] });

        return try p.addNode(.{
            .asm_stmt = .{
                .asm_tok = asm_tok,
                .asm_str = asm_str.node,
                .outputs = &.{},
                .inputs = &.{},
                .clobbers = &.{},
                .labels = &.{},
                .quals = quals,
            },
        });
    }

    const expected_items = 8; // arbitrarily chosen, most assembly will have fewer than 8 inputs/outputs/constraints/names
    const bytes_needed = expected_items * @sizeOf(Tree.Node.AsmStmt.Operand) + expected_items * 2 * @sizeOf(Node.Index);

    var stack_fallback = std.heap.stackFallback(bytes_needed, gpa);
    const allocator = stack_fallback.get();

    var operands: std.ArrayList(Tree.Node.AsmStmt.Operand) = .empty;
    defer operands.deinit(allocator);
    operands.ensureUnusedCapacity(allocator, expected_items) catch unreachable; //stack allocation already succeeded
    var clobbers: NodeList = .empty;
    defer clobbers.deinit(allocator);
    clobbers.ensureUnusedCapacity(allocator, expected_items) catch unreachable; //stack allocation already succeeded
    var labels: NodeList = .empty;
    defer labels.deinit(allocator);
    labels.ensureUnusedCapacity(allocator, expected_items) catch unreachable; //stack allocation already succeeded

    // Outputs
    var ate_extra_colon = false;
    if (p.eatToken(.colon) orelse p.eatToken(.colon_colon)) |tok_i| {
        ate_extra_colon = p.tok_ids[tok_i] == .colon_colon;
        if (!ate_extra_colon) {
            if (p.tok_ids[p.tok_i].isStringLiteral() or p.tok_ids[p.tok_i] == .l_bracket) {
                while (true) {
                    const operand = try p.asmOperand(.output);
                    try operands.append(allocator, operand);
                    if (p.eatToken(.comma) == null) break;
                }
            }
        }
    }
    const num_outputs = operands.items.len;

    // Inputs
    if (ate_extra_colon or p.tok_ids[p.tok_i] == .colon or p.tok_ids[p.tok_i] == .colon_colon) {
        if (ate_extra_colon) {
            ate_extra_colon = false;
        } else {
            ate_extra_colon = p.tok_ids[p.tok_i] == .colon_colon;
            p.tok_i += 1;
        }
        if (!ate_extra_colon) {
            if (p.tok_ids[p.tok_i].isStringLiteral() or p.tok_ids[p.tok_i] == .l_bracket) {
                while (true) {
                    const operand = try p.asmOperand(.input);
                    try operands.append(allocator, operand);
                    if (p.eatToken(.comma) == null) break;
                }
            }
        }
    }

    // Clobbers
    if (ate_extra_colon or p.tok_ids[p.tok_i] == .colon or p.tok_ids[p.tok_i] == .colon_colon) {
        if (ate_extra_colon) {
            ate_extra_colon = false;
        } else {
            ate_extra_colon = p.tok_ids[p.tok_i] == .colon_colon;
            p.tok_i += 1;
        }
        if (!ate_extra_colon and p.tok_ids[p.tok_i].isStringLiteral()) {
            while (true) {
                const clobber = try p.asmStr();
                try clobbers.append(allocator, clobber.node);
                if (p.eatToken(.comma) == null) break;
            }
        }
    }

    if (!quals.goto and (p.tok_ids[p.tok_i] != .r_paren or ate_extra_colon)) {
        try p.err(p.tok_i, .expected_token, .{ Tree.Token.Id.r_paren, p.tok_ids[p.tok_i] });
        return error.ParsingFailed;
    }

    // Goto labels
    if (ate_extra_colon or p.tok_ids[p.tok_i] == .colon) {
        if (!ate_extra_colon) {
            p.tok_i += 1;
        }
        while (true) {
            const ident = (try p.eatIdentifier()) orelse {
                try p.err(p.tok_i, .expected_identifier, .{});
                return error.ParsingFailed;
            };
            const ident_str = p.tokSlice(ident);
            const label = p.findLabel(ident_str) orelse blk: {
                try p.labels.append(gpa, .{ .unresolved_goto = ident });
                break :blk ident;
            };

            const label_addr_node = try p.addNode(.{
                .addr_of_label = .{
                    .label_tok = label,
                    .qt = .void_pointer,
                },
            });
            try labels.append(allocator, label_addr_node);

            if (p.eatToken(.comma) == null) break;
        }
    } else if (quals.goto) {
        try p.err(p.tok_i, .expected_token, .{ Token.Id.colon, p.tok_ids[p.tok_i] });
        return error.ParsingFailed;
    }

    // TODO: validate
    return p.addNode(.{
        .asm_stmt = .{
            .asm_tok = asm_tok,
            .asm_str = asm_str.node,
            .outputs = operands.items[0..num_outputs],
            .inputs = operands.items[num_outputs..],
            .clobbers = clobbers.items,
            .labels = labels.items,
            .quals = quals,
        },
    });
}

fn checkAsmStr(p: *Parser, asm_str: Value, tok: TokenIndex) !void {
    if (!p.comp.langopts.gnu_asm) {
        const str = p.comp.interner.get(asm_str.ref()).bytes;
        if (str.len > 1) {
            // Empty string (just a NUL byte) is ok because it does not emit any assembly
            try p.err(tok, .gnu_asm_disabled, .{});
        }
    }
}

/// assembly
///  : keyword_asm asmQual* '(' asmStr ')'
///  | keyword_asm asmQual* '(' gnuAsmStmt ')'
///  | keyword_asm msvcAsmStmt
fn assembly(p: *Parser, kind: enum { global, decl_label, stmt }) Error!?Node.Index {
    const asm_tok = p.tok_i;
    switch (p.tok_ids[p.tok_i]) {
        .keyword_asm => {
            try p.err(p.tok_i, .extension_token_used, .{});
            p.tok_i += 1;
        },
        .keyword_asm1, .keyword_asm2 => p.tok_i += 1,
        else => return null,
    }

    if (!p.tok_ids[p.tok_i].canOpenGCCAsmStmt()) {
        return p.msvcAsmStmt();
    }

    var quals: Tree.GNUAssemblyQualifiers = .{};
    while (true) : (p.tok_i += 1) switch (p.tok_ids[p.tok_i]) {
        .keyword_volatile, .keyword_volatile1, .keyword_volatile2 => {
            if (kind != .stmt) try p.err(p.tok_i, .meaningless_asm_qual, .{"volatile"});
            if (quals.@"volatile") try p.err(p.tok_i, .duplicate_asm_qual, .{"volatile"});
            quals.@"volatile" = true;
        },
        .keyword_inline, .keyword_inline1, .keyword_inline2 => {
            if (kind != .stmt) try p.err(p.tok_i, .meaningless_asm_qual, .{"inline"});
            if (quals.@"inline") try p.err(p.tok_i, .duplicate_asm_qual, .{"inline"});
            quals.@"inline" = true;
        },
        .keyword_goto => {
            if (kind != .stmt) try p.err(p.tok_i, .meaningless_asm_qual, .{"goto"});
            if (quals.goto) try p.err(p.tok_i, .duplicate_asm_qual, .{"goto"});
            quals.goto = true;
        },
        else => break,
    };

    const l_paren = try p.expectToken(.l_paren);
    var result_node: ?Node.Index = null;
    switch (kind) {
        .decl_label => {
            const asm_str = try p.asmStr();
            const str = try p.removeNull(asm_str.val);

            const attr = Attribute{ .tag = .asm_label, .args = .{ .asm_label = .{ .name = str } }, .syntax = .keyword };
            try p.attr_buf.append(p.comp.gpa, .{ .attr = attr, .tok = asm_tok });
        },
        .global => {
            const asm_str = try p.asmStr();
            try p.checkAsmStr(asm_str.val, l_paren);
            result_node = try p.addNode(.{
                .global_asm = .{
                    .asm_tok = asm_tok,
                    .asm_str = asm_str.node,
                },
            });
        },
        .stmt => result_node = try p.gnuAsmStmt(quals, asm_tok, l_paren),
    }
    try p.expectClosing(l_paren, .r_paren);

    if (kind != .decl_label) _ = try p.expectToken(.semicolon);
    return result_node;
}

/// Same as stringLiteral but errors on unicode and wide string literals
fn asmStr(p: *Parser) Error!Result {
    var i = p.tok_i;
    while (true) : (i += 1) switch (p.tok_ids[i]) {
        .string_literal, .unterminated_string_literal => {},
        .string_literal_utf_16, .string_literal_utf_8, .string_literal_utf_32 => {
            try p.err(p.tok_i, .invalid_asm_str, .{"unicode"});
            return error.ParsingFailed;
        },
        .string_literal_wide => {
            try p.err(p.tok_i, .invalid_asm_str, .{"wide"});
            return error.ParsingFailed;
        },
        else => {
            if (i == p.tok_i) {
                try p.err(p.tok_i, .expected_str_literal_in, .{"asm"});
                return error.ParsingFailed;
            }
            break;
        },
    };
    return p.stringLiteral();
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
fn stmt(p: *Parser) Error!Node.Index {
    if (try p.labeledStmt()) |some| return some;
    if (try p.compoundStmt(false, null)) |some| return some;
    const gpa = p.comp.gpa;
    if (p.eatToken(.keyword_if)) |kw_if| {
        const l_paren = try p.expectToken(.l_paren);

        const cond_tok = p.tok_i;
        var cond = try p.expect(expr);
        try cond.lvalConversion(p, cond_tok);
        try cond.usualUnaryConversion(p, cond_tok);
        if (!cond.qt.isInvalid() and cond.qt.scalarKind(p.comp) == .none)
            try p.err(l_paren + 1, .statement_scalar, .{cond.qt});
        try cond.saveValue(p);

        try p.expectClosing(l_paren, .r_paren);

        const then_body = try p.stmt();
        const else_body = if (p.eatToken(.keyword_else)) |_| try p.stmt() else null;

        if (p.nodeIs(then_body, .null_stmt) and else_body == null) {
            const semicolon_tok = then_body.get(&p.tree).null_stmt.semicolon_or_r_brace_tok;
            const locs = p.pp.tokens.items(.loc);
            const if_loc = locs[kw_if];
            const semicolon_loc = locs[semicolon_tok];
            if (if_loc.line == semicolon_loc.line) {
                try p.err(semicolon_tok, .empty_if_body, .{});
                try p.err(semicolon_tok, .empty_if_body_note, .{});
            }
        }

        return p.addNode(.{ .if_stmt = .{
            .if_tok = kw_if,
            .cond = cond.node,
            .then_body = then_body,
            .else_body = else_body,
        } });
    }
    if (p.eatToken(.keyword_switch)) |kw_switch| {
        const l_paren = try p.expectToken(.l_paren);
        const cond_tok = p.tok_i;
        var cond = try p.expect(expr);
        try cond.lvalConversion(p, cond_tok);
        try cond.usualUnaryConversion(p, cond_tok);

        // Switch condition can't be complex.
        if (!cond.qt.isInvalid() and !cond.qt.isRealInt(p.comp)) {
            try p.err(l_paren + 1, .statement_int, .{cond.qt});
        }

        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        const old_switch = p.@"switch";
        var @"switch": Switch = .{
            .qt = cond.qt,
            .comp = p.comp,
        };
        p.@"switch" = &@"switch";
        defer {
            @"switch".ranges.deinit(gpa);
            p.@"switch" = old_switch;
        }

        const body = try p.stmt();

        return p.addNode(.{ .switch_stmt = .{
            .switch_tok = kw_switch,
            .cond = cond.node,
            .body = body,
        } });
    }
    if (p.eatToken(.keyword_while)) |kw_while| {
        const l_paren = try p.expectToken(.l_paren);

        const cond_tok = p.tok_i;
        var cond = try p.expect(expr);
        try cond.lvalConversion(p, cond_tok);
        try cond.usualUnaryConversion(p, cond_tok);
        if (!cond.qt.isInvalid() and cond.qt.scalarKind(p.comp) == .none)
            try p.err(l_paren + 1, .statement_scalar, .{cond.qt});
        try cond.saveValue(p);

        try p.expectClosing(l_paren, .r_paren);

        const body = body: {
            const old_loop = p.in_loop;
            p.in_loop = true;
            defer p.in_loop = old_loop;
            break :body try p.stmt();
        };

        return p.addNode(.{ .while_stmt = .{
            .while_tok = kw_while,
            .cond = cond.node,
            .body = body,
        } });
    }
    if (p.eatToken(.keyword_do)) |kw_do| {
        const body = body: {
            const old_loop = p.in_loop;
            p.in_loop = true;
            defer p.in_loop = old_loop;
            break :body try p.stmt();
        };

        _ = try p.expectToken(.keyword_while);
        const l_paren = try p.expectToken(.l_paren);

        const cond_tok = p.tok_i;
        var cond = try p.expect(expr);
        try cond.lvalConversion(p, cond_tok);
        try cond.usualUnaryConversion(p, cond_tok);

        if (!cond.qt.isInvalid() and cond.qt.scalarKind(p.comp) == .none)
            try p.err(l_paren + 1, .statement_scalar, .{cond.qt});
        try cond.saveValue(p);
        try p.expectClosing(l_paren, .r_paren);

        _ = try p.expectToken(.semicolon);

        return p.addNode(.{ .do_while_stmt = .{
            .do_tok = kw_do,
            .cond = cond.node,
            .body = body,
        } });
    }
    if (p.eatToken(.keyword_for)) |kw_for| {
        try p.syms.pushScope(p);
        defer p.syms.popScope();
        const decl_buf_top = p.decl_buf.items.len;
        defer p.decl_buf.items.len = decl_buf_top;

        const l_paren = try p.expectToken(.l_paren);
        const got_decl = try p.decl();

        // for (init
        const init_start = p.tok_i;
        var prev_total = p.diagnostics.total;
        const init = init: {
            if (got_decl) break :init null;
            var init = (try p.expr()) orelse break :init null;

            try init.saveValue(p);
            try init.maybeWarnUnused(p, init_start, prev_total);
            break :init init.node;
        };
        if (!got_decl) _ = try p.expectToken(.semicolon);

        // for (init; cond
        const cond = cond: {
            const cond_tok = p.tok_i;
            var cond = (try p.expr()) orelse break :cond null;

            try cond.lvalConversion(p, cond_tok);
            try cond.usualUnaryConversion(p, cond_tok);
            if (!cond.qt.isInvalid() and cond.qt.scalarKind(p.comp) == .none)
                try p.err(l_paren + 1, .statement_scalar, .{cond.qt});
            try cond.saveValue(p);
            break :cond cond.node;
        };
        _ = try p.expectToken(.semicolon);

        // for (init; cond; incr
        const incr_start = p.tok_i;
        prev_total = p.diagnostics.total;
        const incr = incr: {
            var incr = (try p.expr()) orelse break :incr null;

            try incr.maybeWarnUnused(p, incr_start, prev_total);
            try incr.saveValue(p);
            break :incr incr.node;
        };
        try p.expectClosing(l_paren, .r_paren);

        const body = body: {
            const old_loop = p.in_loop;
            p.in_loop = true;
            defer p.in_loop = old_loop;
            break :body try p.stmt();
        };

        return p.addNode(.{ .for_stmt = .{
            .for_tok = kw_for,
            .init = if (decl_buf_top == p.decl_buf.items.len)
                .{ .expr = init }
            else
                .{ .decls = p.decl_buf.items[decl_buf_top..] },
            .cond = cond,
            .incr = incr,
            .body = body,
        } });
    }
    if (p.eatToken(.keyword_goto)) |goto_tok| {
        if (p.eatToken(.asterisk)) |_| {
            const expr_tok = p.tok_i;
            var goto_expr = try p.expect(expr);
            try goto_expr.lvalConversion(p, expr_tok);
            p.computed_goto_tok = p.computed_goto_tok orelse goto_tok;

            if (!goto_expr.qt.isInvalid() and !goto_expr.qt.isPointer(p.comp)) {
                const result_qt = try p.comp.type_store.put(gpa, .{ .pointer = .{
                    .child = .{ .@"const" = true, ._index = .void },
                    .decayed = null,
                } });
                if (!goto_expr.qt.isRealInt(p.comp)) {
                    try p.err(expr_tok, .incompatible_arg, .{ goto_expr.qt, result_qt });
                    return error.ParsingFailed;
                }
                if (goto_expr.val.isZero(p.comp)) {
                    try goto_expr.nullToPointer(p, result_qt, expr_tok);
                } else {
                    try p.err(expr_tok, .implicit_int_to_ptr, .{ goto_expr.qt, result_qt });
                    try goto_expr.castToPointer(p, result_qt, expr_tok);
                }
            }

            return p.addNode(.{ .computed_goto_stmt = .{ .goto_tok = goto_tok, .expr = goto_expr.node } });
        }
        const name_tok = try p.expectIdentifier();
        const str = p.tokSlice(name_tok);
        if (p.findLabel(str) == null) {
            try p.labels.append(gpa, .{ .unresolved_goto = name_tok });
        }
        _ = try p.expectToken(.semicolon);
        return p.addNode(.{ .goto_stmt = .{ .label_tok = name_tok } });
    }
    if (p.eatToken(.keyword_continue)) |cont| {
        if (!p.in_loop) try p.err(cont, .continue_not_in_loop, .{});
        _ = try p.expectToken(.semicolon);
        return p.addNode(.{ .continue_stmt = .{ .continue_tok = cont } });
    }
    if (p.eatToken(.keyword_break)) |br| {
        if (!p.in_loop and p.@"switch" == null) try p.err(br, .break_not_in_loop_or_switch, .{});
        _ = try p.expectToken(.semicolon);
        return p.addNode(.{ .break_stmt = .{ .break_tok = br } });
    }
    if (try p.returnStmt()) |some| return some;
    if (try p.assembly(.stmt)) |some| return some;

    const expr_start = p.tok_i;
    const prev_total = p.diagnostics.total;

    if (try p.expr()) |some| {
        _ = try p.expectToken(.semicolon);
        try some.maybeWarnUnused(p, expr_start, prev_total);
        return some.node;
    }

    const attr_buf_top = p.attr_buf.len;
    defer p.attr_buf.len = attr_buf_top;
    try p.attributeSpecifier();

    if (p.eatToken(.semicolon)) |semicolon| {
        return p.addNode(.{ .null_stmt = .{
            .semicolon_or_r_brace_tok = semicolon,
            .qt = try Attribute.applyStatementAttributes(p, expr_start, attr_buf_top),
        } });
    }

    try p.err(p.tok_i, .expected_stmt, .{});
    return error.ParsingFailed;
}

/// labeledStmt
/// : IDENTIFIER ':' stmt
/// | keyword_case integerConstExpr ':' stmt
/// | keyword_default ':' stmt
fn labeledStmt(p: *Parser) Error!?Node.Index {
    if ((p.tok_ids[p.tok_i] == .identifier or p.tok_ids[p.tok_i] == .extended_identifier) and p.tok_ids[p.tok_i + 1] == .colon) {
        const name_tok = try p.expectIdentifier();
        const str = p.tokSlice(name_tok);
        if (p.findLabel(str)) |some| {
            try p.err(name_tok, .duplicate_label, .{str});
            try p.err(some, .previous_label, .{str});
        } else {
            p.label_count += 1;
            try p.labels.append(p.comp.gpa, .{ .label = name_tok });
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
        try p.attributeSpecifier();

        return try p.addNode(.{ .labeled_stmt = .{
            .qt = try Attribute.applyLabelAttributes(p, attr_buf_top),
            .body = try p.labelableStmt(),
            .label_tok = name_tok,
        } });
    } else if (p.eatToken(.keyword_case)) |case| {
        var first_item = try p.integerConstExpr(.gnu_folding_extension);
        const ellipsis = p.tok_i;
        var second_item = if (p.eatToken(.ellipsis) != null) blk: {
            try p.err(ellipsis, .gnu_switch_range, .{});
            break :blk try p.integerConstExpr(.gnu_folding_extension);
        } else null;
        _ = try p.expectToken(.colon);

        if (p.@"switch") |@"switch"| check: {
            if (@"switch".qt.hasIncompleteSize(p.comp)) break :check; // error already reported for incomplete size

            // Coerce to switch condition type
            try first_item.coerce(p, @"switch".qt, case + 1, .assign);
            try first_item.putValue(p);
            if (second_item) |*item| {
                try item.coerce(p, @"switch".qt, ellipsis + 1, .assign);
                try item.putValue(p);
            }

            const first = first_item.val;
            const last = if (second_item) |second| second.val else first;
            if (first.opt_ref == .none) {
                try p.err(case + 1, .case_val_unavailable, .{});
                break :check;
            } else if (last.opt_ref == .none) {
                try p.err(ellipsis + 1, .case_val_unavailable, .{});
                break :check;
            } else if (last.compare(.lt, first, p.comp)) {
                try p.err(case + 1, .empty_case_range, .{});
                break :check;
            }

            // TODO cast to target type
            const prev = (try @"switch".add(first, last, case + 1)) orelse break :check;

            // TODO check which value was already handled
            try p.err(case + 1, .duplicate_switch_case, .{first_item});
            try p.err(prev.tok, .previous_case, .{});
        } else {
            try p.err(case, .case_not_in_switch, .{"case"});
        }

        return try p.addNode(.{ .case_stmt = .{
            .case_tok = case,
            .start = first_item.node,
            .end = if (second_item) |some| some.node else null,
            .body = try p.labelableStmt(),
        } });
    } else if (p.eatToken(.keyword_default)) |default| {
        _ = try p.expectToken(.colon);
        const node = try p.addNode(.{ .default_stmt = .{
            .default_tok = default,
            .body = try p.labelableStmt(),
        } });

        const @"switch" = p.@"switch" orelse {
            try p.err(default, .case_not_in_switch, .{"default"});
            return node;
        };
        if (@"switch".default) |previous| {
            try p.err(default, .multiple_default, .{});
            try p.err(previous, .previous_case, .{});
        } else {
            @"switch".default = default;
        }
        return node;
    } else return null;
}

fn labelableStmt(p: *Parser) Error!Node.Index {
    if (p.tok_ids[p.tok_i] == .r_brace) {
        try p.err(p.tok_i, .label_compound_end, .{});
        return p.addNode(.{ .null_stmt = .{
            .semicolon_or_r_brace_tok = p.tok_i,
            .qt = .void,
        } });
    }
    return p.stmt();
}

const StmtExprState = struct {
    last_expr_tok: TokenIndex = 0,
    last_expr_qt: QualType = .void,
};

/// compoundStmt : '{' ( decl | keyword_extension decl | staticAssert | stmt)* '}'
fn compoundStmt(p: *Parser, is_fn_body: bool, stmt_expr_state: ?*StmtExprState) Error!?Node.Index {
    const l_brace = p.eatToken(.l_brace) orelse return null;

    const gpa = p.comp.gpa;
    const decl_buf_top = p.decl_buf.items.len;
    defer p.decl_buf.items.len = decl_buf_top;

    // the parameters of a function are in the same scope as the body
    if (!is_fn_body) try p.syms.pushScope(p);
    defer if (!is_fn_body) p.syms.popScope();

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
        if (stmt_expr_state) |state| {
            state.* = .{
                .last_expr_tok = stmt_tok,
                .last_expr_qt = s.qt(&p.tree),
            };
        }
        try p.decl_buf.append(gpa, s);

        if (noreturn_index == null and p.nodeIsNoreturn(s) == .yes) {
            noreturn_index = p.tok_i;
            noreturn_label_count = p.label_count;
        }
        switch (s.get(&p.tree)) {
            .case_stmt, .default_stmt, .labeled_stmt => noreturn_index = null,
            else => {},
        }
    }
    const r_brace = p.tok_i - 1;

    if (noreturn_index) |some| {
        // if new labels were defined we cannot be certain that the code is unreachable
        if (some != p.tok_i - 1 and noreturn_label_count == p.label_count) try p.err(some, .unreachable_code, .{});
    }
    if (is_fn_body) {
        const last_noreturn = if (p.decl_buf.items.len == decl_buf_top)
            .no
        else
            p.nodeIsNoreturn(p.decl_buf.items[p.decl_buf.items.len - 1]);

        const ret_qt: QualType = if (p.func.qt.?.get(p.comp, .func)) |func_ty| func_ty.return_type else .invalid;
        if (last_noreturn != .yes and !ret_qt.isInvalid()) {
            var return_zero = false;
            if (last_noreturn == .no) switch (ret_qt.base(p.comp).type) {
                .void => {},
                .func, .array => {}, // Invalid, error reported elsewhere
                else => {
                    const func_name = p.tokSlice(p.func.name);
                    const interned_name = try p.comp.internString(func_name);

                    if (interned_name == p.string_ids.main_id) {
                        if (ret_qt.get(p.comp, .int)) |int_ty| {
                            if (int_ty == .int) return_zero = true;
                        }
                    }

                    if (!return_zero) {
                        try p.err(p.tok_i - 1, .func_does_not_return, .{func_name});
                    }
                },
            };

            const implicit_ret = try p.addNode(.{ .return_stmt = .{
                .return_tok = r_brace,
                .return_qt = ret_qt,
                .operand = .{ .implicit = return_zero },
            } });
            try p.decl_buf.append(gpa, implicit_ret);
        }
        if (p.func.ident) |some| try p.decl_buf.insert(gpa, decl_buf_top, some.node);
        if (p.func.pretty_ident) |some| try p.decl_buf.insert(gpa, decl_buf_top, some.node);
    }

    return try p.addNode(.{ .compound_stmt = .{
        .body = p.decl_buf.items[decl_buf_top..],
        .l_brace_tok = l_brace,
    } });
}

fn pointerValue(p: *Parser, node: Node.Index, offset: Value) !Value {
    switch (node.get(&p.tree)) {
        .decl_ref_expr => |decl_ref| {
            const var_name = try p.comp.internString(p.tokSlice(decl_ref.name_tok));
            const sym = p.syms.findSymbol(var_name) orelse return .{};
            const sym_node = sym.node.unpack() orelse return .{};
            return Value.pointer(.{ .node = @intFromEnum(sym_node), .offset = offset.ref() }, p.comp);
        },
        .string_literal_expr => return p.tree.value_map.get(node).?,
        else => return .{},
    }
}

const NoreturnKind = enum { no, yes, complex };

fn nodeIsNoreturn(p: *Parser, node: Node.Index) NoreturnKind {
    switch (node.get(&p.tree)) {
        .break_stmt, .continue_stmt, .return_stmt => return .yes,
        .if_stmt => |@"if"| {
            const else_type = p.nodeIsNoreturn(@"if".else_body orelse return .no);
            const then_type = p.nodeIsNoreturn(@"if".then_body);
            if (then_type == .complex or else_type == .complex) return .complex;
            if (then_type == .yes and else_type == .yes) return .yes;
            return .no;
        },
        .compound_stmt => |compound| {
            for (compound.body) |body_stmt| {
                const kind = p.nodeIsNoreturn(body_stmt);
                if (kind != .no) return kind;
            }
            return .no;
        },
        .labeled_stmt => |labeled| {
            return p.nodeIsNoreturn(labeled.body);
        },
        .default_stmt => |default| {
            return p.nodeIsNoreturn(default.body);
        },
        .while_stmt, .do_while_stmt, .for_stmt, .switch_stmt => return .complex,
        else => return .no,
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
            .semicolon => if (parens == 0) {
                p.tok_i += 1;
                return;
            },
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
            .keyword_c23_thread_local,
            .keyword_inline,
            .keyword_inline1,
            .keyword_inline2,
            .keyword_noreturn,
            .keyword_void,
            .keyword_bool,
            .keyword_c23_bool,
            .keyword_char,
            .keyword_short,
            .keyword_int,
            .keyword_long,
            .keyword_signed,
            .keyword_signed1,
            .keyword_signed2,
            .keyword_unsigned,
            .keyword_float,
            .keyword_double,
            .keyword_complex,
            .keyword_atomic,
            .keyword_enum,
            .keyword_struct,
            .keyword_union,
            .keyword_alignas,
            .keyword_c23_alignas,
            .keyword_typeof,
            .keyword_typeof1,
            .keyword_typeof2,
            .keyword_typeof_unqual,
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

fn returnStmt(p: *Parser) Error!?Node.Index {
    const ret_tok = p.eatToken(.keyword_return) orelse return null;

    const e_tok = p.tok_i;
    var ret_expr = try p.expr();
    _ = try p.expectToken(.semicolon);

    const func_qt = p.func.qt.?; // `return` cannot be parsed outside of a function.
    const ret_qt: QualType = if (func_qt.get(p.comp, .func)) |func_ty| func_ty.return_type else .invalid;
    const ret_void = !ret_qt.isInvalid() and ret_qt.is(p.comp, .void);

    if (func_qt.hasAttribute(p.comp, .noreturn)) {
        try p.err(e_tok, .invalid_noreturn, .{p.tokSlice(p.func.name)});
    }

    if (ret_expr) |*some| {
        if (ret_void) {
            if (!some.qt.is(p.comp, .void)) {
                try p.err(e_tok, .void_func_returns_value, .{p.tokSlice(p.func.name)});
            }
        } else {
            try some.coerce(p, ret_qt, e_tok, .ret);

            try some.saveValue(p);
        }
    } else if (!ret_void) {
        try p.err(ret_tok, .func_should_return, .{p.tokSlice(p.func.name)});
    }

    return try p.addNode(.{ .return_stmt = .{
        .return_tok = ret_tok,
        .operand = if (ret_expr) |some| .{ .expr = some.node } else .none,
        .return_qt = ret_qt,
    } });
}

// ====== expressions ======

pub fn macroExpr(p: *Parser) Compilation.Error!bool {
    const res = p.expect(condExpr) catch |e| switch (e) {
        error.OutOfMemory => return error.OutOfMemory,
        error.FatalError => return error.FatalError,
        error.ParsingFailed => return false,
    };
    return res.val.toBool(p.comp);
}

const CallExpr = union(enum) {
    standard: Node.Index,
    builtin: struct {
        builtin_tok: TokenIndex,
        expanded: Builtins.Expanded,
    },

    fn init(p: *Parser, call_node: Node.Index, func_node: Node.Index) CallExpr {
        if (p.getNode(call_node, .builtin_ref)) |builtin_ref| {
            const name = p.tokSlice(builtin_ref.name_tok);
            const expanded = p.comp.builtins.lookup(name);
            return .{ .builtin = .{ .builtin_tok = builtin_ref.name_tok, .expanded = expanded } };
        }
        return .{ .standard = func_node };
    }

    fn shouldPerformLvalConversion(self: CallExpr, arg_idx: u32) bool {
        return switch (self) {
            .standard => true,
            .builtin => |builtin| switch (builtin.expanded.tag) {
                .common => |tag| switch (tag) {
                    .__builtin_va_start,
                    .__va_start,
                    .va_start,
                    => arg_idx != 1,
                    else => true,
                },
                else => true,
            },
        };
    }

    fn shouldPromoteVarArg(self: CallExpr, arg_idx: u32) bool {
        return switch (self) {
            .standard => true,
            .builtin => |builtin| switch (builtin.expanded.tag) {
                .common => |tag| switch (tag) {
                    .__builtin_va_start,
                    .__va_start,
                    .va_start,
                    => arg_idx != 1,
                    .__builtin_add_overflow,
                    .__builtin_complex,
                    .__builtin_isinf,
                    .__builtin_isinf_sign,
                    .__builtin_mul_overflow,
                    .__builtin_isnan,
                    .__builtin_sub_overflow,
                    => false,
                    else => true,
                },
                else => false,
            },
        };
    }

    fn shouldCoerceArg(self: CallExpr, arg_idx: u32) bool {
        _ = self;
        _ = arg_idx;
        return true;
    }

    fn checkVarArg(self: CallExpr, p: *Parser, first_after: TokenIndex, param_tok: TokenIndex, arg: *Result, arg_idx: u32) !void {
        if (self == .standard) return;

        const builtin_tok = self.builtin.builtin_tok;
        switch (self.builtin.expanded.tag) {
            .common => |tag| switch (tag) {
                .__builtin_va_start,
                .__va_start,
                .va_start,
                => return p.checkVaStartArg(builtin_tok, first_after, param_tok, arg, arg_idx),
                .__builtin_complex => return p.checkComplexArg(builtin_tok, first_after, param_tok, arg, arg_idx),
                .__builtin_add_overflow,
                .__builtin_sub_overflow,
                .__builtin_mul_overflow,
                => return p.checkArithOverflowArg(builtin_tok, first_after, param_tok, arg, arg_idx),

                .__builtin_elementwise_abs,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .sint_float),
                .__builtin_elementwise_bitreverse,
                .__builtin_elementwise_add_sat,
                .__builtin_elementwise_sub_sat,
                .__builtin_elementwise_popcount,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .int),
                .__builtin_elementwise_canonicalize,
                .__builtin_elementwise_ceil,
                .__builtin_elementwise_cos,
                .__builtin_elementwise_exp,
                .__builtin_elementwise_exp2,
                .__builtin_elementwise_floor,
                .__builtin_elementwise_log,
                .__builtin_elementwise_log10,
                .__builtin_elementwise_log2,
                .__builtin_elementwise_nearbyint,
                .__builtin_elementwise_rint,
                .__builtin_elementwise_round,
                .__builtin_elementwise_roundeven,
                .__builtin_elementwise_sin,
                .__builtin_elementwise_sqrt,
                .__builtin_elementwise_trunc,
                .__builtin_elementwise_copysign,
                .__builtin_elementwise_pow,
                .__builtin_elementwise_fma,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .float),
                .__builtin_elementwise_max,
                .__builtin_elementwise_min,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .both),

                .__builtin_reduce_add,
                .__builtin_reduce_mul,
                .__builtin_reduce_and,
                .__builtin_reduce_or,
                .__builtin_reduce_xor,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .int),
                .__builtin_reduce_max,
                .__builtin_reduce_min,
                => return p.checkElementwiseArg(param_tok, arg, arg_idx, .both),

                .__builtin_nondeterministic_value => return p.checkElementwiseArg(param_tok, arg, arg_idx, .both),
                .__builtin_nontemporal_load => return p.checkNonTemporalArg(param_tok, arg, arg_idx, .load),
                .__builtin_nontemporal_store => return p.checkNonTemporalArg(param_tok, arg, arg_idx, .store),

                .__sync_lock_release => return p.checkSyncArg(param_tok, arg, arg_idx, 1),
                .__sync_fetch_and_add,
                .__sync_fetch_and_and,
                .__sync_fetch_and_nand,
                .__sync_fetch_and_or,
                .__sync_fetch_and_sub,
                .__sync_fetch_and_xor,
                .__sync_add_and_fetch,
                .__sync_and_and_fetch,
                .__sync_nand_and_fetch,
                .__sync_or_and_fetch,
                .__sync_sub_and_fetch,
                .__sync_xor_and_fetch,
                .__sync_swap,
                .__sync_lock_test_and_set,
                => return p.checkSyncArg(param_tok, arg, arg_idx, 2),
                .__sync_bool_compare_and_swap,
                .__sync_val_compare_and_swap,
                => return p.checkSyncArg(param_tok, arg, arg_idx, 3),
                else => {},
            },
            else => {},
        }
    }

    /// Some functions cannot be expressed as standard C prototypes. For example `__builtin_complex` requires
    /// two arguments of the same real floating point type (e.g. two doubles or two floats). These functions are
    /// encoded as varargs functions with custom typechecking. Since varargs functions do not have a fixed number
    /// of arguments, `paramCountOverride` is used to tell us how many arguments we should actually expect to see for
    /// these custom-typechecked functions.
    fn paramCountOverride(self: CallExpr) ?u32 {
        return switch (self) {
            .standard => null,
            .builtin => |builtin| switch (builtin.expanded.tag) {
                .common => |tag| switch (tag) {
                    .__c11_atomic_thread_fence,
                    .__atomic_thread_fence,
                    .__c11_atomic_signal_fence,
                    .__atomic_signal_fence,
                    .__c11_atomic_is_lock_free,
                    .__builtin_isinf,
                    .__builtin_isinf_sign,
                    .__builtin_isnan,
                    .__builtin_elementwise_abs,
                    .__builtin_elementwise_bitreverse,
                    .__builtin_elementwise_canonicalize,
                    .__builtin_elementwise_ceil,
                    .__builtin_elementwise_cos,
                    .__builtin_elementwise_exp,
                    .__builtin_elementwise_exp2,
                    .__builtin_elementwise_floor,
                    .__builtin_elementwise_log,
                    .__builtin_elementwise_log10,
                    .__builtin_elementwise_log2,
                    .__builtin_elementwise_nearbyint,
                    .__builtin_elementwise_rint,
                    .__builtin_elementwise_round,
                    .__builtin_elementwise_roundeven,
                    .__builtin_elementwise_sin,
                    .__builtin_elementwise_sqrt,
                    .__builtin_elementwise_trunc,
                    .__builtin_elementwise_popcount,
                    .__builtin_nontemporal_load,
                    .__builtin_nondeterministic_value,
                    .__builtin_reduce_add,
                    .__builtin_reduce_mul,
                    .__builtin_reduce_and,
                    .__builtin_reduce_or,
                    .__builtin_reduce_xor,
                    .__builtin_reduce_max,
                    .__builtin_reduce_min,
                    => 1,

                    .__builtin_complex,
                    .__c11_atomic_load,
                    .__atomic_load_n,
                    .__c11_atomic_init,
                    .__builtin_elementwise_add_sat,
                    .__builtin_elementwise_copysign,
                    .__builtin_elementwise_max,
                    .__builtin_elementwise_min,
                    .__builtin_elementwise_pow,
                    .__builtin_elementwise_sub_sat,
                    .__builtin_nontemporal_store,
                    => 2,

                    .__c11_atomic_store,
                    .__atomic_store,
                    .__c11_atomic_exchange,
                    .__atomic_exchange,
                    .__c11_atomic_fetch_add,
                    .__c11_atomic_fetch_sub,
                    .__c11_atomic_fetch_or,
                    .__c11_atomic_fetch_xor,
                    .__c11_atomic_fetch_and,
                    .__atomic_fetch_add,
                    .__atomic_fetch_sub,
                    .__atomic_fetch_and,
                    .__atomic_fetch_xor,
                    .__atomic_fetch_or,
                    .__atomic_fetch_nand,
                    .__atomic_add_fetch,
                    .__atomic_sub_fetch,
                    .__atomic_and_fetch,
                    .__atomic_xor_fetch,
                    .__atomic_or_fetch,
                    .__atomic_nand_fetch,
                    .__builtin_add_overflow,
                    .__builtin_sub_overflow,
                    .__builtin_mul_overflow,
                    .__builtin_elementwise_fma,
                    .__atomic_exchange_n,
                    => 3,

                    .__c11_atomic_compare_exchange_strong,
                    .__c11_atomic_compare_exchange_weak,
                    => 5,

                    .__atomic_compare_exchange,
                    .__atomic_compare_exchange_n,
                    => 6,
                    else => null,
                },
                else => null,
            },
        };
    }

    fn returnType(self: CallExpr, p: *Parser, args: []const Node.Index, func_qt: QualType) !QualType {
        if (self == .standard) {
            return if (func_qt.get(p.comp, .func)) |func_ty| func_ty.return_type else .invalid;
        }
        const builtin = self.builtin;
        const func_ty = func_qt.get(p.comp, .func).?;
        return switch (builtin.expanded.tag) {
            .common => |tag| switch (tag) {
                .__c11_atomic_exchange => {
                    if (args.len != 4) return .invalid; // wrong number of arguments; already an error
                    const second_param = args[2];
                    return second_param.qt(&p.tree);
                },
                .__c11_atomic_load => {
                    if (args.len != 3) return .invalid; // wrong number of arguments; already an error
                    const first_param = args[1];
                    const qt = first_param.qt(&p.tree);
                    if (!qt.isPointer(p.comp)) return .invalid;
                    return qt.childType(p.comp);
                },

                .__atomic_fetch_add,
                .__atomic_add_fetch,
                .__c11_atomic_fetch_add,

                .__atomic_fetch_sub,
                .__atomic_sub_fetch,
                .__c11_atomic_fetch_sub,

                .__atomic_fetch_and,
                .__atomic_and_fetch,
                .__c11_atomic_fetch_and,

                .__atomic_fetch_xor,
                .__atomic_xor_fetch,
                .__c11_atomic_fetch_xor,

                .__atomic_fetch_or,
                .__atomic_or_fetch,
                .__c11_atomic_fetch_or,

                .__atomic_fetch_nand,
                .__atomic_nand_fetch,
                .__c11_atomic_fetch_nand,

                .__atomic_exchange_n,
                => {
                    if (args.len != 3) return .invalid; // wrong number of arguments; already an error
                    const second_param = args[2];
                    return second_param.qt(&p.tree);
                },
                .__builtin_complex => {
                    if (args.len < 1) return .invalid; // not enough arguments; already an error
                    const last_param = args[args.len - 1];
                    return try last_param.qt(&p.tree).toComplex(p.comp);
                },
                .__atomic_compare_exchange,
                .__atomic_compare_exchange_n,
                .__c11_atomic_is_lock_free,
                .__sync_bool_compare_and_swap,
                => .bool,

                .__c11_atomic_compare_exchange_strong,
                .__c11_atomic_compare_exchange_weak,
                => {
                    if (args.len != 6) return .invalid; // wrong number of arguments
                    const third_param = args[3];
                    return third_param.qt(&p.tree);
                },

                .__builtin_elementwise_abs,
                .__builtin_elementwise_bitreverse,
                .__builtin_elementwise_canonicalize,
                .__builtin_elementwise_ceil,
                .__builtin_elementwise_cos,
                .__builtin_elementwise_exp,
                .__builtin_elementwise_exp2,
                .__builtin_elementwise_floor,
                .__builtin_elementwise_log,
                .__builtin_elementwise_log10,
                .__builtin_elementwise_log2,
                .__builtin_elementwise_nearbyint,
                .__builtin_elementwise_rint,
                .__builtin_elementwise_round,
                .__builtin_elementwise_roundeven,
                .__builtin_elementwise_sin,
                .__builtin_elementwise_sqrt,
                .__builtin_elementwise_trunc,
                .__builtin_elementwise_add_sat,
                .__builtin_elementwise_copysign,
                .__builtin_elementwise_max,
                .__builtin_elementwise_min,
                .__builtin_elementwise_pow,
                .__builtin_elementwise_sub_sat,
                .__builtin_elementwise_fma,
                .__builtin_elementwise_popcount,
                .__builtin_nondeterministic_value,
                => {
                    if (args.len < 1) return .invalid; // not enough arguments; already an error
                    const last_param = args[args.len - 1];
                    return last_param.qt(&p.tree);
                },
                .__builtin_nontemporal_load,
                .__builtin_reduce_add,
                .__builtin_reduce_mul,
                .__builtin_reduce_and,
                .__builtin_reduce_or,
                .__builtin_reduce_xor,
                .__builtin_reduce_max,
                .__builtin_reduce_min,
                => {
                    if (args.len < 1) return .invalid; // not enough arguments; already an error
                    const last_param = args[args.len - 1];
                    return last_param.qt(&p.tree).childType(p.comp);
                },
                .__sync_add_and_fetch,
                .__sync_and_and_fetch,
                .__sync_fetch_and_add,
                .__sync_fetch_and_and,
                .__sync_fetch_and_nand,
                .__sync_fetch_and_or,
                .__sync_fetch_and_sub,
                .__sync_fetch_and_xor,
                .__sync_lock_test_and_set,
                .__sync_nand_and_fetch,
                .__sync_or_and_fetch,
                .__sync_sub_and_fetch,
                .__sync_swap,
                .__sync_xor_and_fetch,
                .__sync_val_compare_and_swap,
                .__atomic_load_n,
                => {
                    if (args.len < 1) return .invalid; // not enough arguments; already an error
                    const first_param = args[0];
                    return first_param.qt(&p.tree).childType(p.comp);
                },
                else => func_ty.return_type,
            },
            else => func_ty.return_type,
        };
    }

    fn finish(self: CallExpr, p: *Parser, func_qt: QualType, list_buf_top: usize, l_paren: TokenIndex) Error!Result {
        const args = p.list_buf.items[list_buf_top..];
        const return_qt = try self.returnType(p, args, func_qt);
        switch (self) {
            .standard => |func_node| return .{
                .qt = return_qt,
                .node = try p.addNode(.{ .call_expr = .{
                    .l_paren_tok = l_paren,
                    .qt = return_qt.unqualified(),
                    .callee = func_node,
                    .args = args,
                } }),
            },
            .builtin => |builtin| return .{
                .val = try evalBuiltin(builtin.expanded, p, args),
                .qt = return_qt,
                .node = try p.addNode(.{ .builtin_call_expr = .{
                    .builtin_tok = builtin.builtin_tok,
                    .qt = return_qt,
                    .args = args,
                } }),
            },
        }
    }
};

pub const Result = struct {
    node: Node.Index,
    qt: QualType = .int,
    val: Value = .{},

    fn maybeWarnUnused(res: Result, p: *Parser, expr_start: TokenIndex, prev_total: usize) Error!void {
        if (res.qt.is(p.comp, .void)) return;
        if (res.qt.isInvalid()) return;
        // // don't warn about unused result if the expression contained errors besides other unused results
        if (p.diagnostics.total != prev_total) return; // TODO improve
        // for (p.diagnostics.list.items[err_start..]) |err_item| {
        //     if (err_item.tag != .unused_value) return;
        // }
        loop: switch (res.node.get(&p.tree)) {
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
            .pre_inc_expr,
            .pre_dec_expr,
            .post_inc_expr,
            .post_dec_expr,
            => {},
            .call_expr => |call| {
                const call_info = p.tree.callableResultUsage(call.callee) orelse return;
                if (call_info.nodiscard) try p.err(expr_start, .nodiscard_unused, .{p.tokSlice(call_info.tok)});
                if (call_info.warn_unused_result) try p.err(expr_start, .warn_unused_result, .{p.tokSlice(call_info.tok)});
            },
            .builtin_call_expr => |call| {
                const expanded = p.comp.builtins.lookup(p.tokSlice(call.builtin_tok));
                const attributes = expanded.attributes;
                if (attributes.pure) try p.err(call.builtin_tok, .builtin_unused, .{"pure"});
                if (attributes.@"const") try p.err(call.builtin_tok, .builtin_unused, .{"const"});
            },
            .stmt_expr => |stmt_expr| {
                const compound = stmt_expr.operand.get(&p.tree).compound_stmt;
                continue :loop compound.body[compound.body.len - 1].get(&p.tree);
            },
            .comma_expr => |comma| continue :loop comma.rhs.get(&p.tree),
            .paren_expr => |grouped| continue :loop grouped.operand.get(&p.tree),
            else => try p.err(expr_start, .unused_value, .{}),
        }
    }

    fn boolRes(lhs: *Result, p: *Parser, tag: std.meta.Tag(Node), rhs: Result, tok_i: TokenIndex) !void {
        if (lhs.val.opt_ref == .null) {
            lhs.val = .zero;
        }
        if (!lhs.qt.isInvalid()) {
            if (lhs.qt.get(p.comp, .vector)) |vec| {
                if (!vec.elem.isInt(p.comp)) {
                    lhs.qt = try p.comp.type_store.put(p.comp.gpa, .{
                        .vector = .{ .elem = .int, .len = vec.len },
                    });
                }
            } else {
                lhs.qt = .int;
            }
        }
        return lhs.bin(p, tag, rhs, tok_i);
    }

    fn bin(lhs: *Result, p: *Parser, rt_tag: std.meta.Tag(Node), rhs: Result, tok_i: TokenIndex) !void {
        const bin_data: Node.Binary = .{
            .op_tok = tok_i,
            .lhs = lhs.node,
            .rhs = rhs.node,
            .qt = lhs.qt,
        };
        switch (rt_tag) {
            // zig fmt: off
            inline .comma_expr, .assign_expr, .mul_assign_expr, .div_assign_expr,
            .mod_assign_expr, .add_assign_expr, .sub_assign_expr, .shl_assign_expr,
            .shr_assign_expr, .bit_and_assign_expr, .bit_xor_assign_expr,
            .bit_or_assign_expr, .bool_or_expr, .bool_and_expr, .bit_or_expr,
            .bit_xor_expr, .bit_and_expr, .equal_expr, .not_equal_expr,
            .less_than_expr, .less_than_equal_expr, .greater_than_expr,
            .greater_than_equal_expr, .shl_expr, .shr_expr, .add_expr,
            .sub_expr, .mul_expr, .div_expr, .mod_expr,
            // zig fmt: on
            => |tag| lhs.node = try p.addNode(@unionInit(Node, @tagName(tag), bin_data)),
            else => unreachable,
        }
    }

    fn un(operand: *Result, p: *Parser, rt_tag: std.meta.Tag(Node), tok_i: TokenIndex) Error!void {
        const un_data: Node.Unary = .{
            .op_tok = tok_i,
            .operand = operand.node,
            .qt = operand.qt,
        };
        switch (rt_tag) {
            // zig fmt: off
            inline .addr_of_expr, .deref_expr, .plus_expr, .negate_expr,
            .bit_not_expr, .bool_not_expr, .pre_inc_expr, .pre_dec_expr,
            .imag_expr, .real_expr, .post_inc_expr,.post_dec_expr,
            .paren_expr, .stmt_expr, .imaginary_literal, .compound_assign_dummy_expr,
            // zig fmt: on
            => |tag| operand.node = try p.addNode(@unionInit(Node, @tagName(tag), un_data)),
            else => unreachable,
        }
    }

    fn implicitCast(operand: *Result, p: *Parser, kind: Node.Cast.Kind, tok: TokenIndex) Error!void {
        operand.node = try p.addNode(.{
            .cast = .{
                .l_paren = tok,
                .kind = kind,
                .operand = operand.node,
                .qt = operand.qt,
                .implicit = true,
            },
        });
    }

    fn adjustCondExprPtrs(a: *Result, tok: TokenIndex, b: *Result, p: *Parser) !bool {
        assert(a.qt.isPointer(p.comp) and b.qt.isPointer(p.comp));
        const gpa = p.comp.gpa;

        const a_elem = a.qt.childType(p.comp);
        const b_elem = b.qt.childType(p.comp);
        if (a_elem.eqlQualified(b_elem, p.comp)) return true;

        const has_void_pointer_branch = a.qt.scalarKind(p.comp) == .void_pointer or
            b.qt.scalarKind(p.comp) == .void_pointer;

        const only_quals_differ = a_elem.eql(b_elem, p.comp);
        const pointers_compatible = only_quals_differ or has_void_pointer_branch;

        var adjusted_elem_qt = a_elem;
        if (!pointers_compatible or has_void_pointer_branch) {
            if (!pointers_compatible) {
                try p.err(tok, .pointer_mismatch, .{ a.qt, b.qt });
            }
            adjusted_elem_qt = .void;
        }

        if (pointers_compatible) {
            adjusted_elem_qt.@"const" = a_elem.@"const" or b_elem.@"const";
            adjusted_elem_qt.@"volatile" = a_elem.@"volatile" or b_elem.@"volatile";
            // TODO restrict?
        }

        if (!adjusted_elem_qt.eqlQualified(a_elem, p.comp)) {
            a.qt = try p.comp.type_store.put(gpa, .{ .pointer = .{
                .child = adjusted_elem_qt,
                .decayed = null,
            } });
            try a.implicitCast(p, .bitcast, tok);
        }
        if (!adjusted_elem_qt.eqlQualified(b_elem, p.comp)) {
            b.qt = try p.comp.type_store.put(gpa, .{ .pointer = .{
                .child = adjusted_elem_qt,
                .decayed = null,
            } });
            try b.implicitCast(p, .bitcast, tok);
        }

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
        if (b.qt.isInvalid()) {
            try a.saveValue(p);
            a.qt = .invalid;
        }
        if (a.qt.isInvalid()) {
            return false;
        }
        try a.lvalConversion(p, tok);
        try b.lvalConversion(p, tok);

        const a_vec = a.qt.is(p.comp, .vector);
        const b_vec = b.qt.is(p.comp, .vector);
        if (a_vec and b_vec) {
            if (kind == .boolean_logic) {
                return a.invalidBinTy(tok, b, p);
            }
            if (a.qt.eql(b.qt, p.comp)) {
                return a.shouldEval(b, p);
            }
            if (a.qt.sizeCompare(b.qt, p.comp) == .eq) {
                b.qt = a.qt;
                try b.implicitCast(p, .bitcast, tok);
                return a.shouldEval(b, p);
            }
            try p.err(tok, .incompatible_vec_types, .{ a.qt, b.qt });
            a.val = .{};
            b.val = .{};
            a.qt = .invalid;
            return false;
        } else if (a_vec) {
            if (b.coerceExtra(p, a.qt.childType(p.comp), tok, .test_coerce)) {
                try b.saveValue(p);
                b.qt = a.qt;
                try b.implicitCast(p, .vector_splat, tok);
                return a.shouldEval(b, p);
            } else |er| switch (er) {
                error.CoercionFailed => return a.invalidBinTy(tok, b, p),
                else => |e| return e,
            }
        } else if (b_vec) {
            if (a.coerceExtra(p, b.qt.childType(p.comp), tok, .test_coerce)) {
                try a.saveValue(p);
                a.qt = b.qt;
                try a.implicitCast(p, .vector_splat, tok);
                return a.shouldEval(b, p);
            } else |er| switch (er) {
                error.CoercionFailed => return a.invalidBinTy(tok, b, p),
                else => |e| return e,
            }
        }

        const a_sk = a.qt.scalarKind(p.comp);
        const b_sk = b.qt.scalarKind(p.comp);

        if (a_sk.isInt() and b_sk.isInt()) {
            try a.usualArithmeticConversion(b, p, tok);
            return a.shouldEval(b, p);
        }
        if (kind == .integer) return a.invalidBinTy(tok, b, p);

        if (a_sk.isArithmetic() and b_sk.isArithmetic()) {
            // <, <=, >, >= only work on real types
            if (kind == .relational and (!a_sk.isReal() or !b_sk.isReal()))
                return a.invalidBinTy(tok, b, p);

            try a.usualArithmeticConversion(b, p, tok);
            return a.shouldEval(b, p);
        }
        if (kind == .arithmetic) return a.invalidBinTy(tok, b, p);

        switch (kind) {
            .boolean_logic => {
                if (!(a_sk != .none or a_sk == .nullptr_t) or
                    !(b_sk != .none or b_sk == .nullptr_t))
                {
                    return a.invalidBinTy(tok, b, p);
                }

                // Do integer promotions but nothing else
                if (a_sk.isInt()) try a.castToInt(p, a.qt.promoteInt(p.comp), tok);
                if (b_sk.isInt()) try b.castToInt(p, b.qt.promoteInt(p.comp), tok);
                return a.shouldEval(b, p);
            },
            .relational, .equality => {
                if (kind == .equality and (a_sk == .nullptr_t or b_sk == .nullptr_t)) {
                    if (a_sk == .nullptr_t and b_sk == .nullptr_t) return a.shouldEval(b, p);

                    const nullptr_res = if (a_sk == .nullptr_t) a else b;
                    const other_res = if (a_sk == .nullptr_t) b else a;

                    if (other_res.qt.isPointer(p.comp)) {
                        try nullptr_res.nullToPointer(p, other_res.qt, tok);
                        return other_res.shouldEval(nullptr_res, p);
                    } else if (other_res.val.isZero(p.comp)) {
                        other_res.val = .null;
                        try other_res.nullToPointer(p, nullptr_res.qt, tok);
                        return other_res.shouldEval(nullptr_res, p);
                    }
                    return a.invalidBinTy(tok, b, p);
                }

                // comparisons between floats and pointes not allowed
                if (a_sk == .none or b_sk == .none or (a_sk.isFloat() and b_sk.isPointer()) or (b_sk.isFloat() and a_sk.isPointer()))
                    return a.invalidBinTy(tok, b, p);
                if (a_sk == .nullptr_t or b_sk == .nullptr_t) return a.invalidBinTy(tok, b, p);

                if ((a_sk.isInt() or b_sk.isInt()) and !(a.val.isZero(p.comp) or b.val.isZero(p.comp))) {
                    try p.err(tok, .comparison_ptr_int, .{ a.qt, b.qt });
                } else if (a_sk.isPointer() and b_sk.isPointer()) {
                    if (a_sk != .void_pointer and b_sk != .void_pointer) {
                        const a_elem = a.qt.childType(p.comp);
                        const b_elem = b.qt.childType(p.comp);
                        if (!a_elem.eql(b_elem, p.comp)) {
                            try p.err(tok, .comparison_distinct_ptr, .{ a.qt, b.qt });
                            try b.castToPointer(p, a.qt, tok);
                        }
                    } else if (a_sk == .void_pointer) {
                        try b.castToPointer(p, a.qt, tok);
                    } else if (b_sk == .void_pointer) {
                        try a.castToPointer(p, b.qt, tok);
                    }
                } else if (a_sk.isPointer()) {
                    try b.castToPointer(p, a.qt, tok);
                } else {
                    assert(b_sk.isPointer());
                    try a.castToPointer(p, b.qt, tok);
                }

                return a.shouldEval(b, p);
            },
            .conditional => {
                // doesn't matter what we return here, as the result is ignored
                if (a.qt.is(p.comp, .void) or b.qt.is(p.comp, .void)) {
                    try a.castToVoid(p, tok);
                    try b.castToVoid(p, tok);
                    return true;
                }

                if (a_sk == .nullptr_t and b_sk == .nullptr_t) return true;

                if ((a_sk.isPointer() and b_sk.isInt()) or (a_sk.isInt() and b_sk.isPointer())) {
                    if (a.val.isZero(p.comp) or b.val.isZero(p.comp)) {
                        try a.nullToPointer(p, b.qt, tok);
                        try b.nullToPointer(p, a.qt, tok);
                        return true;
                    }
                    const int_ty = if (a_sk.isInt()) a else b;
                    const ptr_ty = if (a_sk.isPointer()) a else b;
                    try p.err(tok, .implicit_int_to_ptr, .{ int_ty.qt, ptr_ty.qt });
                    try int_ty.castToPointer(p, ptr_ty.qt, tok);

                    return true;
                }
                if ((a_sk.isPointer() and b_sk == .nullptr_t) or (a_sk == .nullptr_t and b_sk.isPointer())) {
                    const nullptr_res = if (a_sk == .nullptr_t) a else b;
                    const ptr_res = if (a_sk == .nullptr_t) b else a;
                    try nullptr_res.nullToPointer(p, ptr_res.qt, tok);
                    return true;
                }
                if (a_sk.isPointer() and b_sk.isPointer()) return a.adjustCondExprPtrs(tok, b, p);

                if (a.qt.getRecord(p.comp) != null and b.qt.getRecord(p.comp) != null and a.qt.eql(b.qt, p.comp)) {
                    return true;
                }
                return a.invalidBinTy(tok, b, p);
            },
            .add => {
                // if both aren't arithmetic one should be pointer and the other an integer
                if (a_sk.isPointer() == b_sk.isPointer() or a_sk.isInt() == b_sk.isInt()) return a.invalidBinTy(tok, b, p);

                if (a_sk == .void_pointer or b_sk == .void_pointer)
                    try p.err(tok, .gnu_pointer_arith, .{});

                if (a_sk == .nullptr_t) try a.nullToPointer(p, .void_pointer, tok);
                if (b_sk == .nullptr_t) try b.nullToPointer(p, .void_pointer, tok);

                // Do integer promotions but nothing else
                if (a_sk.isInt()) try a.castToInt(p, a.qt.promoteInt(p.comp), tok);
                if (b_sk.isInt()) try b.castToInt(p, b.qt.promoteInt(p.comp), tok);

                // The result type is the type of the pointer operand
                if (a_sk.isInt()) a.qt = b.qt else b.qt = a.qt;
                return a.shouldEval(b, p);
            },
            .sub => {
                // if both aren't arithmetic then either both should be pointers or just the left one.
                if (!a_sk.isPointer() or !(b_sk.isPointer() or b_sk.isInt())) return a.invalidBinTy(tok, b, p);

                if (a_sk == .void_pointer)
                    try p.err(tok, .gnu_pointer_arith, .{});

                if (a_sk == .nullptr_t) try a.nullToPointer(p, .void_pointer, tok);
                if (b_sk == .nullptr_t) try b.nullToPointer(p, .void_pointer, tok);

                if (a_sk.isPointer() and b_sk.isPointer()) {
                    const a_child_qt = a.qt.get(p.comp, .pointer).?.child;
                    const b_child_qt = b.qt.get(p.comp, .pointer).?.child;

                    if (!a_child_qt.eql(b_child_qt, p.comp)) try p.err(tok, .incompatible_pointers, .{ a.qt, b.qt });
                    if (a.qt.childType(p.comp).sizeofOrNull(p.comp) orelse 1 == 0) try p.err(tok, .subtract_pointers_zero_elem_size, .{a.qt.childType(p.comp)});
                    a.qt = p.comp.type_store.ptrdiff;
                }

                // Do integer promotion on b if needed
                if (b_sk.isInt()) try b.castToInt(p, b.qt.promoteInt(p.comp), tok);
                return a.shouldEval(b, p);
            },
            else => return a.invalidBinTy(tok, b, p),
        }
    }

    fn lvalConversion(res: *Result, p: *Parser, tok: TokenIndex) Error!void {
        if (res.qt.is(p.comp, .func)) {
            res.val = try p.pointerValue(res.node, .zero);

            res.qt = try res.qt.decay(p.comp);
            try res.implicitCast(p, .function_to_pointer, tok);
        } else if (res.qt.is(p.comp, .array)) {
            res.val = try p.pointerValue(res.node, .zero);

            res.qt = try res.qt.decay(p.comp);
            try res.implicitCast(p, .array_to_pointer, tok);
        } else if (!p.in_macro and p.tree.isLval(res.node)) {
            res.qt = res.qt.unqualified();
            try res.implicitCast(p, .lval_to_rval, tok);
        }
    }

    fn castToBool(res: *Result, p: *Parser, bool_qt: QualType, tok: TokenIndex) Error!void {
        if (res.qt.isInvalid()) return;
        std.debug.assert(!bool_qt.isInvalid());

        const src_sk = res.qt.scalarKind(p.comp);
        if (res.qt.is(p.comp, .array)) {
            if (res.val.is(.bytes, p.comp)) {
                try p.err(tok, .string_literal_to_bool, .{ res.qt, bool_qt });
            } else {
                try p.err(tok, .array_address_to_bool, .{p.tokSlice(tok)});
            }
            try res.lvalConversion(p, tok);
            res.val = .one;
            res.qt = bool_qt;
            try res.implicitCast(p, .pointer_to_bool, tok);
        } else if (src_sk.isPointer()) {
            res.val.boolCast(p.comp);
            res.qt = bool_qt;
            try res.implicitCast(p, .pointer_to_bool, tok);
        } else if (src_sk.isInt() and src_sk != .bool) {
            res.val.boolCast(p.comp);
            if (!src_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_int_to_real, tok);
            }
            res.qt = bool_qt;
            try res.implicitCast(p, .int_to_bool, tok);
        } else if (src_sk.isFloat()) {
            const old_val = res.val;
            const value_change_kind = try res.val.floatToInt(bool_qt, p.comp);
            try res.floatToIntWarning(p, bool_qt, old_val, value_change_kind, tok);
            if (!src_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_float_to_real, tok);
            }
            res.qt = bool_qt;
            try res.implicitCast(p, .float_to_bool, tok);
        }
    }

    fn castToInt(res: *Result, p: *Parser, int_qt: QualType, tok: TokenIndex) Error!void {
        if (res.qt.isInvalid()) return;
        std.debug.assert(!int_qt.isInvalid());
        if (int_qt.hasIncompleteSize(p.comp)) {
            return error.ParsingFailed; // Cast to incomplete enum, diagnostic already issued
        }

        const src_sk = res.qt.scalarKind(p.comp);
        const dest_sk = int_qt.scalarKind(p.comp);

        if (src_sk == .bool) {
            res.qt = int_qt.toReal(p.comp);
            try res.implicitCast(p, .bool_to_int, tok);
            if (!dest_sk.isReal()) {
                res.qt = int_qt;
                try res.implicitCast(p, .real_to_complex_int, tok);
            }
        } else if (src_sk.isPointer()) {
            res.val = .{};
            res.qt = int_qt.toReal(p.comp);
            try res.implicitCast(p, .pointer_to_int, tok);
            if (!dest_sk.isReal()) {
                res.qt = int_qt;
                try res.implicitCast(p, .real_to_complex_int, tok);
            }
        } else if (res.qt.isFloat(p.comp)) {
            const old_val = res.val;
            const value_change_kind = try res.val.floatToInt(int_qt, p.comp);
            try res.floatToIntWarning(p, int_qt, old_val, value_change_kind, tok);
            if (src_sk.isReal() and dest_sk.isReal()) {
                res.qt = int_qt;
                try res.implicitCast(p, .float_to_int, tok);
            } else if (src_sk.isReal()) {
                res.qt = int_qt.toReal(p.comp);
                try res.implicitCast(p, .float_to_int, tok);
                res.qt = int_qt;
                try res.implicitCast(p, .real_to_complex_int, tok);
            } else if (dest_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_float_to_real, tok);
                res.qt = int_qt;
                try res.implicitCast(p, .float_to_int, tok);
            } else {
                res.qt = int_qt;
                try res.implicitCast(p, .complex_float_to_complex_int, tok);
            }
        } else if (!res.qt.eql(int_qt, p.comp)) {
            const old_val = res.val;
            const value_change_kind = try res.val.intCast(int_qt, p.comp);
            switch (value_change_kind) {
                .none => {},
                .truncated => try p.errValueChanged(tok, .int_value_changed, res.*, old_val, int_qt),
                .sign_changed => try p.err(tok, .sign_conversion, .{ res.qt, int_qt }),
            }

            if (src_sk.isReal() and dest_sk.isReal()) {
                res.qt = int_qt;
                try res.implicitCast(p, .int_cast, tok);
            } else if (src_sk.isReal()) {
                const real_int_qt = int_qt.toReal(p.comp);
                if (!res.qt.eql(real_int_qt, p.comp)) {
                    res.qt = real_int_qt;
                    try res.implicitCast(p, .int_cast, tok);
                }
                res.qt = int_qt;
                try res.implicitCast(p, .real_to_complex_int, tok);
            } else if (dest_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_int_to_real, tok);
                res.qt = int_qt;
                try res.implicitCast(p, .int_cast, tok);
            } else {
                res.qt = int_qt;
                try res.implicitCast(p, .complex_int_cast, tok);
            }
        }
    }

    fn floatToIntWarning(
        res: Result,
        p: *Parser,
        int_qt: QualType,
        old_val: Value,
        change_kind: Value.FloatToIntChangeKind,
        tok: TokenIndex,
    ) !void {
        switch (change_kind) {
            .none => return p.err(tok, .float_to_int, .{ res.qt, int_qt }),
            .out_of_range => return p.err(tok, .float_out_of_range, .{ res.qt, int_qt }),
            .overflow => return p.err(tok, .float_overflow_conversion, .{ res.qt, int_qt }),
            .nonzero_to_zero => return p.errValueChanged(tok, .float_zero_conversion, res, old_val, int_qt),
            .value_changed => return p.errValueChanged(tok, .float_value_changed, res, old_val, int_qt),
        }
    }

    fn castToFloat(res: *Result, p: *Parser, float_qt: QualType, tok: TokenIndex) Error!void {
        const src_sk = res.qt.scalarKind(p.comp);
        const dest_sk = float_qt.scalarKind(p.comp);

        if (src_sk == .bool) {
            try res.val.intToFloat(float_qt, p.comp);
            res.qt = float_qt.toReal(p.comp);
            try res.implicitCast(p, .bool_to_float, tok);
            if (!dest_sk.isReal()) {
                res.qt = float_qt;
                try res.implicitCast(p, .real_to_complex_float, tok);
            }
        } else if (src_sk.isInt()) {
            try res.val.intToFloat(float_qt, p.comp);
            if (src_sk.isReal() and dest_sk.isReal()) {
                res.qt = float_qt;
                try res.implicitCast(p, .int_to_float, tok);
            } else if (src_sk.isReal()) {
                res.qt = float_qt.toReal(p.comp);
                try res.implicitCast(p, .int_to_float, tok);
                res.qt = float_qt;
                try res.implicitCast(p, .real_to_complex_float, tok);
            } else if (dest_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_int_to_real, tok);
                res.qt = float_qt;
                try res.implicitCast(p, .int_to_float, tok);
            } else {
                res.qt = float_qt;
                try res.implicitCast(p, .complex_int_to_complex_float, tok);
            }
        } else if (!res.qt.eql(float_qt, p.comp)) {
            try res.val.floatCast(float_qt, p.comp);
            if (src_sk.isReal() and dest_sk.isReal()) {
                res.qt = float_qt;
                try res.implicitCast(p, .float_cast, tok);
            } else if (src_sk.isReal()) {
                if (res.qt.floatRank(p.comp) != float_qt.floatRank(p.comp)) {
                    res.qt = float_qt.toReal(p.comp);
                    try res.implicitCast(p, .float_cast, tok);
                }
                res.qt = float_qt;
                try res.implicitCast(p, .real_to_complex_float, tok);
            } else if (dest_sk.isReal()) {
                res.qt = res.qt.toReal(p.comp);
                try res.implicitCast(p, .complex_float_to_real, tok);
                if (res.qt.floatRank(p.comp) != float_qt.floatRank(p.comp)) {
                    res.qt = float_qt;
                    try res.implicitCast(p, .float_cast, tok);
                }
            } else {
                res.qt = float_qt;
                try res.implicitCast(p, .complex_float_cast, tok);
            }
        }
    }

    /// Converts a bool or integer to a pointer
    fn castToPointer(res: *Result, p: *Parser, ptr_qt: QualType, tok: TokenIndex) Error!void {
        const src_sk = res.qt.scalarKind(p.comp);
        if (src_sk == .bool) {
            res.qt = ptr_qt;
            try res.implicitCast(p, .bool_to_pointer, tok);
        } else if (src_sk.isInt()) {
            _ = try res.val.intCast(ptr_qt, p.comp);
            res.qt = ptr_qt;
            try res.implicitCast(p, .int_to_pointer, tok);
        } else if (src_sk == .nullptr_t) {
            try res.nullToPointer(p, ptr_qt, tok);
        } else if (src_sk.isPointer() and !res.qt.eql(ptr_qt, p.comp)) {
            if (ptr_qt.is(p.comp, .nullptr_t)) {
                res.qt = .invalid;
                return;
            }

            const src_elem = res.qt.childType(p.comp);
            const dest_elem = ptr_qt.childType(p.comp);
            res.qt = ptr_qt;

            if (dest_elem.eql(src_elem, p.comp) and
                (dest_elem.@"const" == src_elem.@"const" or dest_elem.@"const") and
                (dest_elem.@"volatile" == src_elem.@"volatile" or dest_elem.@"volatile"))
            {
                // Gaining qualifiers is a no-op.
                try res.implicitCast(p, .no_op, tok);
            } else {
                try res.implicitCast(p, .bitcast, tok);
            }
        }
    }

    fn castToVoid(res: *Result, p: *Parser, tok: TokenIndex) Error!void {
        if (!res.qt.is(p.comp, .void)) {
            res.qt = .void;
            try res.implicitCast(p, .to_void, tok);
        }
    }

    fn nullToPointer(res: *Result, p: *Parser, ptr_ty: QualType, tok: TokenIndex) Error!void {
        if (!res.qt.is(p.comp, .nullptr_t) and !res.val.isZero(p.comp)) return;
        res.val = .null;
        res.qt = ptr_ty;
        try res.implicitCast(p, .null_to_pointer, tok);
    }

    fn usualUnaryConversion(res: *Result, p: *Parser, tok: TokenIndex) Error!void {
        if (res.qt.isInvalid()) return;
        if (res.qt.isFloat(p.comp)) fp_eval: {
            const eval_method = p.comp.langopts.fp_eval_method orelse break :fp_eval;
            switch (eval_method) {
                .source => {},
                .indeterminate => unreachable,
                .double => {
                    if (res.qt.floatRank(p.comp) < QualType.double.floatRank(p.comp)) {
                        var res_qt: QualType = .double;
                        if (res.qt.is(p.comp, .complex)) res_qt = try res_qt.toComplex(p.comp);
                        return res.castToFloat(p, res_qt, tok);
                    }
                },
                .extended => {
                    if (res.qt.floatRank(p.comp) < QualType.long_double.floatRank(p.comp)) {
                        var res_qt: QualType = .long_double;
                        if (res.qt.is(p.comp, .complex)) res_qt = try res_qt.toComplex(p.comp);
                        return res.castToFloat(p, res_qt, tok);
                    }
                },
            }
        }

        if (!p.comp.langopts.use_native_half_type) {
            if (res.qt.get(p.comp, .float)) |float_ty| {
                if (float_ty == .fp16) {
                    return res.castToFloat(p, .float, tok);
                }
            }
        }

        if (res.qt.isInt(p.comp) and !p.in_macro) {
            if (p.tree.bitfieldWidth(res.node, true)) |width| {
                if (res.qt.promoteBitfield(p.comp, width)) |promotion_ty| {
                    return res.castToInt(p, promotion_ty, tok);
                }
            }
            return res.castToInt(p, res.qt.promoteInt(p.comp), tok);
        }
    }

    fn usualArithmeticConversion(a: *Result, b: *Result, p: *Parser, tok: TokenIndex) Error!void {
        try a.usualUnaryConversion(p, tok);
        try b.usualUnaryConversion(p, tok);

        // if either is a float cast to that type
        const a_float = a.qt.isFloat(p.comp);
        const b_float = b.qt.isFloat(p.comp);
        if (a_float and b_float) {
            const a_complex = a.qt.is(p.comp, .complex);
            const b_complex = b.qt.is(p.comp, .complex);
            const a_rank = a.qt.floatRank(p.comp);
            const b_rank = b.qt.floatRank(p.comp);
            if ((a_rank >= QualType.decimal_float_rank) != (b_rank >= QualType.decimal_float_rank)) {
                try p.err(tok, .mixing_decimal_floats, .{});
                return;
            }

            const res_qt = if (a_rank > b_rank)
                (if (!a_complex and b_complex)
                    try a.qt.toComplex(p.comp)
                else
                    a.qt)
            else
                (if (!b_complex and a_complex)
                    try b.qt.toComplex(p.comp)
                else
                    b.qt);

            try a.castToFloat(p, res_qt, tok);
            try b.castToFloat(p, res_qt, tok);
            return;
        } else if (a_float) {
            try b.castToFloat(p, a.qt, tok);
            return;
        } else if (b_float) {
            try a.castToFloat(p, b.qt, tok);
            return;
        }

        if (a.qt.eql(b.qt, p.comp)) {
            // cast to promoted type
            try a.castToInt(p, a.qt, tok);
            try b.castToInt(p, b.qt, tok);
            return;
        }

        const a_real = a.qt.toReal(p.comp);
        const b_real = b.qt.toReal(p.comp);

        const type_order = a.qt.intRankOrder(b.qt, p.comp);
        const a_signed = a.qt.signedness(p.comp) == .signed;
        const b_signed = b.qt.signedness(p.comp) == .signed;

        var target_qt: QualType = .invalid;
        if (a_signed == b_signed) {
            // If both have the same sign, use higher-rank type.
            target_qt = switch (type_order) {
                .lt => b.qt,
                .eq, .gt => a_real,
            };
        } else if (type_order != if (a_signed) std.math.Order.gt else std.math.Order.lt) {
            // Only one is signed; and the unsigned type has rank >= the signed type
            // Use the unsigned type
            target_qt = if (b_signed) a_real else b_real;
        } else if (a_real.bitSizeof(p.comp) != b_real.bitSizeof(p.comp)) {
            // Signed type is higher rank and sizes are not equal
            // Use the signed type
            target_qt = if (a_signed) a_real else b_real;
        } else {
            // Signed type is higher rank but same size as unsigned type
            // e.g. `long` and `unsigned` on x86-linux-gnu
            // Use unsigned version of the signed type
            target_qt = if (a_signed) try a_real.makeIntUnsigned(p.comp) else try b_real.makeIntUnsigned(p.comp);
        }

        if (a.qt.is(p.comp, .complex) or b.qt.is(p.comp, .complex)) {
            target_qt = try target_qt.toComplex(p.comp);
        }

        if (target_qt.is(p.comp, .complex)) {
            // TODO implement complex int values
            try a.saveValue(p);
            try b.saveValue(p);
        }
        try a.castToInt(p, target_qt, tok);
        try b.castToInt(p, target_qt, tok);
    }

    fn invalidBinTy(a: *Result, tok: TokenIndex, b: *Result, p: *Parser) Error!bool {
        try p.err(tok, .invalid_bin_types, .{ a.qt, b.qt });
        a.val = .{};
        b.val = .{};
        a.qt = .invalid;
        return false;
    }

    fn shouldEval(a: *Result, b: *Result, p: *Parser) Error!bool {
        if (p.no_eval) return false;
        if (a.val.opt_ref != .none and b.val.opt_ref != .none)
            return true;

        try a.saveValue(p);
        try b.saveValue(p);
        return p.no_eval;
    }

    /// Saves value and replaces it with `.unavailable`.
    fn saveValue(res: *Result, p: *Parser) !void {
        assert(!p.in_macro);
        try res.putValue(p);
        res.val = .{};
    }

    /// Saves value without altering the result.
    fn putValue(res: *const Result, p: *Parser) !void {
        if (res.val.opt_ref == .none or res.val.opt_ref == .null) return;
        if (!p.in_macro) try p.tree.value_map.put(p.comp.gpa, res.node, res.val);
    }

    fn castType(res: *Result, p: *Parser, dest_qt: QualType, operand_tok: TokenIndex, l_paren: TokenIndex) !void {
        if (res.qt.isInvalid()) {
            res.val = .{};
            return;
        } else if (dest_qt.isInvalid()) {
            res.val = .{};
            res.qt = .invalid;
            return;
        }
        var cast_kind: Node.Cast.Kind = undefined;

        const dest_sk = dest_qt.scalarKind(p.comp);
        const src_sk = res.qt.scalarKind(p.comp);

        const dest_vec = dest_qt.is(p.comp, .vector);
        const src_vec = res.qt.is(p.comp, .vector);

        if (dest_qt.is(p.comp, .void)) {
            // everything can cast to void
            cast_kind = .to_void;
            res.val = .{};
        } else if (res.qt.is(p.comp, .void)) {
            try p.err(operand_tok, .invalid_cast_operand_type, .{res.qt});
            return error.ParsingFailed;
        } else if (dest_vec and src_vec) {
            if (dest_qt.eql(res.qt, p.comp)) {
                cast_kind = .no_op;
            } else if (dest_qt.sizeCompare(res.qt, p.comp) == .eq) {
                cast_kind = .bitcast;
            } else {
                try p.err(l_paren, .invalid_vec_conversion, .{ dest_qt, res.qt });
                return error.ParsingFailed;
            }
        } else if (dest_vec or src_vec) {
            const non_vec_sk = if (dest_vec) src_sk else dest_sk;
            const vec_qt = if (dest_vec) dest_qt else res.qt;
            const non_vec_qt = if (dest_vec) res.qt else dest_qt;
            const non_vec_tok = if (dest_vec) operand_tok else l_paren;
            if (non_vec_sk == .none) {
                try p.err(non_vec_tok, .invalid_cast_operand_type, .{non_vec_qt});
                return error.ParsingFailed;
            } else if (!non_vec_sk.isInt()) {
                try p.err(non_vec_tok, .invalid_vec_conversion_scalar, .{ vec_qt, non_vec_qt });
                return error.ParsingFailed;
            } else if (dest_qt.sizeCompare(res.qt, p.comp) != .eq) {
                try p.err(non_vec_tok, .invalid_vec_conversion_int, .{ vec_qt, non_vec_qt });
                return error.ParsingFailed;
            } else {
                cast_kind = .bitcast;
            }
        } else if (dest_sk == .nullptr_t) {
            res.val = .{};
            if (src_sk == .nullptr_t) {
                cast_kind = .no_op;
            } else {
                try p.err(l_paren, .invalid_object_cast, .{ res.qt, dest_qt });
                return error.ParsingFailed;
            }
        } else if (src_sk == .nullptr_t) {
            if (dest_sk == .bool) {
                try res.nullToPointer(p, res.qt, l_paren);
                res.val.boolCast(p.comp);
                res.qt = .bool;
                try res.implicitCast(p, .pointer_to_bool, l_paren);
                try res.saveValue(p);
            } else if (dest_sk.isPointer()) {
                try res.nullToPointer(p, dest_qt, l_paren);
            } else {
                try p.err(l_paren, .invalid_object_cast, .{ res.qt, dest_qt });
                return error.ParsingFailed;
            }
            cast_kind = .no_op;
        } else if (res.val.isZero(p.comp) and dest_sk.isPointer()) {
            cast_kind = .null_to_pointer;
        } else if (dest_sk != .none) cast: {
            if (dest_sk.isFloat() and src_sk.isPointer()) {
                try p.err(l_paren, .invalid_cast_to_float, .{dest_qt});
                return error.ParsingFailed;
            } else if ((src_sk.isFloat() or !src_sk.isReal()) and dest_sk.isPointer()) {
                try p.err(l_paren, .invalid_cast_to_pointer, .{res.qt});
                return error.ParsingFailed;
            }

            if (dest_qt.eql(res.qt, p.comp)) {
                cast_kind = .no_op;
            } else if (dest_sk == .bool) {
                if (src_sk.isPointer()) {
                    cast_kind = .pointer_to_bool;
                } else if (src_sk.isInt()) {
                    if (!src_sk.isReal()) {
                        res.qt = res.qt.toReal(p.comp);
                        try res.implicitCast(p, .complex_int_to_real, l_paren);
                    }
                    cast_kind = .int_to_bool;
                } else if (src_sk.isFloat()) {
                    if (!src_sk.isReal()) {
                        res.qt = res.qt.toReal(p.comp);
                        try res.implicitCast(p, .complex_float_to_real, l_paren);
                    }
                    cast_kind = .float_to_bool;
                }
            } else if (dest_sk.isInt()) {
                if (src_sk == .bool) {
                    if (!dest_sk.isReal()) {
                        res.qt = dest_qt.toReal(p.comp);
                        try res.implicitCast(p, .bool_to_int, l_paren);
                        cast_kind = .real_to_complex_int;
                    } else {
                        cast_kind = .bool_to_int;
                    }
                } else if (src_sk.isInt()) {
                    if (src_sk.isReal() and dest_sk.isReal()) {
                        cast_kind = .int_cast;
                    } else if (src_sk.isReal()) {
                        res.qt = dest_qt.toReal(p.comp);
                        try res.implicitCast(p, .int_cast, l_paren);
                        cast_kind = .real_to_complex_int;
                    } else if (dest_sk.isReal()) {
                        res.qt = res.qt.toReal(p.comp);
                        try res.implicitCast(p, .complex_int_to_real, l_paren);
                        cast_kind = .int_cast;
                    } else {
                        cast_kind = .complex_int_cast;
                    }
                } else if (src_sk.isPointer()) {
                    res.val = .{};
                    if (!dest_sk.isReal()) {
                        res.qt = dest_qt.toReal(p.comp);
                        try res.implicitCast(p, .pointer_to_int, l_paren);
                        cast_kind = .real_to_complex_int;
                    } else {
                        cast_kind = .pointer_to_int;
                    }
                } else if (src_sk.isReal() and dest_sk.isReal()) {
                    cast_kind = .float_to_int;
                } else if (src_sk.isReal()) {
                    res.qt = dest_qt.toReal(p.comp);
                    try res.implicitCast(p, .float_to_int, l_paren);
                    cast_kind = .real_to_complex_int;
                } else if (dest_sk.isReal()) {
                    res.qt = res.qt.toReal(p.comp);
                    try res.implicitCast(p, .complex_float_to_real, l_paren);
                    cast_kind = .float_to_int;
                } else {
                    cast_kind = .complex_float_to_complex_int;
                }
            } else if (dest_sk.isPointer()) {
                if (src_sk.isPointer()) {
                    cast_kind = .bitcast;
                } else if (src_sk.isInt()) {
                    if (!src_sk.isReal()) {
                        res.qt = res.qt.toReal(p.comp);
                        try res.implicitCast(p, .complex_int_to_real, l_paren);
                    }
                    cast_kind = .int_to_pointer;
                } else if (src_sk == .bool) {
                    cast_kind = .bool_to_pointer;
                } else if (res.qt.is(p.comp, .array)) {
                    cast_kind = .array_to_pointer;
                } else if (res.qt.is(p.comp, .func)) {
                    cast_kind = .function_to_pointer;
                } else {
                    try p.err(operand_tok, .invalid_cast_operand_type, .{res.qt});
                    return error.ParsingFailed;
                }
            } else if (dest_sk.isFloat()) {
                if (src_sk == .bool) {
                    if (!dest_sk.isReal()) {
                        res.qt = dest_qt.toReal(p.comp);
                        try res.implicitCast(p, .bool_to_float, l_paren);
                        cast_kind = .real_to_complex_float;
                    } else {
                        cast_kind = .bool_to_float;
                    }
                } else if (src_sk.isInt()) {
                    if (src_sk.isReal() and dest_sk.isReal()) {
                        cast_kind = .int_to_float;
                    } else if (src_sk.isReal()) {
                        res.qt = dest_qt.toReal(p.comp);
                        try res.implicitCast(p, .int_to_float, l_paren);
                        cast_kind = .real_to_complex_float;
                    } else if (dest_sk.isReal()) {
                        res.qt = res.qt.toReal(p.comp);
                        try res.implicitCast(p, .complex_int_to_real, l_paren);
                        cast_kind = .int_to_float;
                    } else {
                        cast_kind = .complex_int_to_complex_float;
                    }
                } else if (src_sk.isReal() and dest_sk.isReal()) {
                    cast_kind = .float_cast;
                } else if (src_sk.isReal()) {
                    res.qt = dest_qt.toReal(p.comp);
                    try res.implicitCast(p, .float_cast, l_paren);
                    cast_kind = .real_to_complex_float;
                } else if (dest_sk.isReal()) {
                    res.qt = res.qt.toReal(p.comp);
                    try res.implicitCast(p, .complex_float_to_real, l_paren);
                    cast_kind = .float_cast;
                } else {
                    cast_kind = .complex_float_cast;
                }
            }
            if (res.val.opt_ref == .none) break :cast;

            const src_int = src_sk.isInt() or src_sk.isPointer();
            const dest_int = dest_sk.isInt() or dest_sk.isPointer();
            if (dest_sk == .bool) {
                res.val.boolCast(p.comp);
            } else if (src_sk.isFloat() and dest_int) {
                if (dest_qt.hasIncompleteSize(p.comp)) {
                    try p.err(l_paren, .cast_to_incomplete_type, .{dest_qt});
                    return error.ParsingFailed;
                }
                // Explicit cast, no conversion warning
                _ = try res.val.floatToInt(dest_qt, p.comp);
            } else if (dest_sk.isFloat() and src_int) {
                try res.val.intToFloat(dest_qt, p.comp);
            } else if (dest_sk.isFloat() and src_sk.isFloat()) {
                try res.val.floatCast(dest_qt, p.comp);
            } else if (src_int and dest_int) {
                if (dest_qt.hasIncompleteSize(p.comp)) {
                    try p.err(l_paren, .cast_to_incomplete_type, .{dest_qt});
                    return error.ParsingFailed;
                }
                _ = try res.val.intCast(dest_qt, p.comp);
            }
        } else if (dest_qt.get(p.comp, .@"union")) |union_ty| {
            if (union_ty.layout == null) {
                try p.err(l_paren, .cast_to_incomplete_type, .{dest_qt});
                return error.ParsingFailed;
            }

            for (union_ty.fields) |field| {
                if (field.qt.eql(res.qt, p.comp)) {
                    cast_kind = .union_cast;
                    try p.err(l_paren, .gnu_union_cast, .{});
                    break;
                }
            } else {
                try p.err(l_paren, .invalid_union_cast, .{res.qt});
                return error.ParsingFailed;
            }
        } else if (dest_qt.eql(res.qt, p.comp)) {
            try p.err(l_paren, .cast_to_same_type, .{dest_qt});
            cast_kind = .no_op;
        } else {
            try p.err(l_paren, .invalid_cast_type, .{dest_qt});
            return error.ParsingFailed;
        }

        if (dest_qt.isQualified()) try p.err(l_paren, .qual_cast, .{dest_qt});
        if (dest_sk.isInt() and src_sk.isPointer() and dest_qt.sizeCompare(res.qt, p.comp) == .lt) {
            try p.err(l_paren, .cast_to_smaller_int, .{ dest_qt, res.qt });
        }

        res.qt = dest_qt.unqualified();
        res.node = try p.addNode(.{
            .cast = .{
                .l_paren = l_paren,
                .qt = res.qt,
                .operand = res.node,
                .kind = cast_kind,
                .implicit = false,
            },
        });
    }

    fn intFitsInType(res: Result, p: *Parser, ty: QualType) !bool {
        const max_int = try Value.maxInt(ty, p.comp);
        const min_int = try Value.minInt(ty, p.comp);
        return res.val.compare(.lte, max_int, p.comp) and
            (res.qt.signedness(p.comp) == .unsigned or res.val.compare(.gte, min_int, p.comp));
    }

    const CoerceContext = union(enum) {
        assign,
        init,
        ret,
        arg: ?TokenIndex,
        test_coerce,

        fn note(c: CoerceContext, p: *Parser) !void {
            switch (c) {
                .arg => |opt_tok| if (opt_tok) |tok| try p.err(tok, .parameter_here, .{}),
                .test_coerce => unreachable,
                else => {},
            }
        }
    };

    /// Perform assignment-like coercion to `dest_ty`.
    fn coerce(res: *Result, p: *Parser, dest_ty: QualType, tok: TokenIndex, c: CoerceContext) Error!void {
        if (dest_ty.isInvalid()) {
            res.qt = .invalid;
            return;
        }
        return res.coerceExtra(p, dest_ty, tok, c) catch |er| switch (er) {
            error.CoercionFailed => unreachable,
            else => |e| return e,
        };
    }

    fn coerceExtra(
        res: *Result,
        p: *Parser,
        dest_qt: QualType,
        tok: TokenIndex,
        c: CoerceContext,
    ) (Error || error{CoercionFailed})!void {
        // Subject of the coercion does not need to be qualified.
        const src_original_qt = res.qt;
        switch (c) {
            .init, .ret, .assign => try res.lvalConversion(p, tok),
            else => {},
        }
        if (res.qt.isInvalid()) return;
        const dest_unqual = dest_qt.unqualified();
        const dest_sk = dest_unqual.scalarKind(p.comp);
        const src_sk = res.qt.scalarKind(p.comp);

        if (dest_qt.is(p.comp, .vector) and res.qt.is(p.comp, .vector)) {
            if (dest_unqual.eql(res.qt, p.comp)) return;
            if (dest_unqual.sizeCompare(res.qt, p.comp) == .eq) {
                res.qt = dest_unqual;
                return res.implicitCast(p, .bitcast, tok);
            }
        } else if (dest_sk == .nullptr_t) {
            if (src_sk == .nullptr_t) return;
        } else if (dest_sk == .bool) {
            if (src_sk != .none and src_sk != .nullptr_t) {
                // this is ridiculous but it's what clang does
                try res.castToBool(p, dest_unqual, tok);
                return;
            }
        } else if (dest_sk.isInt()) {
            if (src_sk.isInt() or src_sk.isFloat()) {
                try res.castToInt(p, dest_unqual, tok);
                return;
            } else if (src_sk.isPointer()) {
                if (c == .test_coerce) return error.CoercionFailed;
                try p.err(tok, .implicit_ptr_to_int, .{ src_original_qt, dest_unqual });
                try c.note(p);
                try res.castToInt(p, dest_unqual, tok);
                return;
            }
        } else if (dest_sk.isFloat()) {
            if (src_sk.isInt() or src_sk.isFloat()) {
                try res.castToFloat(p, dest_unqual, tok);
                return;
            }
        } else if (dest_sk.isPointer()) {
            if (src_sk == .nullptr_t or res.val.isZero(p.comp)) {
                try res.nullToPointer(p, dest_unqual, tok);
                return;
            } else if (src_sk.isInt() and src_sk.isReal()) {
                if (c == .test_coerce) return error.CoercionFailed;
                try p.err(tok, .implicit_int_to_ptr, .{ src_original_qt, dest_unqual });
                try c.note(p);
                try res.castToPointer(p, dest_unqual, tok);
                return;
            } else if (src_sk == .void_pointer or dest_unqual.eql(res.qt, p.comp)) {
                return res.castToPointer(p, dest_unqual, tok);
            } else if (dest_sk == .void_pointer and src_sk.isPointer()) {
                return res.castToPointer(p, dest_unqual, tok);
            } else if (src_sk.isPointer()) {
                const src_child = res.qt.childType(p.comp);
                const dest_child = dest_unqual.childType(p.comp);
                if (src_child.eql(dest_child, p.comp)) {
                    if ((src_child.@"const" and !dest_child.@"const") or
                        (src_child.@"volatile" and !dest_child.@"volatile") or
                        (src_child.restrict and !dest_child.restrict))
                    {
                        try p.err(tok, switch (c) {
                            .assign => .ptr_assign_discards_quals,
                            .init => .ptr_init_discards_quals,
                            .ret => .ptr_ret_discards_quals,
                            .arg => .ptr_arg_discards_quals,
                            .test_coerce => return error.CoercionFailed,
                        }, .{ dest_qt, src_original_qt });
                    }
                    try res.castToPointer(p, dest_unqual, tok);
                    return;
                }

                const different_sign_only = src_child.sameRankDifferentSign(dest_child, p.comp);
                switch (c) {
                    .assign => try p.err(tok, if (different_sign_only) .incompatible_ptr_assign_sign else .incompatible_ptr_assign, .{ dest_qt, src_original_qt }),
                    .init => try p.err(tok, if (different_sign_only) .incompatible_ptr_init_sign else .incompatible_ptr_init, .{ dest_qt, src_original_qt }),
                    .ret => try p.err(tok, if (different_sign_only) .incompatible_return_sign else .incompatible_return, .{ src_original_qt, dest_qt }),
                    .arg => try p.err(tok, if (different_sign_only) .incompatible_ptr_arg_sign else .incompatible_ptr_arg, .{ src_original_qt, dest_qt }),
                    .test_coerce => return error.CoercionFailed,
                }
                try c.note(p);

                res.qt = dest_unqual;
                return res.implicitCast(p, .bitcast, tok);
            }
        } else if (dest_unqual.getRecord(p.comp) != null) {
            if (dest_unqual.eql(res.qt, p.comp)) {
                return; // ok
            }

            if (c == .arg) if (dest_unqual.get(p.comp, .@"union")) |union_ty| {
                if (dest_unqual.hasAttribute(p.comp, .transparent_union)) transparent_union: {
                    res.coerceExtra(p, union_ty.fields[0].qt, tok, .test_coerce) catch |er| switch (er) {
                        error.CoercionFailed => break :transparent_union,
                        else => |e| return e,
                    };
                    res.node = try p.addNode(.{ .union_init_expr = .{
                        .field_index = 0,
                        .initializer = res.node,
                        .l_brace_tok = tok,
                        .union_qt = dest_unqual,
                    } });
                    res.qt = dest_unqual;
                    return;
                }
            };
        } else if (dest_unqual.is(p.comp, .vector)) {
            if (dest_unqual.eql(res.qt, p.comp)) {
                return; // ok
            }
        } else {
            if (c == .assign) {
                const base_type = dest_unqual.base(p.comp);
                switch (base_type.type) {
                    .array => return p.err(tok, .array_not_assignable, .{base_type.qt}),
                    .func => return p.err(tok, .non_object_not_assignable, .{base_type.qt}),
                    else => {},
                }
            } else if (c == .test_coerce) {
                return error.CoercionFailed;
            }
            // This case should not be possible and an error should have already been emitted but we
            // might still have attempted to parse further so return error.ParsingFailed here to stop.
            return error.ParsingFailed;
        }

        switch (c) {
            .assign => try p.err(tok, .incompatible_assign, .{ dest_unqual, res.qt }),
            .init => try p.err(tok, .incompatible_init, .{ dest_unqual, res.qt }),
            .ret => try p.err(tok, .incompatible_return, .{ res.qt, dest_unqual }),
            .arg => try p.err(tok, .incompatible_arg, .{ res.qt, dest_unqual }),
            .test_coerce => return error.CoercionFailed,
        }
        try c.note(p);
    }
};

fn expect(p: *Parser, comptime func: fn (*Parser) Error!?Result) Error!Result {
    return p.expectResult(try func(p));
}

fn expectResult(p: *Parser, res: ?Result) Error!Result {
    return res orelse {
        try p.err(p.tok_i, .expected_expr, .{});
        return error.ParsingFailed;
    };
}

/// expr : assignExpr (',' assignExpr)*
fn expr(p: *Parser) Error!?Result {
    var expr_start = p.tok_i;
    var prev_total = p.diagnostics.total;
    var lhs = (try p.assignExpr()) orelse {
        if (p.tok_ids[p.tok_i] == .comma) _ = try p.expectResult(null);
        return null;
    };
    while (p.eatToken(.comma)) |comma| {
        try lhs.maybeWarnUnused(p, expr_start, prev_total);
        expr_start = p.tok_i;
        prev_total = p.diagnostics.total;

        var rhs = try p.expect(assignExpr);
        try rhs.lvalConversion(p, expr_start);
        lhs.val = rhs.val;
        lhs.qt = rhs.qt;
        try lhs.bin(p, .comma_expr, rhs, comma);
    }
    return lhs;
}

fn eatTag(p: *Parser, id: Token.Id) ?std.meta.Tag(Node) {
    if (p.eatToken(id)) |_| return switch (id) {
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
    } else return null;
}

fn nonAssignExpr(assign_node: std.meta.Tag(Node)) std.meta.Tag(Node) {
    return switch (assign_node) {
        .mul_assign_expr => .mul_expr,
        .div_assign_expr => .div_expr,
        .mod_assign_expr => .mod_expr,
        .add_assign_expr => .add_expr,
        .sub_assign_expr => .sub_expr,
        .shl_assign_expr => .shl_expr,
        .shr_assign_expr => .shr_expr,
        .bit_and_assign_expr => .bit_and_expr,
        .bit_xor_assign_expr => .bit_xor_expr,
        .bit_or_assign_expr => .bit_or_expr,
        else => unreachable,
    };
}

fn unwrapNestedOperation(p: *Parser, node_idx: Node.Index) ?Node.DeclRef {
    return loop: switch (node_idx.get(&p.tree)) {
        inline .array_access_expr,
        .member_access_ptr_expr,
        .member_access_expr,
        => |memb_or_arr_access| continue :loop memb_or_arr_access.base.get(&p.tree),
        inline .cast,
        .paren_expr,
        .pre_inc_expr,
        .post_inc_expr,
        .pre_dec_expr,
        .post_dec_expr,
        => |cast_or_unary| continue :loop cast_or_unary.operand.get(&p.tree),
        .sub_expr,
        .add_expr,
        => |bin| continue :loop bin.lhs.get(&p.tree),
        .call_expr => |call| continue :loop call.callee.get(&p.tree),
        .decl_ref_expr => |decl_ref| decl_ref,
        else => null,
    };
}

fn issueDeclaredConstHereNote(p: *Parser, decl_ref: Tree.Node.DeclRef, var_name: []const u8) Compilation.Error!void {
    const location = switch (decl_ref.decl.get(&p.tree)) {
        .variable => |variable| variable.name_tok,
        .param => |param| param.name_tok,
        else => return,
    };
    try p.err(location, .declared_const_here, .{var_name});
}

fn issueConstAssignmetDiagnostics(p: *Parser, node_idx: Node.Index, tok: TokenIndex) Compilation.Error!void {
    if (p.unwrapNestedOperation(node_idx)) |unwrapped| {
        const name = p.tokSlice(unwrapped.name_tok);
        try p.err(tok, .const_var_assignment, .{ name, unwrapped.qt });
        try p.issueDeclaredConstHereNote(unwrapped, name);
    } else {
        try p.err(tok, .not_assignable, .{});
    }
}

/// assignExpr
///  : condExpr
///  | unExpr ('=' | '*=' | '/=' | '%=' | '+=' | '-=' | '<<=' | '>>=' | '&=' | '^=' | '|=') assignExpr
fn assignExpr(p: *Parser) Error!?Result {
    var lhs = (try p.condExpr()) orelse return null;

    const tok = p.tok_i;
    const tag = p.eatTag(.equal) orelse
        p.eatTag(.asterisk_equal) orelse
        p.eatTag(.slash_equal) orelse
        p.eatTag(.percent_equal) orelse
        p.eatTag(.plus_equal) orelse
        p.eatTag(.minus_equal) orelse
        p.eatTag(.angle_bracket_angle_bracket_left_equal) orelse
        p.eatTag(.angle_bracket_angle_bracket_right_equal) orelse
        p.eatTag(.ampersand_equal) orelse
        p.eatTag(.caret_equal) orelse
        p.eatTag(.pipe_equal) orelse return lhs;

    var rhs = try p.expect(assignExpr);

    var is_const: bool = undefined;
    if (!p.tree.isLvalExtra(lhs.node, &is_const) or is_const) {
        try p.issueConstAssignmetDiagnostics(lhs.node, tok);
        lhs.qt = .invalid;
    }

    if (tag == .assign_expr) {
        try rhs.coerce(p, lhs.qt, tok, .assign);

        try lhs.bin(p, tag, rhs, tok);
        return lhs;
    }

    var lhs_dummy = blk: {
        var lhs_copy = lhs;
        try lhs_copy.un(p, .compound_assign_dummy_expr, tok);
        try lhs_copy.lvalConversion(p, tok);
        break :blk lhs_copy;
    };
    switch (tag) {
        .mul_assign_expr,
        .div_assign_expr,
        .mod_assign_expr,
        => {
            if (!lhs.qt.isInvalid() and rhs.val.isZero(p.comp) and lhs.qt.isInt(p.comp) and rhs.qt.isInt(p.comp)) {
                switch (tag) {
                    .div_assign_expr => try p.err(tok, .division_by_zero, .{"division"}),
                    .mod_assign_expr => try p.err(tok, .division_by_zero, .{"remainder"}),
                    else => {},
                }
            }
            _ = try lhs_dummy.adjustTypes(tok, &rhs, p, if (tag == .mod_assign_expr) .integer else .arithmetic);
        },
        .sub_assign_expr => {
            _ = try lhs_dummy.adjustTypes(tok, &rhs, p, .sub);
        },
        .add_assign_expr => {
            _ = try lhs_dummy.adjustTypes(tok, &rhs, p, .add);
        },
        .shl_assign_expr,
        .shr_assign_expr,
        .bit_and_assign_expr,
        .bit_xor_assign_expr,
        .bit_or_assign_expr,
        => {
            _ = try lhs_dummy.adjustTypes(tok, &rhs, p, .integer);
        },
        else => unreachable,
    }

    _ = try lhs_dummy.bin(p, nonAssignExpr(tag), rhs, tok);
    try lhs_dummy.coerce(p, lhs.qt, tok, .assign);
    try lhs.bin(p, tag, lhs_dummy, tok);
    return lhs;
}

/// Returns a parse error if the expression is not an integer constant
/// integerConstExpr : constExpr
fn integerConstExpr(p: *Parser, decl_folding: ConstDeclFoldingMode) Error!Result {
    const start = p.tok_i;
    const res = try p.constExpr(decl_folding);
    if (!res.qt.isInvalid() and !res.qt.isRealInt(p.comp)) {
        try p.err(start, .expected_integer_constant_expr, .{});
        return error.ParsingFailed;
    }
    return res;
}

/// Caller is responsible for issuing a diagnostic if result is invalid/unavailable
/// constExpr : condExpr
fn constExpr(p: *Parser, decl_folding: ConstDeclFoldingMode) Error!Result {
    const const_decl_folding = p.const_decl_folding;
    defer p.const_decl_folding = const_decl_folding;
    p.const_decl_folding = decl_folding;

    const res = try p.expect(condExpr);

    if (res.qt.isInvalid() or res.val.opt_ref == .none) return res;

    try res.putValue(p);
    return res;
}

/// condExpr : lorExpr ('?' expression? ':' condExpr)?
fn condExpr(p: *Parser) Error!?Result {
    const cond_tok = p.tok_i;
    var cond = (try p.lorExpr()) orelse return null;
    if (p.eatToken(.question_mark) == null) return cond;
    try cond.lvalConversion(p, cond_tok);
    const saved_eval = p.no_eval;

    if (cond.qt.scalarKind(p.comp) == .none) {
        try p.err(cond_tok, .cond_expr_type, .{cond.qt});
        return error.ParsingFailed;
    }

    // Prepare for possible binary conditional expression.
    const maybe_colon = p.eatToken(.colon);

    // Depending on the value of the condition, avoid evaluating unreachable branches.
    var then_expr = blk: {
        defer p.no_eval = saved_eval;
        if (cond.val.opt_ref != .none and !cond.val.toBool(p.comp)) p.no_eval = true;
        break :blk try p.expect(expr);
    };

    // If we saw a colon then this is a binary conditional expression.
    if (maybe_colon) |colon| {
        var cond_then = cond;
        cond_then.node = try p.addNode(.{
            .cond_dummy_expr = .{
                .op_tok = colon,
                .operand = cond.node,
                .qt = cond.qt,
            },
        });
        _ = try cond_then.adjustTypes(colon, &then_expr, p, .conditional);
        cond.qt = then_expr.qt;
        cond.node = try p.addNode(.{
            .binary_cond_expr = .{
                .cond_tok = cond_tok,
                .cond = cond.node,
                .then_expr = cond_then.node,
                .else_expr = then_expr.node,
                .qt = cond.qt,
            },
        });
        return cond;
    }

    const colon = try p.expectToken(.colon);
    var else_expr = blk: {
        defer p.no_eval = saved_eval;
        if (cond.val.opt_ref != .none and cond.val.toBool(p.comp)) p.no_eval = true;
        break :blk try p.expect(condExpr);
    };

    _ = try then_expr.adjustTypes(colon, &else_expr, p, .conditional);

    if (cond.val.opt_ref != .none) {
        cond.val = if (cond.val.toBool(p.comp)) then_expr.val else else_expr.val;
    } else {
        try then_expr.saveValue(p);
        try else_expr.saveValue(p);
    }
    cond.qt = then_expr.qt;
    cond.node = try p.addNode(.{
        .cond_expr = .{
            .cond_tok = cond_tok,
            .qt = cond.qt,
            .cond = cond.node,
            .then_expr = then_expr.node,
            .else_expr = else_expr.node,
        },
    });
    return cond;
}

/// lorExpr : landExpr ('||' landExpr)*
fn lorExpr(p: *Parser) Error!?Result {
    var lhs = (try p.landExpr()) orelse return null;
    const saved_eval = p.no_eval;
    defer p.no_eval = saved_eval;

    while (p.eatToken(.pipe_pipe)) |tok| {
        if (lhs.val.opt_ref != .none and lhs.val.toBool(p.comp)) p.no_eval = true;
        var rhs = try p.expect(landExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .boolean_logic)) {
            const res = lhs.val.toBool(p.comp) or rhs.val.toBool(p.comp);
            lhs.val = Value.fromBool(res);
        } else {
            lhs.val.boolCast(p.comp);
        }
        try lhs.boolRes(p, .bool_or_expr, rhs, tok);
    }
    return lhs;
}

/// landExpr : orExpr ('&&' orExpr)*
fn landExpr(p: *Parser) Error!?Result {
    var lhs = (try p.orExpr()) orelse return null;
    const saved_eval = p.no_eval;
    defer p.no_eval = saved_eval;

    while (p.eatToken(.ampersand_ampersand)) |tok| {
        if (lhs.val.opt_ref != .none and !lhs.val.toBool(p.comp)) p.no_eval = true;
        var rhs = try p.expect(orExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .boolean_logic)) {
            const res = lhs.val.toBool(p.comp) and rhs.val.toBool(p.comp);
            lhs.val = Value.fromBool(res);
        } else {
            lhs.val.boolCast(p.comp);
        }
        try lhs.boolRes(p, .bool_and_expr, rhs, tok);
    }
    return lhs;
}

/// orExpr : xorExpr ('|' xorExpr)*
fn orExpr(p: *Parser) Error!?Result {
    var lhs = (try p.xorExpr()) orelse return null;
    while (p.eatToken(.pipe)) |tok| {
        var rhs = try p.expect(xorExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = try lhs.val.bitOr(rhs.val, p.comp);
        }
        try lhs.bin(p, .bit_or_expr, rhs, tok);
    }
    return lhs;
}

/// xorExpr : andExpr ('^' andExpr)*
fn xorExpr(p: *Parser) Error!?Result {
    var lhs = (try p.andExpr()) orelse return null;
    while (p.eatToken(.caret)) |tok| {
        var rhs = try p.expect(andExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = try lhs.val.bitXor(rhs.val, p.comp);
        }
        try lhs.bin(p, .bit_xor_expr, rhs, tok);
    }
    return lhs;
}

/// andExpr : eqExpr ('&' eqExpr)*
fn andExpr(p: *Parser) Error!?Result {
    var lhs = (try p.eqExpr()) orelse return null;
    while (p.eatToken(.ampersand)) |tok| {
        var rhs = try p.expect(eqExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            lhs.val = try lhs.val.bitAnd(rhs.val, p.comp);
        }
        try lhs.bin(p, .bit_and_expr, rhs, tok);
    }
    return lhs;
}

/// eqExpr : compExpr (('==' | '!=') compExpr)*
fn eqExpr(p: *Parser) Error!?Result {
    var lhs = (try p.compExpr()) orelse return null;
    while (true) {
        const tok = p.tok_i;
        const tag = p.eatTag(.equal_equal) orelse
            p.eatTag(.bang_equal) orelse break;
        var rhs = try p.expect(compExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .equality)) {
            const op: std.math.CompareOperator = if (tag == .equal_expr) .eq else .neq;

            const res: ?bool = if (lhs.qt.isPointer(p.comp) or rhs.qt.isPointer(p.comp))
                lhs.val.comparePointers(op, rhs.val, p.comp)
            else
                lhs.val.compare(op, rhs.val, p.comp);

            lhs.val = if (res) |val| Value.fromBool(val) else .{};
        } else {
            lhs.val.boolCast(p.comp);
        }
        try lhs.boolRes(p, tag, rhs, tok);
    }
    return lhs;
}

/// compExpr : shiftExpr (('<' | '<=' | '>' | '>=') shiftExpr)*
fn compExpr(p: *Parser) Error!?Result {
    var lhs = (try p.shiftExpr()) orelse return null;
    while (true) {
        const tok = p.tok_i;
        const tag = p.eatTag(.angle_bracket_left) orelse
            p.eatTag(.angle_bracket_left_equal) orelse
            p.eatTag(.angle_bracket_right) orelse
            p.eatTag(.angle_bracket_right_equal) orelse break;
        var rhs = try p.expect(shiftExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .relational)) {
            const op: std.math.CompareOperator = switch (tag) {
                .less_than_expr => .lt,
                .less_than_equal_expr => .lte,
                .greater_than_expr => .gt,
                .greater_than_equal_expr => .gte,
                else => unreachable,
            };

            const res: ?bool = if (lhs.qt.isPointer(p.comp) or rhs.qt.isPointer(p.comp))
                lhs.val.comparePointers(op, rhs.val, p.comp)
            else
                lhs.val.compare(op, rhs.val, p.comp);
            lhs.val = if (res) |val| Value.fromBool(val) else .{};
        } else {
            lhs.val.boolCast(p.comp);
        }
        try lhs.boolRes(p, tag, rhs, tok);
    }
    return lhs;
}

/// shiftExpr : addExpr (('<<' | '>>') addExpr)*
fn shiftExpr(p: *Parser) Error!?Result {
    var lhs = (try p.addExpr()) orelse return null;
    while (true) {
        const tok = p.tok_i;
        const tag = p.eatTag(.angle_bracket_angle_bracket_left) orelse
            p.eatTag(.angle_bracket_angle_bracket_right) orelse break;
        var rhs = try p.expect(addExpr);

        if (try lhs.adjustTypes(tok, &rhs, p, .integer)) {
            if (rhs.val.compare(.lt, .zero, p.comp)) {
                try p.err(tok, .negative_shift_count, .{});
            }
            if (rhs.val.compare(.gte, try Value.int(lhs.qt.bitSizeof(p.comp), p.comp), p.comp)) {
                try p.err(tok, .too_big_shift_count, .{});
            }
            if (tag == .shl_expr) {
                if (try lhs.val.shl(lhs.val, rhs.val, lhs.qt, p.comp) and
                    lhs.qt.signedness(p.comp) != .unsigned) try p.err(tok, .overflow, .{lhs});
            } else {
                lhs.val = try lhs.val.shr(rhs.val, lhs.qt, p.comp);
            }
        }
        try lhs.bin(p, tag, rhs, tok);
    }
    return lhs;
}

/// addExpr : mulExpr (('+' | '-') mulExpr)*
fn addExpr(p: *Parser) Error!?Result {
    var lhs = (try p.mulExpr()) orelse return null;
    while (true) {
        const tok = p.tok_i;
        const tag = p.eatTag(.plus) orelse
            p.eatTag(.minus) orelse break;
        var rhs = try p.expect(mulExpr);

        // We'll want to check this for invalid pointer arithmetic.
        const original_lhs_qt = lhs.qt;

        if (try lhs.adjustTypes(tok, &rhs, p, if (tag == .add_expr) .add else .sub)) {
            const lhs_sk = lhs.qt.scalarKind(p.comp);
            if (tag == .add_expr) {
                if (try lhs.val.add(lhs.val, rhs.val, lhs.qt, p.comp)) {
                    if (lhs_sk.isPointer()) {
                        const increment = lhs;
                        const ptr_bits = p.comp.type_store.intptr.bitSizeof(p.comp);
                        const element_size = increment.qt.childType(p.comp).sizeofOrNull(p.comp) orelse 1;
                        const max_elems = p.comp.maxArrayBytes() / element_size;

                        try p.err(tok, .array_overflow, .{ increment, ptr_bits, element_size * 8, element_size, max_elems });
                    } else if (lhs.qt.signedness(p.comp) != .unsigned) {
                        try p.err(tok, .overflow, .{lhs});
                    }
                }
            } else {
                const elem_size = if (original_lhs_qt.isPointer(p.comp)) original_lhs_qt.childType(p.comp).sizeofOrNull(p.comp) orelse 1 else 1;
                if (elem_size == 0 and rhs.qt.isPointer(p.comp)) {
                    lhs.val = .{};
                } else {
                    if (try lhs.val.sub(lhs.val, rhs.val, lhs.qt, elem_size, p.comp) and
                        lhs.qt.signedness(p.comp) != .unsigned)
                    {
                        try p.err(tok, .overflow, .{lhs});
                    }
                }
            }
        }
        if (!lhs.qt.isInvalid()) {
            const lhs_sk = original_lhs_qt.scalarKind(p.comp);
            if (lhs_sk == .pointer and original_lhs_qt.childType(p.comp).hasIncompleteSize(p.comp)) {
                try p.err(tok, .ptr_arithmetic_incomplete, .{original_lhs_qt.childType(p.comp)});
                lhs.qt = .invalid;
            }
        }
        try lhs.bin(p, tag, rhs, tok);
    }
    return lhs;
}

/// mulExpr : castExpr (('*' | '/' | '%') castExpr)*´
fn mulExpr(p: *Parser) Error!?Result {
    var lhs = (try p.castExpr()) orelse return null;
    while (true) {
        const tok = p.tok_i;
        const tag = p.eatTag(.asterisk) orelse
            p.eatTag(.slash) orelse
            p.eatTag(.percent) orelse break;
        var rhs = try p.expect(castExpr);

        if (rhs.val.isZero(p.comp) and tag != .mul_expr and !p.no_eval and lhs.qt.isInt(p.comp) and rhs.qt.isInt(p.comp)) {
            lhs.val = .{};
            try p.err(tok, if (p.in_macro) .division_by_zero_macro else .division_by_zero, if (tag == .div_expr) .{"division"} else .{"remainder"});
            if (p.in_macro) return error.ParsingFailed;
        }

        if (try lhs.adjustTypes(tok, &rhs, p, if (tag == .mod_expr) .integer else .arithmetic)) {
            switch (tag) {
                .mul_expr => if (try lhs.val.mul(lhs.val, rhs.val, lhs.qt, p.comp) and
                    lhs.qt.signedness(p.comp) != .unsigned) try p.err(tok, .overflow, .{lhs}),
                .div_expr => if (try lhs.val.div(lhs.val, rhs.val, lhs.qt, p.comp) and
                    lhs.qt.signedness(p.comp) != .unsigned) try p.err(tok, .overflow, .{lhs}),
                .mod_expr => {
                    var res = try Value.rem(lhs.val, rhs.val, lhs.qt, p.comp);
                    if (res.opt_ref == .none) {
                        if (p.in_macro) {
                            // match clang behavior by defining invalid remainder to be zero in macros
                            res = .zero;
                        } else {
                            try lhs.saveValue(p);
                            try rhs.saveValue(p);
                        }
                    }
                    lhs.val = res;
                },
                else => unreachable,
            }
        }

        try lhs.bin(p, tag, rhs, tok);
    }
    return lhs;
}

/// castExpr
///  :  '(' compoundStmt ')' suffixExpr*
///  |  '(' typeName ')' castExpr
///  | '(' typeName ')' '{' initializerItems '}'
///  | unExpr
fn castExpr(p: *Parser) Error!?Result {
    if (p.eatToken(.l_paren)) |l_paren| cast_expr: {
        if (p.tok_ids[p.tok_i] == .l_brace) {
            const tok = p.tok_i;
            try p.err(p.tok_i, .gnu_statement_expression, .{});
            if (p.func.qt == null) {
                try p.err(p.tok_i, .stmt_expr_not_allowed_file_scope, .{});
                return error.ParsingFailed;
            }
            var stmt_expr_state: StmtExprState = .{};
            const body_node = (try p.compoundStmt(false, &stmt_expr_state)).?; // compoundStmt only returns null if .l_brace isn't the first token

            var res: Result = .{
                .node = body_node,
                .qt = stmt_expr_state.last_expr_qt,
            };
            try p.expectClosing(l_paren, .r_paren);
            try res.un(p, .stmt_expr, tok);
            while (try p.suffixExpr(res)) |suffix| {
                res = suffix;
            }
            return res;
        }
        const ty = (try p.typeName()) orelse {
            p.tok_i -= 1;
            break :cast_expr;
        };
        try p.expectClosing(l_paren, .r_paren);

        if (p.tok_ids[p.tok_i] == .l_brace) {
            var lhs = (try p.compoundLiteral(ty, l_paren)).?;
            while (try p.suffixExpr(lhs)) |suffix| {
                lhs = suffix;
            }
            return lhs;
        }

        const operand_tok = p.tok_i;
        var operand = try p.expect(castExpr);
        try operand.lvalConversion(p, operand_tok);
        try operand.castType(p, ty, operand_tok, l_paren);
        return operand;
    }
    return p.unExpr();
}

/// builtinBitCast : __builtin_bit_cast '(' typeName ',' assignExpr ')'
fn builtinBitCast(p: *Parser, builtin_tok: TokenIndex) Error!Result {
    const l_paren = try p.expectToken(.l_paren);

    const res_qt = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        return error.ParsingFailed;
    };

    _ = try p.expectToken(.comma);

    const operand_tok = p.tok_i;
    var operand = try p.expect(assignExpr);
    try operand.lvalConversion(p, operand_tok);

    try p.expectClosing(l_paren, .r_paren);

    return .{
        .qt = res_qt,
        .node = try p.addNode(.{
            .cast = .{
                .l_paren = builtin_tok,
                .qt = res_qt,
                .kind = .bitcast,
                .operand = operand.node,
                .implicit = false,
            },
        }),
    };
}

/// shufflevector : __builtin_shufflevector '(' assignExpr ',' assignExpr (',' integerConstExpr)* ')'
fn shufflevector(p: *Parser, builtin_tok: TokenIndex) Error!Result {
    const l_paren = try p.expectToken(.l_paren);

    const first_tok = p.tok_i;
    const lhs = try p.expect(assignExpr);
    _ = try p.expectToken(.comma);
    const second_tok = p.tok_i;
    const rhs = try p.expect(assignExpr);

    const max_index: ?Value = blk: {
        if (lhs.qt.isInvalid() or rhs.qt.isInvalid()) break :blk null;
        const lhs_vec = lhs.qt.get(p.comp, .vector) orelse break :blk null;
        const rhs_vec = rhs.qt.get(p.comp, .vector) orelse break :blk null;

        break :blk try Value.int(lhs_vec.len + rhs_vec.len, p.comp);
    };
    const negative_one = try Value.intern(p.comp, .{ .int = .{ .i64 = -1 } });

    const gpa = p.comp.gpa;
    const list_buf_top = p.list_buf.items.len;
    defer p.list_buf.items.len = list_buf_top;
    while (p.eatToken(.comma)) |_| {
        const index_tok = p.tok_i;
        const index = try p.integerConstExpr(.gnu_folding_extension);
        try p.list_buf.append(gpa, index.node);
        if (index.val.compare(.lt, negative_one, p.comp)) {
            try p.err(index_tok, .shufflevector_negative_index, .{});
        } else if (max_index != null and index.val.compare(.gte, max_index.?, p.comp)) {
            try p.err(index_tok, .shufflevector_index_too_big, .{});
        }
    }

    try p.expectClosing(l_paren, .r_paren);

    var res_qt: QualType = .invalid;
    if (!lhs.qt.isInvalid() and !lhs.qt.is(p.comp, .vector)) {
        try p.err(first_tok, .shufflevector_arg, .{"first"});
    } else if (!rhs.qt.isInvalid() and !rhs.qt.is(p.comp, .vector)) {
        try p.err(second_tok, .shufflevector_arg, .{"second"});
    } else if (!lhs.qt.eql(rhs.qt, p.comp)) {
        try p.err(builtin_tok, .shufflevector_same_type, .{});
    } else if (p.list_buf.items.len == list_buf_top) {
        res_qt = lhs.qt;
    } else {
        res_qt = try p.comp.type_store.put(gpa, .{ .vector = .{
            .elem = lhs.qt.childType(p.comp),
            .len = @intCast(p.list_buf.items.len - list_buf_top),
        } });
    }

    return .{
        .qt = res_qt,
        .node = try p.addNode(.{
            .builtin_shufflevector = .{
                .builtin_tok = builtin_tok,
                .qt = res_qt,
                .lhs = lhs.node,
                .rhs = rhs.node,
                .indexes = p.list_buf.items[list_buf_top..],
            },
        }),
    };
}

/// convertvector : __builtin_convertvector '(' assignExpr ',' typeName ')'
fn convertvector(p: *Parser, builtin_tok: TokenIndex) Error!Result {
    const l_paren = try p.expectToken(.l_paren);

    const operand = try p.expect(assignExpr);
    _ = try p.expectToken(.comma);

    var dest_qt = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    };

    try p.expectClosing(l_paren, .r_paren);

    if (operand.qt.isInvalid() or operand.qt.isInvalid()) {
        dest_qt = .invalid;
    } else check: {
        const operand_vec = operand.qt.get(p.comp, .vector) orelse {
            try p.err(builtin_tok, .convertvector_arg, .{"first"});
            dest_qt = .invalid;
            break :check;
        };
        const dest_vec = dest_qt.get(p.comp, .vector) orelse {
            try p.err(builtin_tok, .convertvector_arg, .{"second"});
            dest_qt = .invalid;
            break :check;
        };
        if (operand_vec.len != dest_vec.len) {
            try p.err(builtin_tok, .convertvector_size, .{});
            dest_qt = .invalid;
        }
    }

    return .{
        .qt = dest_qt,
        .node = try p.addNode(.{
            .builtin_convertvector = .{
                .builtin_tok = builtin_tok,
                .dest_qt = dest_qt,
                .operand = operand.node,
            },
        }),
    };
}

/// typesCompatible : __builtin_types_compatible_p '(' typeName ',' typeName ')'
fn typesCompatible(p: *Parser, builtin_tok: TokenIndex) Error!Result {
    const l_paren = try p.expectToken(.l_paren);

    const lhs = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    };
    _ = try p.expectToken(.comma);

    const rhs = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    };

    try p.expectClosing(l_paren, .r_paren);

    const compatible = lhs.eql(rhs, p.comp);
    const res: Result = .{
        .val = Value.fromBool(compatible),
        .qt = .int,
        .node = try p.addNode(.{
            .builtin_types_compatible_p = .{
                .builtin_tok = builtin_tok,
                .lhs = lhs,
                .rhs = rhs,
            },
        }),
    };
    try res.putValue(p);
    return res;
}

/// chooseExpr : __builtin_choose_expr '(' integerConstExpr ',' assignExpr ',' assignExpr ')'
fn builtinChooseExpr(p: *Parser) Error!Result {
    const l_paren = try p.expectToken(.l_paren);
    const cond_tok = p.tok_i;
    var cond = try p.integerConstExpr(.no_const_decl_folding);
    if (cond.val.opt_ref == .none) {
        try p.err(cond_tok, .builtin_choose_cond, .{});
        return error.ParsingFailed;
    }

    _ = try p.expectToken(.comma);

    const then_expr = if (cond.val.toBool(p.comp))
        try p.expect(assignExpr)
    else
        try p.parseNoEval(assignExpr);

    _ = try p.expectToken(.comma);

    const else_expr = if (!cond.val.toBool(p.comp))
        try p.expect(assignExpr)
    else
        try p.parseNoEval(assignExpr);

    try p.expectClosing(l_paren, .r_paren);

    if (cond.val.toBool(p.comp)) {
        cond.val = then_expr.val;
        cond.qt = then_expr.qt;
    } else {
        cond.val = else_expr.val;
        cond.qt = else_expr.qt;
    }
    cond.node = try p.addNode(.{
        .builtin_choose_expr = .{
            .cond_tok = cond_tok,
            .qt = cond.qt,
            .cond = cond.node,
            .then_expr = then_expr.node,
            .else_expr = else_expr.node,
        },
    });
    return cond;
}

/// vaStart : __builtin_va_arg '(' assignExpr ',' typeName ')'
fn builtinVaArg(p: *Parser, builtin_tok: TokenIndex) Error!Result {
    const l_paren = try p.expectToken(.l_paren);
    const va_list_tok = p.tok_i;
    var va_list = try p.expect(assignExpr);
    try va_list.lvalConversion(p, va_list_tok);

    _ = try p.expectToken(.comma);

    const ty = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        return error.ParsingFailed;
    };
    try p.expectClosing(l_paren, .r_paren);

    if (!va_list.qt.eql(p.comp.type_store.va_list, p.comp)) {
        try p.err(va_list_tok, .incompatible_va_arg, .{va_list.qt});
        return error.ParsingFailed;
    }

    return .{
        .qt = ty,
        .node = try p.addNode(.{
            .builtin_call_expr = .{
                .builtin_tok = builtin_tok,
                .qt = ty,
                .args = &.{va_list.node},
            },
        }),
    };
}

const OffsetKind = enum { bits, bytes };

/// offsetof
///  : __builtin_offsetof '(' typeName ',' offsetofMemberDesignator ')'
///  | __builtin_bitoffsetof '(' typeName ',' offsetofMemberDesignator ')'
fn builtinOffsetof(p: *Parser, builtin_tok: TokenIndex, offset_kind: OffsetKind) Error!Result {
    const l_paren = try p.expectToken(.l_paren);
    const ty_tok = p.tok_i;

    const operand_qt = (try p.typeName()) orelse {
        try p.err(p.tok_i, .expected_type, .{});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    };

    const record_ty = operand_qt.getRecord(p.comp) orelse {
        try p.err(ty_tok, .offsetof_ty, .{operand_qt});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    };

    if (record_ty.layout == null) {
        try p.err(ty_tok, .offsetof_incomplete, .{operand_qt});
        p.skipTo(.r_paren);
        return error.ParsingFailed;
    }

    _ = try p.expectToken(.comma);

    const offsetof_expr = try p.offsetofMemberDesignator(record_ty, operand_qt, offset_kind, builtin_tok);

    try p.expectClosing(l_paren, .r_paren);

    const res: Result = .{
        .qt = p.comp.type_store.size,
        .val = offsetof_expr.val,
        .node = try p.addNode(.{
            .builtin_call_expr = .{
                .builtin_tok = builtin_tok,
                .qt = p.comp.type_store.size,
                .args = &.{offsetof_expr.node},
            },
        }),
    };
    try res.putValue(p);
    return res;
}

/// offsetofMemberDesignator : IDENTIFIER ('.' IDENTIFIER | '[' expr ']' )*
fn offsetofMemberDesignator(
    p: *Parser,
    base_record_ty: Type.Record,
    base_qt: QualType,
    offset_kind: OffsetKind,
    base_access_tok: TokenIndex,
) Error!Result {
    errdefer p.skipTo(.r_paren);
    const base_field_name_tok = try p.expectIdentifier();
    const base_field_name = try p.comp.internString(p.tokSlice(base_field_name_tok));

    const base_node = try p.addNode(.{ .default_init_expr = .{
        .last_tok = p.tok_i,
        .qt = base_qt,
    } });

    var lhs, const initial_offset = try p.fieldAccessExtra(base_node, base_record_ty, false, &.{
        .base_qt = base_qt,
        .target_name = base_field_name,
        .access_tok = base_access_tok,
        .name_tok = base_field_name_tok,
        .check_deprecated = false,
    });

    var total_offset: i64 = @intCast(initial_offset);
    var runtime_offset = false;
    while (true) switch (p.tok_ids[p.tok_i]) {
        .period => {
            const access_tok = p.tok_i;
            p.tok_i += 1;
            const field_name_tok = try p.expectIdentifier();
            const field_name = try p.comp.internString(p.tokSlice(field_name_tok));

            const lhs_record_ty = lhs.qt.getRecord(p.comp) orelse {
                try p.err(field_name_tok, .offsetof_ty, .{lhs.qt});
                return error.ParsingFailed;
            };
            lhs, const offset_bits = try p.fieldAccessExtra(lhs.node, lhs_record_ty, false, &.{
                .base_qt = base_qt,
                .target_name = field_name,
                .access_tok = access_tok,
                .name_tok = field_name_tok,
                .check_deprecated = false,
            });
            total_offset += @intCast(offset_bits);
        },
        .l_bracket => {
            const l_bracket_tok = p.tok_i;
            p.tok_i += 1;
            var index = try p.expect(expr);
            _ = try p.expectClosing(l_bracket_tok, .r_bracket);

            const array_ty = lhs.qt.get(p.comp, .array) orelse {
                try p.err(l_bracket_tok, .offsetof_array, .{lhs.qt});
                return error.ParsingFailed;
            };
            var ptr = lhs;
            try ptr.lvalConversion(p, l_bracket_tok);
            try index.lvalConversion(p, l_bracket_tok);

            if (!index.qt.isInvalid() and index.qt.isRealInt(p.comp)) {
                try p.checkArrayBounds(index, lhs, l_bracket_tok);
            } else if (!index.qt.isInvalid()) {
                try p.err(l_bracket_tok, .invalid_index, .{});
            }

            if (index.val.toInt(i64, p.comp)) |index_int| {
                total_offset += @as(i64, @intCast(array_ty.elem.bitSizeof(p.comp))) * index_int;
            } else {
                runtime_offset = true;
            }

            try index.saveValue(p);
            ptr.node = try p.addNode(.{ .array_access_expr = .{
                .l_bracket_tok = l_bracket_tok,
                .base = ptr.node,
                .index = index.node,
                .qt = ptr.qt,
            } });
            lhs = ptr;
        },
        else => break,
    };
    return .{
        .qt = base_qt,
        .val = if (runtime_offset)
            .{}
        else
            try Value.int(if (offset_kind == .bits) total_offset else @divExact(total_offset, 8), p.comp),
        .node = lhs.node,
    };
}

fn computeOffsetExtra(p: *Parser, node: Node.Index, offset_so_far: *Value) !Value {
    switch (node.get(&p.tree)) {
        .cast => |cast| {
            return switch (cast.kind) {
                .lval_to_rval => .{},
                else => p.computeOffsetExtra(cast.operand, offset_so_far),
            };
        },
        .paren_expr => |un| return p.computeOffsetExtra(un.operand, offset_so_far),
        .decl_ref_expr => return p.pointerValue(node, offset_so_far.*),
        .array_access_expr => |access| {
            const index_val = p.tree.value_map.get(access.index) orelse return .{};
            var size = try Value.int(access.qt.sizeof(p.comp), p.comp);
            const mul_overflow = try size.mul(size, index_val, p.comp.type_store.ptrdiff, p.comp);

            const add_overflow = try offset_so_far.add(size, offset_so_far.*, p.comp.type_store.ptrdiff, p.comp);
            _ = mul_overflow;
            _ = add_overflow;
            return p.computeOffsetExtra(access.base, offset_so_far);
        },
        .member_access_expr, .member_access_ptr_expr => |access| {
            var ty = access.base.qt(&p.tree);
            if (ty.isPointer(p.comp)) ty = ty.childType(p.comp);
            const record_ty = ty.getRecord(p.comp).?;

            const field_offset = try Value.int(@divExact(record_ty.fields[access.member_index].layout.offset_bits, 8), p.comp);
            _ = try offset_so_far.add(field_offset, offset_so_far.*, p.comp.type_store.ptrdiff, p.comp);
            return p.computeOffsetExtra(access.base, offset_so_far);
        },
        else => return .{},
    }
}

/// Compute the offset (in bytes) of an expression from a base pointer.
fn computeOffset(p: *Parser, res: Result) !Value {
    var val: Value = if (res.val.opt_ref == .none) .zero else res.val;
    return p.computeOffsetExtra(res.node, &val);
}

/// unExpr
///  : (compoundLiteral | primaryExpr) suffixExpr*
///  | '&&' IDENTIFIER
///  | ('&' | '*' | '+' | '-' | '~' | '!' | '++' | '--' | keyword_extension | keyword_imag | keyword_real) castExpr
///  | keyword_sizeof unExpr
///  | keyword_sizeof '(' typeName ')'
///  | keyword_alignof '(' typeName ')'
///  | keyword_c23_alignof '(' typeName ')'
fn unExpr(p: *Parser) Error!?Result {
    const gpa = p.comp.gpa;
    const tok = p.tok_i;
    switch (p.tok_ids[tok]) {
        .ampersand_ampersand => {
            const address_tok = p.tok_i;
            p.tok_i += 1;
            const name_tok = try p.expectIdentifier();
            try p.err(address_tok, .gnu_label_as_value, .{});
            p.contains_address_of_label = true;

            const str = p.tokSlice(name_tok);
            if (p.findLabel(str) == null) {
                try p.labels.append(gpa, .{ .unresolved_goto = name_tok });
            }

            return .{
                .node = try p.addNode(.{
                    .addr_of_label = .{
                        .label_tok = name_tok,
                        .qt = .void_pointer,
                    },
                }),
                .qt = .void_pointer,
            };
        },
        .ampersand => {
            if (p.in_macro) {
                try p.err(p.tok_i, .invalid_preproc_operator, .{});
                return error.ParsingFailed;
            }
            const orig_tok_i = p.tok_i;
            p.tok_i += 1;
            var operand = try p.expect(castExpr);
            var addr_val: Value = .{};

            if (p.getNode(operand.node, .member_access_expr) orelse
                p.getNode(operand.node, .member_access_ptr_expr)) |access|
            {
                if (access.isBitFieldWidth(&p.tree) != null) try p.err(tok, .addr_of_bitfield, .{});
                const lhs_qt = access.base.qt(&p.tree);
                if (lhs_qt.hasAttribute(p.comp, .@"packed")) {
                    const record_ty = lhs_qt.getRecord(p.comp).?;
                    try p.err(orig_tok_i, .packed_member_address, .{
                        record_ty.fields[access.member_index].name.lookup(p.comp),
                        record_ty.name.lookup(p.comp),
                    });
                }
            }
            if (!operand.qt.isInvalid()) {
                if (!p.tree.isLval(operand.node)) {
                    try p.err(tok, .addr_of_rvalue, .{});
                }
                addr_val = try p.computeOffset(operand);

                operand.qt = try p.comp.type_store.put(gpa, .{ .pointer = .{
                    .child = operand.qt,
                    .decayed = null,
                } });
            }
            if (p.getNode(operand.node, .decl_ref_expr)) |decl_ref| {
                switch (decl_ref.decl.get(&p.tree)) {
                    .variable => |variable| {
                        if (variable.storage_class == .register) try p.err(tok, .addr_of_register, .{});
                    },
                    else => {},
                }
            } else if (p.getNode(operand.node, .compound_literal_expr)) |literal| {
                switch (literal.storage_class) {
                    .register => try p.err(tok, .addr_of_register, .{}),
                    else => {},
                }
            }

            try operand.saveValue(p);
            try operand.un(p, .addr_of_expr, tok);
            operand.val = addr_val;
            return operand;
        },
        .asterisk => {
            p.tok_i += 1;
            var operand = try p.expect(castExpr);

            switch (operand.qt.base(p.comp).type) {
                .array, .func, .pointer => {
                    try operand.lvalConversion(p, tok);
                    operand.qt = operand.qt.childType(p.comp);
                    operand.val = .{};
                },
                else => {
                    try p.err(tok, .indirection_ptr, .{});
                },
            }

            if (operand.qt.hasIncompleteSize(p.comp) and !operand.qt.is(p.comp, .void)) {
                try p.err(tok, .deref_incomplete_ty_ptr, .{operand.qt});
            }

            operand.qt = operand.qt.unqualified();
            try operand.un(p, .deref_expr, tok);
            return operand;
        },
        .plus => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            const scalar_qt = if (operand.qt.get(p.comp, .vector)) |vec| vec.elem else operand.qt;
            if (!scalar_qt.isInt(p.comp) and !scalar_qt.isFloat(p.comp))
                try p.err(tok, .invalid_argument_un, .{operand.qt});

            try operand.usualUnaryConversion(p, tok);

            return operand;
        },
        .minus => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            const scalar_qt = if (operand.qt.get(p.comp, .vector)) |vec| vec.elem else operand.qt;
            if (!scalar_qt.isInt(p.comp) and !scalar_qt.isFloat(p.comp))
                try p.err(tok, .invalid_argument_un, .{operand.qt});

            try operand.usualUnaryConversion(p, tok);
            if (operand.val.isArithmetic(p.comp)) {
                _ = try operand.val.negate(operand.val, operand.qt, p.comp);
            } else {
                operand.val = .{};
            }
            try operand.un(p, .negate_expr, tok);
            return operand;
        },
        .plus_plus => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            const scalar_kind = operand.qt.scalarKind(p.comp);
            if (scalar_kind == .void_pointer)
                try p.err(tok, .gnu_pointer_arith, .{});
            if (scalar_kind == .none)
                try p.err(tok, .invalid_argument_un, .{operand.qt});
            if (!scalar_kind.isReal())
                try p.err(p.tok_i, .complex_prefix_postfix_op, .{operand.qt});

            if (!p.tree.isLval(operand.node) or operand.qt.@"const") {
                try p.err(tok, .not_assignable, .{});
                return error.ParsingFailed;
            }
            try operand.usualUnaryConversion(p, tok);

            if (operand.val.is(.int, p.comp) or operand.val.is(.int, p.comp)) {
                if (try operand.val.add(operand.val, .one, operand.qt, p.comp))
                    try p.err(tok, .overflow, .{operand});
            } else {
                operand.val = .{};
            }

            try operand.un(p, .pre_inc_expr, tok);
            return operand;
        },
        .minus_minus => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            const scalar_kind = operand.qt.scalarKind(p.comp);
            if (scalar_kind == .void_pointer)
                try p.err(tok, .gnu_pointer_arith, .{});
            if (scalar_kind == .none)
                try p.err(tok, .invalid_argument_un, .{operand.qt});
            if (!scalar_kind.isReal())
                try p.err(p.tok_i, .complex_prefix_postfix_op, .{operand.qt});

            if (!p.tree.isLval(operand.node) or operand.qt.@"const") {
                try p.err(tok, .not_assignable, .{});
                return error.ParsingFailed;
            }
            try operand.usualUnaryConversion(p, tok);

            if (operand.val.is(.int, p.comp) or operand.val.is(.int, p.comp)) {
                if (try operand.val.decrement(operand.val, operand.qt, p.comp))
                    try p.err(tok, .overflow, .{operand});
            } else {
                operand.val = .{};
            }

            try operand.un(p, .pre_dec_expr, tok);
            return operand;
        },
        .tilde => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            try operand.usualUnaryConversion(p, tok);

            const scalar_qt = if (operand.qt.get(p.comp, .vector)) |vec| vec.elem else operand.qt;
            const scalar_kind = scalar_qt.scalarKind(p.comp);
            if (!scalar_kind.isReal()) {
                try p.err(tok, .complex_conj, .{operand.qt});
                if (operand.val.is(.complex, p.comp)) {
                    operand.val = try operand.val.complexConj(operand.qt, p.comp);
                }
            } else if (scalar_kind.isInt()) {
                if (operand.val.is(.int, p.comp)) {
                    operand.val = try operand.val.bitNot(operand.qt, p.comp);
                }
            } else {
                try p.err(tok, .invalid_argument_un, .{operand.qt});
                operand.val = .{};
            }
            try operand.un(p, .bit_not_expr, tok);
            return operand;
        },
        .bang => {
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            if (operand.qt.scalarKind(p.comp) == .none)
                try p.err(tok, .invalid_argument_un, .{operand.qt});

            try operand.usualUnaryConversion(p, tok);
            if (operand.val.is(.int, p.comp)) {
                operand.val = Value.fromBool(!operand.val.toBool(p.comp));
            } else if (operand.val.opt_ref == .null) {
                operand.val = .one;
            } else {
                operand.val = .{};
                if (operand.qt.get(p.comp, .pointer)) |pointer_ty| {
                    if (pointer_ty.decayed != null) operand.val = .zero;
                }
            }
            operand.qt = .int;
            try operand.un(p, .bool_not_expr, tok);
            return operand;
        },
        .keyword_sizeof => {
            p.tok_i += 1;
            const expected_paren = p.tok_i;

            var has_expr = false;
            var res: Result = .{
                .node = undefined, // check has_expr
            };
            if (try p.typeName()) |qt| {
                res.qt = qt;
                try p.err(expected_paren, .expected_parens_around_typename, .{});
            } else if (p.eatToken(.l_paren)) |l_paren| {
                if (try p.typeName()) |ty| {
                    res.qt = ty;
                    try p.expectClosing(l_paren, .r_paren);
                } else {
                    p.tok_i = expected_paren;
                    res = try p.parseNoEval(unExpr);
                    has_expr = true;
                }
            } else {
                res = try p.parseNoEval(unExpr);
                has_expr = true;
            }
            const operand_qt = res.qt;

            if (res.qt.isInvalid()) {
                res.val = .{};
            } else {
                const base_type = res.qt.base(p.comp);
                switch (base_type.type) {
                    .void => try p.err(tok, .pointer_arith_void, .{"sizeof"}),
                    .pointer => |pointer_ty| if (pointer_ty.decayed) |decayed_qt| {
                        try p.err(tok, .sizeof_array_arg, .{ res.qt, decayed_qt });
                    },
                    else => {},
                }

                if (base_type.qt.sizeofOrNull(p.comp)) |size| {
                    if (size == 0 and p.comp.langopts.emulate == .msvc) {
                        try p.err(tok, .sizeof_returns_zero, .{});
                    }
                    res.val = try Value.int(size, p.comp);
                    res.qt = p.comp.type_store.size;
                } else {
                    res.val = .{};
                    if (res.qt.hasIncompleteSize(p.comp)) {
                        try p.err(expected_paren - 1, .invalid_sizeof, .{res.qt});
                        res.qt = .invalid;
                    } else {
                        res.qt = p.comp.type_store.size;
                    }
                }
            }

            res.node = try p.addNode(.{ .sizeof_expr = .{
                .op_tok = tok,
                .qt = res.qt,
                .expr = if (has_expr) res.node else null,
                .operand_qt = operand_qt,
            } });
            return res;
        },
        .keyword_alignof,
        .keyword_alignof1,
        .keyword_alignof2,
        .keyword_c23_alignof,
        => {
            p.tok_i += 1;
            const expected_paren = p.tok_i;

            var has_expr = false;
            var res: Result = .{
                .node = undefined, // check has_expr
            };
            if (try p.typeName()) |qt| {
                res.qt = qt;
                try p.err(expected_paren, .expected_parens_around_typename, .{});
            } else if (p.eatToken(.l_paren)) |l_paren| {
                if (try p.typeName()) |qt| {
                    res.qt = qt;
                    try p.expectClosing(l_paren, .r_paren);
                } else {
                    p.tok_i = expected_paren;
                    res = try p.parseNoEval(unExpr);
                    has_expr = true;

                    try p.err(expected_paren, .alignof_expr, .{});
                }
            } else {
                res = try p.parseNoEval(unExpr);
                has_expr = true;

                try p.err(expected_paren, .alignof_expr, .{});
            }
            const operand_qt = res.qt;

            if (res.qt.is(p.comp, .void)) {
                try p.err(tok, .pointer_arith_void, .{"alignof"});
            }

            if (res.qt.sizeofOrNull(p.comp) != null) {
                res.val = try Value.int(res.qt.alignof(p.comp), p.comp);
                res.qt = p.comp.type_store.size;
            } else if (!res.qt.isInvalid()) {
                try p.err(expected_paren, .invalid_alignof, .{res.qt});
                res.qt = .invalid;
            }

            res.node = try p.addNode(.{ .alignof_expr = .{
                .op_tok = tok,
                .qt = res.qt,
                .expr = if (has_expr) res.node else null,
                .operand_qt = operand_qt,
            } });
            return res;
        },
        .keyword_extension => {
            p.tok_i += 1;
            const saved_extension = p.extension_suppressed;
            defer p.extension_suppressed = saved_extension;
            p.extension_suppressed = true;

            return try p.expect(castExpr);
        },
        .keyword_imag1, .keyword_imag2 => {
            const imag_tok = p.tok_i;
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            if (operand.qt.isInvalid()) return operand;

            const scalar_kind = operand.qt.scalarKind(p.comp);
            if (!scalar_kind.isArithmetic()) {
                try p.err(imag_tok, .invalid_imag, .{operand.qt});
            }
            if (!scalar_kind.isReal()) {
                operand.val = try operand.val.imaginaryPart(p.comp);
            } else switch (p.comp.langopts.emulate) {
                .msvc => {}, // Doesn't support `_Complex` or `__imag` in the first place
                .gcc => operand.val = .zero,
                .clang => {
                    if (operand.val.is(.int, p.comp) or operand.val.is(.float, p.comp)) {
                        operand.val = .zero;
                    } else {
                        operand.val = .{};
                    }
                },
            }
            // convert _Complex T to T
            operand.qt = operand.qt.toReal(p.comp);
            try operand.un(p, .imag_expr, tok);
            return operand;
        },
        .keyword_real1, .keyword_real2 => {
            const real_tok = p.tok_i;
            p.tok_i += 1;

            var operand = try p.expect(castExpr);
            try operand.lvalConversion(p, tok);
            if (operand.qt.isInvalid()) return operand;
            if (!operand.qt.isInt(p.comp) and !operand.qt.isFloat(p.comp)) {
                try p.err(real_tok, .invalid_real, .{operand.qt});
            }
            // convert _Complex T to T
            operand.qt = operand.qt.toReal(p.comp);
            operand.val = try operand.val.realPart(p.comp);
            try operand.un(p, .real_expr, tok);
            return operand;
        },
        else => {
            var lhs = (try p.compoundLiteral(null, null)) orelse
                (try p.primaryExpr()) orelse
                return null;

            while (try p.suffixExpr(lhs)) |suffix| {
                lhs = suffix;
            }
            return lhs;
        },
    }
}

/// compoundLiteral
///  : '(' storageClassSpec* type_name ')' '{' initializer_list '}'
///  | '(' storageClassSpec* type_name ')' '{' initializer_list ',' '}'
fn compoundLiteral(p: *Parser, qt_opt: ?QualType, opt_l_paren: ?TokenIndex) Error!?Result {
    const l_paren, const d = if (qt_opt) |some| .{ opt_l_paren.?, DeclSpec{ .qt = some } } else blk: {
        const l_paren = p.eatToken(.l_paren) orelse return null;

        var d: DeclSpec = .{ .qt = .invalid };
        const any = if (p.comp.langopts.standard.atLeast(.c23))
            try p.storageClassSpec(&d)
        else
            false;

        switch (d.storage_class) {
            .auto, .@"extern", .typedef => |tok| {
                try p.err(tok, .invalid_compound_literal_storage_class, .{@tagName(d.storage_class)});
                d.storage_class = .none;
            },
            .register => if (p.func.qt == null) try p.err(p.tok_i, .illegal_storage_on_global, .{}),
            else => {},
        }

        d.qt = (try p.typeName()) orelse {
            p.tok_i = l_paren;
            if (any) {
                try p.err(p.tok_i, .expected_type, .{});
                return error.ParsingFailed;
            }
            return null;
        };
        try p.expectClosing(l_paren, .r_paren);
        break :blk .{ l_paren, d };
    };
    var qt = d.qt;

    var incomplete_array_ty = false;
    switch (qt.base(p.comp).type) {
        .func => try p.err(p.tok_i, .func_init, .{}),
        .array => |array_ty| if (array_ty.len == .variable) {
            try p.err(p.tok_i, .vla_init, .{});
        } else {
            incomplete_array_ty = array_ty.len == .incomplete;
        },
        else => if (qt.hasIncompleteSize(p.comp)) {
            try p.err(p.tok_i, .variable_incomplete_ty, .{qt});
            return error.ParsingFailed;
        },
    }

    const init_context = p.init_context;
    defer p.init_context = init_context;
    p.init_context = d.initContext(p);
    var init_list_expr = try p.initializer(qt);
    if (d.constexpr) |_| {
        // TODO error if not constexpr
    }

    if (!incomplete_array_ty) init_list_expr.qt = qt;

    init_list_expr.node = try p.addNode(.{ .compound_literal_expr = .{
        .l_paren_tok = l_paren,
        .storage_class = switch (d.storage_class) {
            .register => .register,
            .static => .static,
            else => .auto,
        },
        .thread_local = d.thread_local != null,
        .initializer = init_list_expr.node,
        .qt = init_list_expr.qt,
    } });
    return init_list_expr;
}

/// suffixExpr
///  : '[' expr ']'
///  | '(' argumentExprList? ')'
///  | '.' IDENTIFIER
///  | '->' IDENTIFIER
///  | '++'
///  | '--'
/// argumentExprList : assignExpr (',' assignExpr)*
fn suffixExpr(p: *Parser, lhs: Result) Error!?Result {
    switch (p.tok_ids[p.tok_i]) {
        .l_paren => return try p.callExpr(lhs),
        .plus_plus => {
            defer p.tok_i += 1;

            var operand = lhs;
            const scalar_kind = operand.qt.scalarKind(p.comp);
            if (scalar_kind == .void_pointer)
                try p.err(p.tok_i, .gnu_pointer_arith, .{});
            if (scalar_kind == .none)
                try p.err(p.tok_i, .invalid_argument_un, .{operand.qt});
            if (!scalar_kind.isReal())
                try p.err(p.tok_i, .complex_prefix_postfix_op, .{operand.qt});

            if (!p.tree.isLval(operand.node) or operand.qt.@"const") {
                try p.err(p.tok_i, .not_assignable, .{});
                return error.ParsingFailed;
            }
            try operand.usualUnaryConversion(p, p.tok_i);

            try operand.un(p, .post_inc_expr, p.tok_i);
            return operand;
        },
        .minus_minus => {
            defer p.tok_i += 1;

            var operand = lhs;
            const scalar_kind = operand.qt.scalarKind(p.comp);
            if (scalar_kind == .void_pointer)
                try p.err(p.tok_i, .gnu_pointer_arith, .{});
            if (scalar_kind == .none)
                try p.err(p.tok_i, .invalid_argument_un, .{operand.qt});
            if (!scalar_kind.isReal())
                try p.err(p.tok_i, .complex_prefix_postfix_op, .{operand.qt});

            if (!p.tree.isLval(operand.node) or operand.qt.@"const") {
                try p.err(p.tok_i, .not_assignable, .{});
                return error.ParsingFailed;
            }
            try operand.usualUnaryConversion(p, p.tok_i);

            try operand.un(p, .post_dec_expr, p.tok_i);
            return operand;
        },
        .l_bracket => {
            const l_bracket = p.tok_i;
            p.tok_i += 1;
            var index = try p.expect(expr);
            try p.expectClosing(l_bracket, .r_bracket);

            const array_before_conversion = lhs;
            const index_before_conversion = index;
            var ptr = lhs;
            try ptr.lvalConversion(p, l_bracket);
            try index.lvalConversion(p, l_bracket);
            if (ptr.qt.get(p.comp, .pointer)) |pointer_ty| {
                ptr.qt = pointer_ty.child;
                if (index.qt.isRealInt(p.comp)) {
                    try p.checkArrayBounds(index_before_conversion, array_before_conversion, l_bracket);
                } else {
                    try p.err(l_bracket, .invalid_index, .{});
                }
            } else if (index.qt.get(p.comp, .pointer)) |pointer_ty| {
                index.qt = pointer_ty.child;
                if (ptr.qt.isRealInt(p.comp)) {
                    try p.checkArrayBounds(array_before_conversion, index_before_conversion, l_bracket);
                } else {
                    try p.err(l_bracket, .invalid_index, .{});
                }
                std.mem.swap(Result, &ptr, &index);
            } else if (ptr.qt.get(p.comp, .vector)) |vector_ty| {
                ptr = array_before_conversion;
                ptr.qt = vector_ty.elem;
                if (!index.qt.isRealInt(p.comp)) {
                    try p.err(l_bracket, .invalid_index, .{});
                }
            } else if (!index.qt.isInvalid() and !ptr.qt.isInvalid()) {
                try p.err(l_bracket, .invalid_subscript, .{});
            }

            try ptr.saveValue(p);
            try index.saveValue(p);
            ptr.node = try p.addNode(.{ .array_access_expr = .{
                .l_bracket_tok = l_bracket,
                .base = ptr.node,
                .index = index.node,
                .qt = ptr.qt,
            } });
            return ptr;
        },
        .period => {
            const period = p.tok_i;
            p.tok_i += 1;
            const name = try p.expectIdentifier();
            return try p.fieldAccess(lhs, name, false, period);
        },
        .arrow => {
            const arrow = p.tok_i;
            p.tok_i += 1;
            const name = try p.expectIdentifier();
            if (lhs.qt.is(p.comp, .array)) {
                var copy = lhs;
                copy.qt = try copy.qt.decay(p.comp);
                try copy.implicitCast(p, .array_to_pointer, arrow);
                return try p.fieldAccess(copy, name, true, arrow);
            }
            return try p.fieldAccess(lhs, name, true, arrow);
        },
        else => return null,
    }
}

fn fieldAccess(
    p: *Parser,
    lhs: Result,
    field_name_tok: TokenIndex,
    is_arrow: bool,
    access_tok: TokenIndex,
) !Result {
    if (lhs.qt.isInvalid()) {
        const access: Node.MemberAccess = .{
            .access_tok = access_tok,
            .qt = .invalid,
            .base = lhs.node,
            .member_index = std.math.maxInt(u32),
        };
        return .{
            .qt = .invalid,
            .node = try p.addNode(if (is_arrow)
                .{ .member_access_ptr_expr = access }
            else
                .{ .member_access_expr = access }),
        };
    }

    const expr_qt = if (lhs.qt.get(p.comp, .atomic)) |atomic| atomic else lhs.qt;
    const is_ptr = expr_qt.isPointer(p.comp);
    const expr_base_qt = if (is_ptr) expr_qt.childType(p.comp) else expr_qt;
    const record_qt = if (expr_base_qt.get(p.comp, .atomic)) |atomic| atomic else expr_base_qt;
    const record_ty = record_qt.getRecord(p.comp) orelse {
        try p.err(field_name_tok, .expected_record_ty, .{expr_qt});
        return error.ParsingFailed;
    };

    if (record_ty.layout == null) {
        // Invalid use of incomplete type, error reported elsewhere.
        if (!is_ptr) return error.ParsingFailed;

        try p.err(field_name_tok - 2, .deref_incomplete_ty_ptr, .{expr_base_qt});
        return error.ParsingFailed;
    }
    if (expr_qt != lhs.qt) try p.err(field_name_tok, .member_expr_atomic, .{lhs.qt});
    if (expr_base_qt != record_qt) try p.err(field_name_tok, .member_expr_atomic, .{expr_base_qt});

    if (is_arrow and !is_ptr) try p.err(field_name_tok, .member_expr_not_ptr, .{expr_qt});
    if (!is_arrow and is_ptr) try p.err(field_name_tok, .member_expr_ptr, .{expr_qt});

    const field_name = try p.comp.internString(p.tokSlice(field_name_tok));
    const result, _ = try p.fieldAccessExtra(lhs.node, record_ty, is_arrow, &.{
        .base_qt = record_qt,
        .target_name = field_name,
        .access_tok = access_tok,
        .name_tok = field_name_tok,
        .check_deprecated = true,
    });
    return result;
}

fn fieldAccessExtra(
    p: *Parser,
    base: Node.Index,
    record_ty: Type.Record,
    is_arrow: bool,
    ctx: *const struct {
        base_qt: QualType,
        target_name: StringId,
        access_tok: TokenIndex,
        name_tok: TokenIndex,
        check_deprecated: bool,
    },
) Error!struct { Result, u64 } {
    for (record_ty.fields, 0..) |field, field_index| {
        if (field.name_tok == 0) if (field.qt.getRecord(p.comp)) |field_record_ty| {
            if (!field_record_ty.hasField(p.comp, ctx.target_name)) continue;

            const access: Node.MemberAccess = .{
                .access_tok = ctx.access_tok,
                .qt = field.qt,
                .base = base,
                .member_index = @intCast(field_index),
            };
            const inner = try p.addNode(if (is_arrow)
                .{ .member_access_ptr_expr = access }
            else
                .{ .member_access_expr = access });

            const ret, const offset_bits = try p.fieldAccessExtra(inner, field_record_ty, false, ctx);
            return .{ ret, offset_bits + field.layout.offset_bits };
        };
        if (ctx.target_name == field.name) {
            if (ctx.check_deprecated) try p.checkDeprecatedUnavailable(field.qt, ctx.name_tok, field.name_tok);

            const access: Node.MemberAccess = .{
                .access_tok = ctx.access_tok,
                .qt = field.qt,
                .base = base,
                .member_index = @intCast(field_index),
            };
            const result_node = try p.addNode(if (is_arrow)
                .{ .member_access_ptr_expr = access }
            else
                .{ .member_access_expr = access });
            return .{ .{ .qt = field.qt, .node = result_node }, field.layout.offset_bits };
        }
    }
    try p.err(ctx.name_tok, .no_such_member, .{ p.tokSlice(ctx.name_tok), ctx.base_qt });
    return error.ParsingFailed;
}

fn checkVaStartArg(p: *Parser, builtin_tok: TokenIndex, first_after: TokenIndex, param_tok: TokenIndex, arg: *Result, idx: u32) !void {
    assert(idx != 0);
    if (idx > 1) {
        try p.err(first_after, .closing_paren, .{});
        return error.ParsingFailed;
    }

    const func_qt = p.func.qt orelse {
        try p.err(builtin_tok, .va_start_not_in_func, .{});
        return;
    };
    const func_ty = func_qt.get(p.comp, .func) orelse return;
    if (func_ty.kind != .variadic or func_ty.params.len == 0) {
        return p.err(builtin_tok, .va_start_fixed_args, .{});
    }
    const last_param_name = func_ty.params[func_ty.params.len - 1].name;
    const decl_ref = p.getNode(arg.node, .decl_ref_expr);
    if (decl_ref == null or last_param_name != try p.comp.internString(p.tokSlice(decl_ref.?.name_tok))) {
        try p.err(param_tok, .va_start_not_last_param, .{});
    }
}

fn checkArithOverflowArg(p: *Parser, builtin_tok: TokenIndex, first_after: TokenIndex, param_tok: TokenIndex, arg: *Result, idx: u32) !void {
    _ = builtin_tok;
    _ = first_after;
    if (idx <= 1) {
        if (!arg.qt.isRealInt(p.comp)) {
            return p.err(param_tok, .overflow_builtin_requires_int, .{arg.qt});
        }
    } else if (idx == 2) {
        if (!arg.qt.isPointer(p.comp)) return p.err(param_tok, .overflow_result_requires_ptr, .{arg.qt});
        const child = arg.qt.childType(p.comp);
        if (child.scalarKind(p.comp) != .int or child.@"const") return p.err(param_tok, .overflow_result_requires_ptr, .{arg.qt});
    }
}

fn checkComplexArg(p: *Parser, builtin_tok: TokenIndex, first_after: TokenIndex, param_tok: TokenIndex, arg: *Result, idx: u32) !void {
    _ = builtin_tok;
    _ = first_after;
    if (idx <= 1 and !arg.qt.isFloat(p.comp)) {
        try p.err(param_tok, .not_floating_type, .{arg.qt});
    } else if (idx == 1) {
        const prev_idx = p.list_buf.items[p.list_buf.items.len - 1];
        const prev_qt = prev_idx.qt(&p.tree);
        if (!prev_qt.eql(arg.qt, p.comp)) {
            try p.err(param_tok, .argument_types_differ, .{ prev_qt, arg.qt });
        }
    }
}

fn checkElementwiseArg(
    p: *Parser,
    param_tok: TokenIndex,
    arg: *Result,
    idx: u32,
    kind: enum { sint_float, float, int, both },
) !void {
    if (idx == 0) {
        const scarlar_qt = if (arg.qt.get(p.comp, .vector)) |vec| vec.elem else arg.qt;
        const sk = scarlar_qt.scalarKind(p.comp);
        switch (kind) {
            .float => if (!sk.isFloat() or !sk.isReal()) {
                try p.err(param_tok, .elementwise_type, .{ " or a floating point type", arg.qt });
            },
            .int => if (!sk.isInt() or !sk.isReal()) {
                try p.err(param_tok, .elementwise_type, .{ " or an integer point type", arg.qt });
            },
            .sint_float => if (!((sk.isInt() and scarlar_qt.signedness(p.comp) == .signed) or sk.isFloat()) or !sk.isReal()) {
                try p.err(param_tok, .elementwise_type, .{ ", a signed integer or a floating point type", arg.qt });
            },
            .both => if (!(sk.isInt() or sk.isFloat()) or !sk.isReal()) {
                try p.err(param_tok, .elementwise_type, .{ ", an integer or a floating point type", arg.qt });
            },
        }
    } else {
        const prev_idx = p.list_buf.items[p.list_buf.items.len - 1];
        const prev_qt = prev_idx.qt(&p.tree);
        arg.coerceExtra(p, prev_qt, param_tok, .{ .arg = null }) catch |er| switch (er) {
            error.CoercionFailed => {
                try p.err(param_tok, .argument_types_differ, .{ prev_qt, arg.qt });
            },
            else => |e| return e,
        };
    }
}

fn checkNonTemporalArg(
    p: *Parser,
    param_tok: TokenIndex,
    arg: *Result,
    idx: u32,
    kind: enum { store, load },
) !void {
    if (kind == .store and idx == 0) return;
    const base_qt = if (arg.qt.get(p.comp, .pointer)) |ptr|
        ptr.child
    else
        return p.err(param_tok, .nontemporal_address_pointer, .{arg.qt});

    const scarlar_qt = if (base_qt.get(p.comp, .vector)) |vec| vec.elem else base_qt;
    const sk = scarlar_qt.scalarKind(p.comp);
    if (!(sk.isInt() or sk.isFloat()) or !sk.isReal() or sk.isPointer()) {
        try p.err(param_tok, .nontemporal_address_type, .{arg.qt});
    }

    if (kind == .store) {
        const prev_idx = p.list_buf.items[p.list_buf.items.len - 1];
        var prev_arg: Result = .{
            .node = prev_idx,
            .qt = prev_idx.qt(&p.tree),
        };
        try prev_arg.coerce(p, base_qt, prev_idx.tok(&p.tree), .{ .arg = null });
        p.list_buf.items[p.list_buf.items.len - 1] = prev_arg.node;
    }
}

fn checkSyncArg(
    p: *Parser,
    param_tok: TokenIndex,
    arg: *Result,
    idx: u32,
    max_count: u8,
) !void {
    if (idx >= max_count) return;
    if (idx == 0) {
        const ptr_ty = arg.qt.get(p.comp, .pointer) orelse
            return p.err(param_tok, .atomic_address_pointer, .{arg.qt});

        const child_sk = ptr_ty.child.scalarKind(p.comp);
        if (!((child_sk.isInt() and child_sk.isReal()) or child_sk.isPointer()))
            return p.err(param_tok, .atomic_address_type, .{arg.qt});
    } else {
        const first_idx = p.list_buf.items[p.list_buf.items.len - idx];
        const ptr_ty = first_idx.qt(&p.tree).get(p.comp, .pointer) orelse return;
        const prev_qt = ptr_ty.child;
        arg.coerceExtra(p, prev_qt, param_tok, .{ .arg = null }) catch |er| switch (er) {
            error.CoercionFailed => {
                try p.err(param_tok, .argument_types_differ, .{ prev_qt, arg.qt });
            },
            else => |e| return e,
        };
    }
}

fn callExpr(p: *Parser, lhs: Result) Error!Result {
    const gpa = p.comp.gpa;
    const l_paren = p.tok_i;
    p.tok_i += 1;

    // We cannot refer to the function type here because the pointer to
    // type_store.extra might get invalidated while parsing args.
    const func_qt, const params_len, const func_kind = blk: {
        var base_qt = lhs.qt;
        if (base_qt.get(p.comp, .pointer)) |pointer_ty| base_qt = pointer_ty.child;
        if (base_qt.isInvalid()) break :blk .{ base_qt, std.math.maxInt(usize), undefined };

        const func_type_qt = base_qt.base(p.comp);
        if (func_type_qt.type != .func) {
            try p.err(l_paren, .not_callable, .{lhs.qt});
            return error.ParsingFailed;
        }
        break :blk .{ func_type_qt.qt, func_type_qt.type.func.params.len, func_type_qt.type.func.kind };
    };

    var func = lhs;
    try func.lvalConversion(p, l_paren);

    const list_buf_top = p.list_buf.items.len;
    defer p.list_buf.items.len = list_buf_top;
    var arg_count: u32 = 0;
    var first_after = l_paren;

    const call_expr = CallExpr.init(p, lhs.node, func.node);

    while (p.eatToken(.r_paren) == null) {
        const param_tok = p.tok_i;
        if (arg_count == params_len) first_after = p.tok_i;
        var arg = try p.expect(assignExpr);

        if (call_expr.shouldPerformLvalConversion(arg_count)) {
            try arg.lvalConversion(p, param_tok);
        }
        if ((arg.qt.hasIncompleteSize(p.comp) and !arg.qt.is(p.comp, .void)) or arg.qt.isInvalid()) return error.ParsingFailed;

        if (arg_count >= params_len) {
            if (call_expr.shouldPromoteVarArg(arg_count)) switch (arg.qt.base(p.comp).type) {
                .int => |int_ty| if (int_ty == .int) try arg.castToInt(p, arg.qt.promoteInt(p.comp), param_tok),
                .float => |float_ty| if (float_ty == .double) try arg.castToFloat(p, .double, param_tok),
                else => {},
            };

            try call_expr.checkVarArg(p, first_after, param_tok, &arg, arg_count);
            try arg.saveValue(p);
            try p.list_buf.append(gpa, arg.node);
            arg_count += 1;

            _ = p.eatToken(.comma) orelse {
                try p.expectClosing(l_paren, .r_paren);
                break;
            };
            continue;
        }

        if (func_qt.get(p.comp, .func)) |func_ty| {
            const param = func_ty.params[arg_count];

            if (param.qt.get(p.comp, .pointer)) |pointer_ty| static_check: {
                const decayed_child_qt = pointer_ty.decayed orelse break :static_check;
                const param_array_ty = decayed_child_qt.get(p.comp, .array).?;
                if (param_array_ty.len != .static) break :static_check;
                const param_array_len = param_array_ty.len.static;
                const arg_array_len = arg.qt.arrayLen(p.comp);

                if (arg_array_len != null and arg_array_len.? < param_array_len) {
                    try p.err(param_tok, .array_argument_too_small, .{ arg_array_len.?, param_array_len });
                    try p.err(param.name_tok, .callee_with_static_array, .{});
                }
                if (arg.val.isZero(p.comp)) {
                    try p.err(param_tok, .non_null_argument, .{});
                    try p.err(param.name_tok, .callee_with_static_array, .{});
                }
            }

            if (call_expr.shouldCoerceArg(arg_count)) {
                try arg.coerce(p, param.qt, param_tok, .{ .arg = param.name_tok });
            }
        }
        try arg.saveValue(p);
        try p.list_buf.append(gpa, arg.node);
        arg_count += 1;

        _ = p.eatToken(.comma) orelse {
            try p.expectClosing(l_paren, .r_paren);
            break;
        };
    }
    if (func_qt.isInvalid()) {
        // Skip argument count checks.
        return try call_expr.finish(p, func_qt, list_buf_top, l_paren);
    }

    if (call_expr.paramCountOverride()) |expected| {
        if (expected != arg_count) {
            try p.err(first_after, .expected_arguments, .{ expected, arg_count });
        }
    } else switch (func_kind) {
        .normal => if (params_len != arg_count) {
            try p.err(first_after, .expected_arguments, .{ params_len, arg_count });
        },
        .variadic => if (arg_count < params_len) {
            try p.err(first_after, .expected_at_least_arguments, .{ params_len, arg_count });
        },
        .old_style => if (params_len != arg_count) {
            if (params_len == 0)
                try p.err(first_after, .passing_args_to_kr, .{})
            else
                try p.err(first_after, .expected_arguments_old, .{ params_len, arg_count });
        },
    }

    return try call_expr.finish(p, func_qt, list_buf_top, l_paren);
}

fn checkArrayBounds(p: *Parser, index: Result, array: Result, tok: TokenIndex) !void {
    if (index.val.opt_ref == .none) return;

    const array_len = array.qt.arrayLen(p.comp) orelse return;
    if (array_len == 0) return;

    if (array_len == 1) {
        if (p.getNode(array.node, .member_access_expr) orelse p.getNode(array.node, .member_access_ptr_expr)) |access| {
            var base_ty = access.base.qt(&p.tree);
            if (base_ty.get(p.comp, .pointer)) |pointer_ty| {
                base_ty = pointer_ty.child;
            }
            if (base_ty.getRecord(p.comp)) |record_ty| {
                if (access.member_index + 1 == record_ty.fields.len) {
                    if (!index.val.isZero(p.comp)) {
                        try p.err(tok, .old_style_flexible_struct, .{index});
                    }
                    return;
                }
            }
        }
    }
    const index_int = index.val.toInt(u64, p.comp) orelse std.math.maxInt(u64);
    if (index.qt.signedness(p.comp) == .unsigned) {
        if (index_int >= array_len) {
            try p.err(tok, .array_after, .{index});
        }
    } else {
        if (index.val.compare(.lt, .zero, p.comp)) {
            try p.err(tok, .array_before, .{index});
        } else if (index_int >= array_len) {
            try p.err(tok, .array_after, .{index});
        }
    }
}

/// primaryExpr
///  : IDENTIFIER
///  | keyword_true
///  | keyword_false
///  | keyword_nullptr
///  | INTEGER_LITERAL
///  | FLOAT_LITERAL
///  | IMAGINARY_LITERAL
///  | CHAR_LITERAL
///  | STRING_LITERAL
///  | '(' expr ')'
///  | genericSelection
///  | shufflevector
///  | convertvector
///  | typesCompatible
///  | chooseExpr
///  | vaStart
///  | offsetof
fn primaryExpr(p: *Parser) Error!?Result {
    if (p.eatToken(.l_paren)) |l_paren| {
        var grouped_expr = try p.expect(expr);
        try p.expectClosing(l_paren, .r_paren);
        try grouped_expr.un(p, .paren_expr, l_paren);
        return grouped_expr;
    }

    const gpa = p.comp.gpa;
    switch (p.tok_ids[p.tok_i]) {
        .identifier, .extended_identifier => {
            const name_tok = try p.expectIdentifier();
            const name = p.tokSlice(name_tok);
            const interned_name = try p.comp.internString(name);
            if (interned_name == p.auto_type_decl_name) {
                try p.err(name_tok, .auto_type_self_initialized, .{name});
                return error.ParsingFailed;
            }

            if (p.syms.findSymbol(interned_name)) |sym| {
                if (sym.kind == .typedef) {
                    try p.err(name_tok, .unexpected_type_name, .{name});
                    return error.ParsingFailed;
                }
                if (sym.out_of_scope) {
                    try p.err(name_tok, .out_of_scope_use, .{name});
                    try p.err(sym.tok, .previous_definition, .{});
                }
                try p.checkDeprecatedUnavailable(sym.qt, name_tok, sym.tok);
                if (sym.kind == .constexpr) {
                    return .{
                        .val = sym.val,
                        .qt = sym.qt,
                        .node = try p.addNode(.{
                            .decl_ref_expr = .{
                                .name_tok = name_tok,
                                .qt = sym.qt,
                                .decl = sym.node.unpack().?,
                            },
                        }),
                    };
                }
                if (sym.val.is(.int, p.comp)) {
                    switch (p.const_decl_folding) {
                        .gnu_folding_extension => try p.err(name_tok, .const_decl_folded, .{}),
                        .gnu_vla_folding_extension => try p.err(name_tok, .const_decl_folded_vla, .{}),
                        else => {},
                    }
                }

                const node = try p.addNode(if (sym.kind == .enumeration)
                    .{ .enumeration_ref = .{
                        .name_tok = name_tok,
                        .qt = sym.qt,
                        .decl = sym.node.unpack().?,
                    } }
                else
                    .{ .decl_ref_expr = .{
                        .name_tok = name_tok,
                        .qt = sym.qt,
                        .decl = sym.node.unpack().?,
                    } });

                const res: Result = .{
                    .val = if (p.const_decl_folding == .no_const_decl_folding and sym.kind != .enumeration) Value{} else sym.val,
                    .qt = sym.qt,
                    .node = node,
                };
                try res.putValue(p);
                return res;
            }

            // Check if this is a builtin call.
            if (try p.comp.builtins.getOrCreate(p.comp, name)) |some| {
                for (p.tok_ids[p.tok_i..]) |id| switch (id) {
                    .r_paren => {}, // closing grouped expr
                    .l_paren => break, // beginning of a call
                    else => {
                        try p.err(name_tok, .builtin_must_be_called, .{});
                        return error.ParsingFailed;
                    },
                };
                if (some.header != .none) {
                    try p.err(name_tok, .implicit_builtin, .{name});
                    try p.err(name_tok, .implicit_builtin_header_note, .{
                        @tagName(some.header), name,
                    });
                }

                switch (some.tag) {
                    .common => |tag| switch (tag) {
                        .__builtin_choose_expr => return try p.builtinChooseExpr(),
                        .__builtin_va_arg => return try p.builtinVaArg(name_tok),
                        .__builtin_offsetof => return try p.builtinOffsetof(name_tok, .bytes),
                        .__builtin_bitoffsetof => return try p.builtinOffsetof(name_tok, .bits),
                        .__builtin_types_compatible_p => return try p.typesCompatible(name_tok),
                        .__builtin_convertvector => return try p.convertvector(name_tok),
                        .__builtin_shufflevector => return try p.shufflevector(name_tok),
                        .__builtin_bit_cast => return try p.builtinBitCast(name_tok),
                        else => {},
                    },
                    else => {},
                }

                return .{
                    .qt = some.qt,
                    .node = try p.addNode(.{
                        .builtin_ref = .{
                            .name_tok = name_tok,
                            .qt = some.qt,
                        },
                    }),
                };
            }

            // Check for unknown builtin or implicit function declaration.
            if (p.tok_ids[p.tok_i] == .l_paren and !p.comp.langopts.standard.atLeast(.c23)) {
                // allow implicitly declaring functions before C99 like `puts("foo")`
                if (mem.startsWith(u8, name, "__builtin_"))
                    try p.err(name_tok, .unknown_builtin, .{name})
                else
                    try p.err(name_tok, .implicit_func_decl, .{name});

                const func_qt = try p.comp.type_store.put(gpa, .{ .func = .{
                    .return_type = .int,
                    .kind = .old_style,
                    .params = &.{},
                } });
                const node = try p.addNode(.{
                    .function = .{
                        .name_tok = name_tok,
                        .qt = func_qt,
                        .static = false,
                        .@"inline" = false,
                        .definition = null,
                        .body = null,
                    },
                });

                try p.decl_buf.append(gpa, node);
                try p.syms.declareSymbol(p, interned_name, func_qt, name_tok, node);

                return .{
                    .qt = func_qt,
                    .node = try p.addNode(.{
                        .decl_ref_expr = .{
                            .name_tok = name_tok,
                            .qt = func_qt,
                            .decl = node,
                        },
                    }),
                };
            }

            try p.err(name_tok, .undeclared_identifier, .{p.tokSlice(name_tok)});
            return error.ParsingFailed;
        },
        .keyword_true, .keyword_false => |id| {
            const tok_i = p.tok_i;
            p.tok_i += 1;
            const res: Result = .{
                .val = .fromBool(id == .keyword_true),
                .qt = .bool,
                .node = try p.addNode(.{
                    .bool_literal = .{
                        .qt = .bool,
                        .literal_tok = tok_i,
                    },
                }),
            };
            std.debug.assert(!p.in_macro); // Should have been replaced with .one / .zero
            try res.putValue(p);
            return res;
        },
        .keyword_nullptr => {
            defer p.tok_i += 1;
            try p.err(p.tok_i, .pre_c23_compat, .{"'nullptr'"});
            return .{
                .val = .null,
                .qt = .nullptr_t,
                .node = try p.addNode(.{
                    .nullptr_literal = .{
                        .qt = .nullptr_t,
                        .literal_tok = p.tok_i,
                    },
                }),
            };
        },
        .macro_func, .macro_function => {
            defer p.tok_i += 1;
            var ty: QualType = undefined;
            var tok = p.tok_i;

            if (p.func.ident) |some| {
                ty = some.qt;
                tok = some.node.get(&p.tree).variable.name_tok;
            } else if (p.func.qt) |_| {
                const strings_top = p.strings.items.len;
                defer p.strings.items.len = strings_top;

                const name = p.tokSlice(p.func.name);
                try p.strings.ensureUnusedCapacity(gpa, name.len + 1);

                p.strings.appendSliceAssumeCapacity(name);
                p.strings.appendAssumeCapacity(0);
                const predef = try p.makePredefinedIdentifier(p.strings.items[strings_top..]);
                ty = predef.qt;
                p.func.ident = predef;
            } else {
                const predef = try p.makePredefinedIdentifier("\x00");
                ty = predef.qt;
                p.func.ident = predef;
                try p.decl_buf.append(gpa, predef.node);
            }
            if (p.func.qt == null) try p.err(p.tok_i, .predefined_top_level, .{});

            return .{
                .qt = ty,
                .node = try p.addNode(.{
                    .decl_ref_expr = .{
                        .name_tok = tok,
                        .qt = ty,
                        .decl = p.func.ident.?.node,
                    },
                }),
            };
        },
        .macro_pretty_func => {
            defer p.tok_i += 1;
            var qt: QualType = undefined;
            if (p.func.pretty_ident) |some| {
                qt = some.qt;
            } else if (p.func.qt) |func_qt| {
                var sf = std.heap.stackFallback(1024, gpa);
                var allocating: std.Io.Writer.Allocating = .init(sf.get());
                defer allocating.deinit();

                func_qt.printNamed(p.tokSlice(p.func.name), p.comp, &allocating.writer) catch return error.OutOfMemory;
                allocating.writer.writeByte(0) catch return error.OutOfMemory;

                const predef = try p.makePredefinedIdentifier(allocating.written());
                qt = predef.qt;
                p.func.pretty_ident = predef;
            } else {
                const predef = try p.makePredefinedIdentifier("top level\x00");
                qt = predef.qt;
                p.func.pretty_ident = predef;
                try p.decl_buf.append(gpa, predef.node);
            }
            if (p.func.qt == null) try p.err(p.tok_i, .predefined_top_level, .{});
            return .{
                .qt = qt,
                .node = try p.addNode(.{
                    .decl_ref_expr = .{
                        .name_tok = p.tok_i,
                        .qt = qt,
                        .decl = p.func.pretty_ident.?.node,
                    },
                }),
            };
        },
        .string_literal,
        .string_literal_utf_16,
        .string_literal_utf_8,
        .string_literal_utf_32,
        .string_literal_wide,
        .unterminated_string_literal,
        => return try p.stringLiteral(),
        .char_literal,
        .char_literal_utf_8,
        .char_literal_utf_16,
        .char_literal_utf_32,
        .char_literal_wide,
        .empty_char_literal,
        .unterminated_char_literal,
        => return try p.charLiteral(),
        .zero => {
            defer p.tok_i += 1;
            const int_qt: QualType = if (p.in_macro) p.comp.type_store.intmax else .int;
            const res: Result = .{
                .val = .zero,
                .qt = int_qt,
                .node = try p.addNode(.{ .int_literal = .{ .qt = int_qt, .literal_tok = p.tok_i } }),
            };
            try res.putValue(p);
            return res;
        },
        .one => {
            defer p.tok_i += 1;
            const int_qt: QualType = if (p.in_macro) p.comp.type_store.intmax else .int;
            const res: Result = .{
                .val = .one,
                .qt = int_qt,
                .node = try p.addNode(.{ .int_literal = .{ .qt = int_qt, .literal_tok = p.tok_i } }),
            };
            try res.putValue(p);
            return res;
        },
        .pp_num => return try p.ppNum(),
        .embed_byte => {
            assert(!p.in_macro);
            const loc = p.pp.tokens.items(.loc)[p.tok_i];
            defer p.tok_i += 1;
            const buf = p.comp.getSource(.generated).buf[loc.byte_offset..];
            var byte: u8 = buf[0] - '0';
            for (buf[1..]) |c| {
                if (!std.ascii.isDigit(c)) break;
                byte *= 10;
                byte += c - '0';
            }
            const res: Result = .{
                .val = try Value.int(byte, p.comp),
                .qt = .int,
                .node = try p.addNode(.{ .int_literal = .{ .qt = .int, .literal_tok = p.tok_i } }),
            };
            try res.putValue(p);
            return res;
        },
        .keyword_generic => return p.genericSelection(),
        else => return null,
    }
}

fn makePredefinedIdentifier(p: *Parser, slice: []const u8) !Result {
    const gpa = p.comp.gpa;
    const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
        .elem = .{ .@"const" = true, ._index = .int_char },
        .len = .{ .fixed = slice.len },
    } });

    const val = try Value.intern(p.comp, .{ .bytes = slice });

    const str_lit = try p.addNode(.{ .string_literal_expr = .{ .qt = array_qt, .literal_tok = p.tok_i, .kind = .ascii } });
    if (!p.in_macro) try p.tree.value_map.put(gpa, str_lit, val);

    return .{ .qt = array_qt, .node = try p.addNode(.{
        .variable = .{
            .name_tok = p.tok_i,
            .qt = array_qt,
            .storage_class = .static,
            .thread_local = false,
            .implicit = true,
            .initializer = str_lit,
            .definition = null,
        },
    }) };
}

fn stringLiteral(p: *Parser) Error!Result {
    const gpa = p.comp.gpa;
    const string_start = p.tok_i;
    var string_end = p.tok_i;
    var string_kind: text_literal.Kind = .char;
    while (text_literal.Kind.classify(p.tok_ids[string_end], .string_literal)) |next| : (string_end += 1) {
        string_kind = string_kind.concat(next) catch {
            try p.err(string_end, .unsupported_str_cat, .{});
            while (p.tok_ids[p.tok_i].isStringLiteral()) : (p.tok_i += 1) {}
            return error.ParsingFailed;
        };
        if (string_kind == .unterminated) {
            // Diagnostic issued in preprocessor.
            p.tok_i = string_end + 1;
            return error.ParsingFailed;
        }
    }
    const count = string_end - p.tok_i;
    assert(count > 0);

    const char_width = string_kind.charUnitSize(p.comp);

    const strings_top = p.strings.items.len;
    defer p.strings.items.len = strings_top;

    const literal_start = mem.alignForward(usize, strings_top, @intFromEnum(char_width));
    try p.strings.resize(gpa, literal_start);

    while (p.tok_i < string_end) : (p.tok_i += 1) {
        const this_kind = text_literal.Kind.classify(p.tok_ids[p.tok_i], .string_literal).?;
        const slice = this_kind.contentSlice(p.tokSlice(p.tok_i));
        var char_literal_parser: text_literal.Parser = .{
            .comp = p.comp,
            .literal = slice,
            .kind = this_kind,
            .max_codepoint = 0x10ffff,
            .loc = p.pp.tokens.items(.loc)[p.tok_i],
            .expansion_locs = p.pp.expansionSlice(p.tok_i),
            .incorrect_encoding_is_error = count > 1,
        };

        try p.strings.ensureUnusedCapacity(gpa, (slice.len + 1) * @intFromEnum(char_width)); // +1 for null terminator
        while (try char_literal_parser.next()) |item| switch (item) {
            .value => |v| {
                switch (char_width) {
                    .@"1" => p.strings.appendAssumeCapacity(@intCast(v)),
                    .@"2" => {
                        const word: u16 = @intCast(v);
                        p.strings.appendSliceAssumeCapacity(mem.asBytes(&word));
                    },
                    .@"4" => p.strings.appendSliceAssumeCapacity(mem.asBytes(&v)),
                }
            },
            .codepoint => |c| {
                switch (char_width) {
                    .@"1" => {
                        var buf: [4]u8 = undefined;
                        const written = std.unicode.utf8Encode(c, &buf) catch unreachable;
                        const encoded = buf[0..written];
                        p.strings.appendSliceAssumeCapacity(encoded);
                    },
                    .@"2" => {
                        var utf16_buf: [2]u16 = undefined;
                        var utf8_buf: [4]u8 = undefined;
                        const utf8_written = std.unicode.utf8Encode(c, &utf8_buf) catch unreachable;
                        const utf16_written = std.unicode.utf8ToUtf16Le(&utf16_buf, utf8_buf[0..utf8_written]) catch unreachable;
                        const bytes = std.mem.sliceAsBytes(utf16_buf[0..utf16_written]);
                        p.strings.appendSliceAssumeCapacity(bytes);
                    },
                    .@"4" => {
                        const val: u32 = c;
                        p.strings.appendSliceAssumeCapacity(mem.asBytes(&val));
                    },
                }
            },
            .improperly_encoded => |bytes| {
                if (count > 1) {
                    return error.ParsingFailed;
                }
                p.strings.appendSliceAssumeCapacity(bytes);
            },
            .utf8_text => |view| {
                switch (char_width) {
                    .@"1" => p.strings.appendSliceAssumeCapacity(view.bytes),
                    .@"2" => {
                        const capacity_slice: []align(@alignOf(u16)) u8 = @alignCast(p.strings.allocatedSlice()[literal_start..]);
                        const dest_len = std.mem.alignBackward(usize, capacity_slice.len, 2);
                        const dest = std.mem.bytesAsSlice(u16, capacity_slice[0..dest_len]);
                        const words_written = std.unicode.utf8ToUtf16Le(dest, view.bytes) catch unreachable;
                        p.strings.resize(gpa, p.strings.items.len + words_written * 2) catch unreachable;
                    },
                    .@"4" => {
                        var it = view.iterator();
                        while (it.nextCodepoint()) |codepoint| {
                            const val: u32 = codepoint;
                            p.strings.appendSliceAssumeCapacity(mem.asBytes(&val));
                        }
                    },
                }
            },
        };
    }
    p.strings.appendNTimesAssumeCapacity(0, @intFromEnum(char_width));
    const slice = p.strings.items[literal_start..];

    // TODO this won't do anything if there is a cache hit
    const interned_align = mem.alignForward(
        usize,
        p.comp.interner.strings.items.len,
        string_kind.internalStorageAlignment(p.comp),
    );
    try p.comp.interner.strings.resize(gpa, interned_align);

    const val = try Value.intern(p.comp, .{ .bytes = slice });

    const array_qt = try p.comp.type_store.put(gpa, .{ .array = .{
        .elem = string_kind.elementType(p.comp),
        .len = .{ .fixed = @divExact(slice.len, @intFromEnum(char_width)) },
    } });
    const res: Result = .{
        .qt = array_qt,
        .val = val,
        .node = try p.addNode(.{ .string_literal_expr = .{
            .literal_tok = string_start,
            .qt = array_qt,
            .kind = switch (string_kind) {
                .char, .unterminated => .ascii,
                .wide => .wide,
                .utf_8 => .utf8,
                .utf_16 => .utf16,
                .utf_32 => .utf32,
            },
        } }),
    };
    try res.putValue(p);
    return res;
}

fn charLiteral(p: *Parser) Error!?Result {
    defer p.tok_i += 1;
    const tok_id = p.tok_ids[p.tok_i];
    const char_kind = text_literal.Kind.classify(tok_id, .char_literal) orelse {
        if (tok_id == .empty_char_literal) {
            try p.err(p.tok_i, .empty_char_literal_error, .{});
        } else if (tok_id == .unterminated_char_literal) {
            try p.err(p.tok_i, .unterminated_char_literal_error, .{});
        } else unreachable;
        return .{
            .qt = .int,
            .val = .zero,
            .node = try p.addNode(.{ .char_literal = .{ .qt = .int, .literal_tok = p.tok_i, .kind = .ascii } }),
        };
    };
    if (char_kind == .utf_8) try p.err(p.tok_i, .u8_char_lit, .{});
    var val: u32 = 0;

    const gpa = p.comp.gpa;
    const slice = char_kind.contentSlice(p.tokSlice(p.tok_i));

    var is_multichar = false;
    if (slice.len == 1 and std.ascii.isAscii(slice[0])) {
        // fast path: single unescaped ASCII char
        val = slice[0];
    } else {
        const max_codepoint = char_kind.maxCodepoint(p.comp);
        var char_literal_parser: text_literal.Parser = .{
            .comp = p.comp,
            .literal = slice,
            .kind = char_kind,
            .max_codepoint = max_codepoint,
            .loc = p.pp.tokens.items(.loc)[p.tok_i],
            .expansion_locs = p.pp.expansionSlice(p.tok_i),
        };

        const max_chars_expected = 4;
        var sf = std.heap.stackFallback(max_chars_expected * @sizeOf(u32), gpa);
        const allocator = sf.get();
        var chars: std.ArrayList(u32) = .empty;
        defer chars.deinit(allocator);

        chars.ensureUnusedCapacity(allocator, max_chars_expected) catch unreachable; // stack allocation already succeeded

        while (try char_literal_parser.next()) |item| switch (item) {
            .value => |v| try chars.append(allocator, v),
            .codepoint => |c| try chars.append(allocator, c),
            .improperly_encoded => |s| {
                try chars.ensureUnusedCapacity(allocator, s.len);
                for (s) |c| chars.appendAssumeCapacity(c);
            },
            .utf8_text => |view| {
                var it = view.iterator();
                var max_codepoint_seen: u21 = 0;
                try chars.ensureUnusedCapacity(allocator, view.bytes.len);
                while (it.nextCodepoint()) |c| {
                    max_codepoint_seen = @max(max_codepoint_seen, c);
                    chars.appendAssumeCapacity(c);
                }
                if (max_codepoint_seen > max_codepoint) {
                    try char_literal_parser.err(.char_too_large, .{});
                }
            },
        };

        is_multichar = chars.items.len > 1;
        if (is_multichar) {
            if (char_kind == .char and chars.items.len == 4) {
                try char_literal_parser.warn(.four_char_char_literal, .{});
            } else if (char_kind == .char) {
                try char_literal_parser.warn(.multichar_literal_warning, .{});
            } else {
                const kind: []const u8 = switch (char_kind) {
                    .wide => "wide",
                    .utf_8, .utf_16, .utf_32 => "Unicode",
                    else => unreachable,
                };
                try char_literal_parser.err(.invalid_multichar_literal, .{kind});
            }
        }

        var multichar_overflow = false;
        if (char_kind == .char and is_multichar) {
            for (chars.items) |item| {
                val, const overflowed = @shlWithOverflow(val, 8);
                multichar_overflow = multichar_overflow or overflowed != 0;
                val += @as(u8, @truncate(item));
            }
        } else if (chars.items.len > 0) {
            val = chars.items[chars.items.len - 1];
        }

        if (multichar_overflow) {
            try char_literal_parser.err(.char_lit_too_wide, .{});
        }
    }

    const char_literal_qt = char_kind.charLiteralType(p.comp);
    // This is the type the literal will have if we're in a macro; macros always operate on intmax_t/uintmax_t values
    const macro_qt = if (char_literal_qt.signedness(p.comp) == .unsigned or
        (char_kind == .char and p.comp.getCharSignedness() == .unsigned))
        try p.comp.type_store.intmax.makeIntUnsigned(p.comp)
    else
        p.comp.type_store.intmax;

    var value = try Value.int(val, p.comp);
    // C99 6.4.4.4.10
    // > If an integer character constant contains a single character or escape sequence,
    // > its value is the one that results when an object with type char whose value is
    // > that of the single character or escape sequence is converted to type int.
    // This conversion only matters if `char` is signed and has a high-order bit of `1`
    if (char_kind == .char and !is_multichar and val > 0x7F and p.comp.getCharSignedness() == .signed) {
        _ = try value.intCast(.char, p.comp);
    }

    const res: Result = .{
        .qt = if (p.in_macro) macro_qt else char_literal_qt,
        .val = value,
        .node = try p.addNode(.{ .char_literal = .{
            .qt = char_literal_qt,
            .literal_tok = p.tok_i,
            .kind = switch (char_kind) {
                .char, .unterminated => .ascii,
                .wide => .wide,
                .utf_8 => .utf8,
                .utf_16 => .utf16,
                .utf_32 => .utf32,
            },
        } }),
    };
    if (!p.in_macro) try p.tree.value_map.put(gpa, res.node, res.val);
    return res;
}

fn parseFloat(p: *Parser, buf: []const u8, suffix: NumberSuffix, tok_i: TokenIndex) !Result {
    const qt: QualType = switch (suffix) {
        .None, .I => .double,
        .F, .IF => .float,
        .F16, .IF16 => .float16,
        .BF16 => .bf16,
        .L, .IL => .long_double,
        .W, .IW => p.comp.float80Type().?,
        .Q, .IQ, .F128, .IF128 => .float128,
        .F32, .IF32 => .float32,
        .F64, .IF64 => .float64,
        .F32x, .IF32x => .float32x,
        .F64x, .IF64x => .float64x,
        .D32 => .dfloat32,
        .D64 => .dfloat64,
        .D128 => .dfloat128,
        .D64x => .dfloat64x,
        else => unreachable,
    };
    const val = try Value.intern(p.comp, key: {
        try p.strings.ensureUnusedCapacity(p.comp.gpa, buf.len);

        const strings_top = p.strings.items.len;
        defer p.strings.items.len = strings_top;
        for (buf) |c| {
            if (c != '\'') p.strings.appendAssumeCapacity(c);
        }

        const float = std.fmt.parseFloat(f128, p.strings.items[strings_top..]) catch unreachable;
        break :key switch (qt.bitSizeof(p.comp)) {
            16 => .{ .float = .{ .f16 = @floatCast(float) } },
            32 => .{ .float = .{ .f32 = @floatCast(float) } },
            64 => .{ .float = .{ .f64 = @floatCast(float) } },
            80 => .{ .float = .{ .f80 = @floatCast(float) } },
            128 => .{ .float = .{ .f128 = @floatCast(float) } },
            else => unreachable,
        };
    });
    var res = Result{
        .qt = qt,
        .node = try p.addNode(.{ .float_literal = .{ .qt = qt, .literal_tok = tok_i } }),
        .val = val,
    };
    if (suffix.isImaginary()) {
        try p.err(p.tok_i, .gnu_imaginary_constant, .{});
        res.qt = try qt.toComplex(p.comp);

        res.val = try Value.intern(p.comp, switch (res.qt.bitSizeof(p.comp)) {
            32 => .{ .complex = .{ .cf16 = .{ 0.0, val.toFloat(f16, p.comp) } } },
            64 => .{ .complex = .{ .cf32 = .{ 0.0, val.toFloat(f32, p.comp) } } },
            128 => .{ .complex = .{ .cf64 = .{ 0.0, val.toFloat(f64, p.comp) } } },
            160 => .{ .complex = .{ .cf80 = .{ 0.0, val.toFloat(f80, p.comp) } } },
            256 => .{ .complex = .{ .cf128 = .{ 0.0, val.toFloat(f128, p.comp) } } },
            else => unreachable,
        });
        try res.un(p, .imaginary_literal, tok_i);
    }
    return res;
}

fn getIntegerPart(p: *Parser, buf: []const u8, prefix: NumberPrefix, tok_i: TokenIndex) ![]const u8 {
    if (buf[0] == '.') return "";

    if (!prefix.digitAllowed(buf[0])) {
        switch (prefix) {
            .binary => try p.err(tok_i, .invalid_binary_digit, .{text_literal.Ascii.init(buf[0])}),
            .octal => try p.err(tok_i, .invalid_octal_digit, .{text_literal.Ascii.init(buf[0])}),
            .hex => try p.err(tok_i, .invalid_int_suffix, .{buf}),
            .decimal => unreachable,
        }
        return error.ParsingFailed;
    }

    for (buf, 0..) |c, idx| {
        if (idx == 0) continue;
        switch (c) {
            '.' => return buf[0..idx],
            'p', 'P' => return if (prefix == .hex) buf[0..idx] else {
                try p.err(tok_i, .invalid_int_suffix, .{buf[idx..]});
                return error.ParsingFailed;
            },
            'e', 'E' => {
                switch (prefix) {
                    .hex => continue,
                    .decimal => return buf[0..idx],
                    .binary => try p.err(tok_i, .invalid_binary_digit, .{text_literal.Ascii.init(c)}),
                    .octal => try p.err(tok_i, .invalid_octal_digit, .{text_literal.Ascii.init(c)}),
                }
                return error.ParsingFailed;
            },
            '0'...'9', 'a'...'d', 'A'...'D', 'f', 'F' => {
                if (!prefix.digitAllowed(c)) {
                    switch (prefix) {
                        .binary => try p.err(tok_i, .invalid_binary_digit, .{text_literal.Ascii.init(c)}),
                        .octal => try p.err(tok_i, .invalid_octal_digit, .{text_literal.Ascii.init(c)}),
                        .decimal, .hex => try p.err(tok_i, .invalid_int_suffix, .{buf[idx..]}),
                    }
                    return error.ParsingFailed;
                }
            },
            '\'' => {},
            else => return buf[0..idx],
        }
    }
    return buf;
}

fn fixedSizeInt(p: *Parser, base: u8, buf: []const u8, suffix: NumberSuffix, tok_i: TokenIndex) !Result {
    var val: u64 = 0;
    var overflow = false;
    for (buf) |c| {
        const digit: u64 = switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            '\'' => continue,
            else => unreachable,
        };

        if (val != 0) {
            const product, const overflowed = @mulWithOverflow(val, base);
            if (overflowed != 0) {
                overflow = true;
            }
            val = product;
        }
        const sum, const overflowed = @addWithOverflow(val, digit);
        if (overflowed != 0) overflow = true;
        val = sum;
    }
    var res: Result = .{
        .val = try Value.int(val, p.comp),
        .node = undefined, // set later
    };
    if (overflow) {
        try p.err(tok_i, .int_literal_too_big, .{});
        res.qt = .ulong_long;
        res.node = try p.addNode(.{ .int_literal = .{ .qt = res.qt, .literal_tok = tok_i } });
        try res.putValue(p);
        return res;
    }
    const interned_val = try Value.int(val, p.comp);
    if (suffix.isSignedInteger() and base == 10) {
        const max_int = try Value.maxInt(p.comp.type_store.intmax, p.comp);
        if (interned_val.compare(.gt, max_int, p.comp)) {
            try p.err(tok_i, .implicitly_unsigned_literal, .{});
        }
    }

    const qts: []const QualType = if (suffix.signedness() == .unsigned)
        &.{ .uint, .ulong, .ulong_long }
    else if (base == 10)
        &.{ .int, .long, .long_long }
    else
        &.{ .int, .uint, .long, .ulong, .long_long, .ulong_long };

    const suffix_qt: QualType = switch (suffix) {
        .None, .I => .int,
        .U, .IU => .uint,
        .UL, .IUL => .ulong,
        .ULL, .IULL => .ulong_long,
        .L, .IL => .long,
        .LL, .ILL => .long_long,
        else => unreachable,
    };

    for (qts) |qt| {
        res.qt = qt;
        if (res.qt.intRankOrder(suffix_qt, p.comp).compare(.lt)) continue;
        const max_int = try Value.maxInt(res.qt, p.comp);
        if (interned_val.compare(.lte, max_int, p.comp)) break;
    } else {
        if (p.comp.langopts.emulate == .gcc) {
            if (p.comp.target.hasInt128()) {
                res.qt = .int128;
            } else {
                res.qt = .long_long;
            }
        } else {
            res.qt = .ulong_long;
        }
    }

    res.node = try p.addNode(.{ .int_literal = .{ .qt = res.qt, .literal_tok = tok_i } });
    try res.putValue(p);
    return res;
}

fn parseInt(p: *Parser, prefix: NumberPrefix, buf: []const u8, suffix: NumberSuffix, tok_i: TokenIndex) !Result {
    if (prefix == .binary) {
        try p.err(tok_i, .binary_integer_literal, .{});
    }
    const base = @intFromEnum(prefix);
    var res = if (suffix.isBitInt())
        try p.bitInt(base, buf, suffix, tok_i)
    else
        try p.fixedSizeInt(base, buf, suffix, tok_i);

    if (suffix.isImaginary()) {
        try p.err(tok_i, .gnu_imaginary_constant, .{});
        res.qt = try res.qt.toComplex(p.comp);
        res.val = .{};
        try res.un(p, .imaginary_literal, tok_i);
    }
    return res;
}

fn bitInt(p: *Parser, base: u8, buf: []const u8, suffix: NumberSuffix, tok_i: TokenIndex) Error!Result {
    const gpa = p.comp.gpa;
    try p.err(tok_i, .pre_c23_compat, .{"'_BitInt' suffix for literals"});
    try p.err(tok_i, .bitint_suffix, .{});

    var managed = try big.int.Managed.init(gpa);
    defer managed.deinit();

    {
        try p.strings.ensureUnusedCapacity(gpa, buf.len);

        const strings_top = p.strings.items.len;
        defer p.strings.items.len = strings_top;
        for (buf) |c| {
            if (c != '\'') p.strings.appendAssumeCapacity(c);
        }

        managed.setString(base, p.strings.items[strings_top..]) catch |e| switch (e) {
            error.InvalidBase => unreachable, // `base` is one of 2, 8, 10, 16
            error.InvalidCharacter => unreachable, // digits validated by Tokenizer
            else => |er| return er,
        };
    }
    const c = managed.toConst();
    const bits_needed: std.math.IntFittingRange(0, Compilation.bit_int_max_bits) = blk: {
        // Literal `0` requires at least 1 bit
        const count = @max(1, c.bitCountTwosComp());
        // The wb suffix results in a _BitInt that includes space for the sign bit even if the
        // value of the constant is positive or was specified in hexadecimal or octal notation.
        const sign_bits = @intFromBool(suffix.isSignedInteger());
        const bits_needed = count + sign_bits;
        break :blk @intCast(bits_needed);
    };

    const int_qt = try p.comp.type_store.put(gpa, .{ .bit_int = .{
        .bits = bits_needed,
        .signedness = suffix.signedness(),
    } });
    const res: Result = .{
        .val = try Value.intern(p.comp, .{ .int = .{ .big_int = c } }),
        .qt = int_qt,
        .node = try p.addNode(.{ .int_literal = .{ .qt = int_qt, .literal_tok = tok_i } }),
    };
    try res.putValue(p);
    return res;
}

fn getFracPart(p: *Parser, buf: []const u8, prefix: NumberPrefix, tok_i: TokenIndex) ![]const u8 {
    if (buf.len == 0 or buf[0] != '.') return "";
    assert(prefix != .octal);
    if (prefix == .binary) {
        try p.err(tok_i, .invalid_int_suffix, .{buf});
        return error.ParsingFailed;
    }
    for (buf, 0..) |c, idx| {
        if (idx == 0) continue;
        if (c == '\'') continue;
        if (!prefix.digitAllowed(c)) return buf[0..idx];
    }
    return buf;
}

fn getExponent(p: *Parser, buf: []const u8, prefix: NumberPrefix, tok_i: TokenIndex) ![]const u8 {
    if (buf.len == 0) return "";

    switch (buf[0]) {
        'e', 'E' => assert(prefix == .decimal),
        'p', 'P' => if (prefix != .hex) {
            try p.err(tok_i, .invalid_float_suffix, .{buf});
            return error.ParsingFailed;
        },
        else => return "",
    }
    const end = for (buf, 0..) |c, idx| {
        if (idx == 0) continue;
        if (idx == 1 and (c == '+' or c == '-')) continue;
        switch (c) {
            '0'...'9' => {},
            '\'' => continue,
            else => break idx,
        }
    } else buf.len;
    const exponent = buf[0..end];
    if (std.mem.indexOfAny(u8, exponent, "0123456789") == null) {
        try p.err(tok_i, .exponent_has_no_digits, .{});
        return error.ParsingFailed;
    }
    return exponent;
}

/// Using an explicit `tok_i` parameter instead of `p.tok_i` makes it easier
/// to parse numbers in pragma handlers.
pub fn parseNumberToken(p: *Parser, tok_i: TokenIndex) !Result {
    const buf = p.tokSlice(tok_i);
    const prefix = NumberPrefix.fromString(buf);
    const after_prefix = buf[prefix.stringLen()..];

    const int_part = try p.getIntegerPart(after_prefix, prefix, tok_i);

    const after_int = after_prefix[int_part.len..];

    const frac = try p.getFracPart(after_int, prefix, tok_i);
    const after_frac = after_int[frac.len..];

    const exponent = try p.getExponent(after_frac, prefix, tok_i);
    const suffix_str = after_frac[exponent.len..];
    const is_float = (exponent.len > 0 or frac.len > 0);
    const suffix = NumberSuffix.fromString(suffix_str, if (is_float) .float else .int) orelse {
        if (is_float) {
            try p.err(tok_i, .invalid_float_suffix, .{suffix_str});
        } else {
            try p.err(tok_i, .invalid_int_suffix, .{suffix_str});
        }
        return error.ParsingFailed;
    };
    if (suffix.isFloat80() and p.comp.float80Type() == null) {
        try p.err(tok_i, .invalid_float_suffix, .{suffix_str});
        return error.ParsingFailed;
    }

    if (is_float) {
        assert(prefix == .hex or prefix == .decimal);
        if (prefix == .hex and exponent.len == 0) {
            try p.err(tok_i, .hex_floating_constant_requires_exponent, .{});
            return error.ParsingFailed;
        }
        const number = buf[0 .. buf.len - suffix_str.len];
        return p.parseFloat(number, suffix, tok_i);
    } else {
        return p.parseInt(prefix, int_part, suffix, tok_i);
    }
}

fn ppNum(p: *Parser) Error!Result {
    defer p.tok_i += 1;
    var res = try p.parseNumberToken(p.tok_i);
    if (p.in_macro) {
        const res_sk = res.qt.scalarKind(p.comp);
        if (res_sk.isFloat() or !res_sk.isReal()) {
            try p.err(p.tok_i, .float_literal_in_pp_expr, .{});
            return error.ParsingFailed;
        }
        res.qt = if (res.qt.signedness(p.comp) == .unsigned)
            try p.comp.type_store.intmax.makeIntUnsigned(p.comp)
        else
            p.comp.type_store.intmax;
    } else if (res.val.opt_ref != .none) {
        try res.putValue(p);
    }
    return res;
}

/// Run a parser function but do not evaluate the result
fn parseNoEval(p: *Parser, comptime func: fn (*Parser) Error!?Result) Error!Result {
    const no_eval = p.no_eval;
    defer p.no_eval = no_eval;
    p.no_eval = true;

    const parsed = try func(p);
    return p.expectResult(parsed);
}

/// genericSelection : keyword_generic '(' assignExpr ',' genericAssoc (',' genericAssoc)* ')'
/// genericAssoc
///  : typeName ':' assignExpr
///  | keyword_default ':' assignExpr
fn genericSelection(p: *Parser) Error!?Result {
    const gpa = p.comp.gpa;
    const kw_generic = p.tok_i;
    p.tok_i += 1;
    const l_paren = try p.expectToken(.l_paren);
    const controlling_tok = p.tok_i;

    const controlling = try p.parseNoEval(assignExpr);
    var controlling_qt = controlling.qt;
    if (controlling_qt.is(p.comp, .array)) {
        controlling_qt = try controlling_qt.decay(p.comp);
    }
    _ = try p.expectToken(.comma);

    const list_buf_top = p.list_buf.items.len;
    defer p.list_buf.items.len = list_buf_top;

    // Use param_buf to store the token indexes of previous cases
    const param_buf_top = p.param_buf.items.len;
    defer p.param_buf.items.len = param_buf_top;

    var default_tok: ?TokenIndex = null;
    var default: Result = undefined;
    var chosen_tok: ?TokenIndex = null;
    var chosen: Result = undefined;

    while (true) {
        const start = p.tok_i;
        if (try p.typeName()) |qt| blk: {
            switch (qt.base(p.comp).type) {
                .array => try p.err(start, .generic_array_type, .{}),
                .func => try p.err(start, .generic_func_type, .{}),
                else => if (qt.isQualified()) {
                    try p.err(start, .generic_qual_type, .{});
                },
            }

            const colon = try p.expectToken(.colon);
            var res = try p.expect(assignExpr);
            res.node = try p.addNode(.{
                .generic_association_expr = .{
                    .colon_tok = colon,
                    .association_qt = qt,
                    .expr = res.node,
                },
            });
            try p.list_buf.append(gpa, res.node);
            try p.param_buf.append(gpa, .{ .name = undefined, .qt = qt, .name_tok = start, .node = .null });

            if (qt.eql(controlling_qt, p.comp)) {
                if (chosen_tok == null) {
                    chosen = res;
                    chosen_tok = start;
                    break :blk;
                }
            }

            const previous_items = p.param_buf.items[0 .. p.param_buf.items.len - 1][param_buf_top..];
            for (previous_items) |prev_item| {
                if (prev_item.qt.eql(qt, p.comp)) {
                    try p.err(start, .generic_duplicate, .{qt});
                    try p.err(prev_item.name_tok, .generic_duplicate_here, .{qt});
                }
            }
        } else if (p.eatToken(.keyword_default)) |tok| {
            _ = try p.expectToken(.colon);
            var res = try p.expect(assignExpr);
            res.node = try p.addNode(.{
                .generic_default_expr = .{
                    .default_tok = tok,
                    .expr = res.node,
                },
            });

            if (default_tok) |prev| {
                try p.err(tok, .generic_duplicate_default, .{});
                try p.err(prev, .previous_case, .{});
            }
            default = res;
            default_tok = tok;
        } else {
            if (p.list_buf.items.len == list_buf_top) {
                try p.err(p.tok_i, .expected_type, .{});
                return error.ParsingFailed;
            }
            break;
        }
        if (p.eatToken(.comma) == null) break;
    }
    try p.expectClosing(l_paren, .r_paren);

    if (chosen_tok == null) {
        if (default_tok != null) {
            chosen = default;
        } else {
            try p.err(controlling_tok, .generic_no_match, .{controlling_qt});
            return error.ParsingFailed;
        }
    } else if (default_tok != null) {
        try p.list_buf.append(gpa, default.node);
    }

    for (p.list_buf.items[list_buf_top..], list_buf_top..) |item, i| {
        if (item == chosen.node) {
            _ = p.list_buf.orderedRemove(i);
            break;
        }
    }

    return .{
        .qt = chosen.qt,
        .val = chosen.val,
        .node = try p.addNode(.{
            .generic_expr = .{
                .generic_tok = kw_generic,
                .controlling = controlling.node,
                .chosen = chosen.node,
                .qt = chosen.qt,
                .rest = p.list_buf.items[list_buf_top..],
            },
        }),
    };
}

test "Node locations" {
    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var diagnostics: Diagnostics = .{ .output = .ignore };
    var comp = Compilation.init(std.testing.allocator, arena, std.testing.io, &diagnostics, std.fs.cwd());
    defer comp.deinit();

    const file = try comp.addSourceFromBuffer("file.c",
        \\int foo = 5;
        \\int bar = 10;
        \\int main(void) {}
        \\
    );

    const builtin_macros = try comp.generateBuiltinMacros(.no_system_defines);

    var pp = Preprocessor.init(&comp, .default);
    defer pp.deinit();
    try pp.addBuiltinMacros();

    _ = try pp.preprocess(builtin_macros);

    const eof = try pp.preprocess(file);
    try pp.addToken(eof);

    var tree = try Parser.parse(&pp);
    defer tree.deinit();

    try std.testing.expectEqual(0, comp.diagnostics.total);
    for (tree.root_decls.items[tree.root_decls.items.len - 3 ..], 0..) |node, i| {
        const slice = tree.tokSlice(node.tok(&tree));
        const expected_slice = switch (i) {
            0 => "foo",
            1 => "bar",
            2 => "main",
            else => unreachable,
        };
        try std.testing.expectEqualStrings(expected_slice, slice);

        const loc = node.loc(&tree).expand(&comp);
        const expected_col: u32 = switch (i) {
            0 => 5,
            1 => 5,
            2 => 5,
            else => unreachable,
        };
        try std.testing.expectEqual(expected_col, loc.col);

        const expected_line_no = i + 1;
        try std.testing.expectEqual(expected_line_no, loc.line_no);

        const expected_source_path = "file.c";
        try std.testing.expectEqualStrings(expected_source_path, loc.path);

        const expected_source_kind = Source.Kind.user;
        try std.testing.expectEqual(expected_source_kind, loc.kind);
    }
}
