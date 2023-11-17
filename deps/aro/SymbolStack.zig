const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const TokenIndex = Tree.TokenIndex;
const NodeIndex = Tree.NodeIndex;
const Type = @import("Type.zig");
const Parser = @import("Parser.zig");
const Value = @import("Value.zig");
const StringId = @import("StringInterner.zig").StringId;

const SymbolStack = @This();

pub const Symbol = struct {
    name: StringId,
    ty: Type,
    tok: TokenIndex,
    node: NodeIndex = .none,
    kind: Kind,
    val: Value,
};

pub const Kind = enum {
    typedef,
    @"struct",
    @"union",
    @"enum",
    decl,
    def,
    enumeration,
    constexpr,
};

syms: std.MultiArrayList(Symbol) = .{},
scopes: std.ArrayListUnmanaged(u32) = .{},

pub fn deinit(s: *SymbolStack, gpa: Allocator) void {
    s.syms.deinit(gpa);
    s.scopes.deinit(gpa);
    s.* = undefined;
}

pub fn scopeEnd(s: SymbolStack) u32 {
    if (s.scopes.items.len == 0) return 0;
    return s.scopes.items[s.scopes.items.len - 1];
}

pub fn pushScope(s: *SymbolStack, p: *Parser) !void {
    try s.scopes.append(p.gpa, @intCast(s.syms.len));
}

pub fn popScope(s: *SymbolStack) void {
    s.syms.len = s.scopes.pop();
}

pub fn findTypedef(s: *SymbolStack, p: *Parser, name: StringId, name_tok: TokenIndex, no_type_yet: bool) !?Symbol {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    var i = s.syms.len;
    while (i > 0) {
        i -= 1;
        switch (kinds[i]) {
            .typedef => if (names[i] == name) return s.syms.get(i),
            .@"struct" => if (names[i] == name) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_struct, name_tok, p.tokSlice(name_tok));
                return s.syms.get(i);
            },
            .@"union" => if (names[i] == name) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_union, name_tok, p.tokSlice(name_tok));
                return s.syms.get(i);
            },
            .@"enum" => if (names[i] == name) {
                if (no_type_yet) return null;
                try p.errStr(.must_use_enum, name_tok, p.tokSlice(name_tok));
                return s.syms.get(i);
            },
            .def, .decl, .constexpr => if (names[i] == name) return null,
            else => {},
        }
    }
    return null;
}

pub fn findSymbol(s: *SymbolStack, name: StringId) ?Symbol {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    var i = s.syms.len;
    while (i > 0) {
        i -= 1;
        switch (kinds[i]) {
            .def, .decl, .enumeration, .constexpr => if (names[i] == name) return s.syms.get(i),
            else => {},
        }
    }
    return null;
}

pub fn findTag(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    kind: Token.Id,
    name_tok: TokenIndex,
    next_tok_id: Token.Id,
) !?Symbol {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    // `tag Name;` should always result in a new type if in a new scope.
    const end = if (next_tok_id == .semicolon) s.scopeEnd() else 0;
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .@"enum" => if (names[i] == name) {
                if (kind == .keyword_enum) return s.syms.get(i);
                break;
            },
            .@"struct" => if (names[i] == name) {
                if (kind == .keyword_struct) return s.syms.get(i);
                break;
            },
            .@"union" => if (names[i] == name) {
                if (kind == .keyword_union) return s.syms.get(i);
                break;
            },
            else => {},
        }
    } else return null;

    if (i < s.scopeEnd()) return null;
    try p.errStr(.wrong_tag, name_tok, p.tokSlice(name_tok));
    try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
    return null;
}

pub fn defineTypedef(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    ty: Type,
    tok: TokenIndex,
    node: NodeIndex,
) !void {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .typedef => if (names[i] == name) {
                const prev_ty = s.syms.items(.ty)[i];
                if (ty.eql(prev_ty, p.comp, true)) break;
                try p.errStr(.redefinition_of_typedef, tok, try p.typePairStrExtra(ty, " vs ", prev_ty));
                const previous_tok = s.syms.items(.tok)[i];
                if (previous_tok != 0) try p.errTok(.previous_definition, previous_tok);
                break;
            },
            else => {},
        }
    }
    try s.syms.append(p.gpa, .{
        .kind = .typedef,
        .name = name,
        .tok = tok,
        .ty = ty,
        .node = node,
        .val = .{},
    });
}

pub fn defineSymbol(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    ty: Type,
    tok: TokenIndex,
    node: NodeIndex,
    val: Value,
    constexpr: bool,
) !void {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .enumeration => if (names[i] == name) {
                try p.errStr(.redefinition_different_sym, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                break;
            },
            .decl => if (names[i] == name) {
                const prev_ty = s.syms.items(.ty)[i];
                if (!ty.eql(prev_ty, p.comp, true)) {
                    try p.errStr(.redefinition_incompatible, tok, p.tokSlice(tok));
                    try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                }
                break;
            },
            .def, .constexpr => if (names[i] == name) {
                try p.errStr(.redefinition, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                break;
            },
            else => {},
        }
    }
    try s.syms.append(p.gpa, .{
        .kind = if (constexpr) .constexpr else .def,
        .name = name,
        .tok = tok,
        .ty = ty,
        .node = node,
        .val = val,
    });
}

pub fn declareSymbol(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    ty: Type,
    tok: TokenIndex,
    node: NodeIndex,
) !void {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .enumeration => if (names[i] == name) {
                try p.errStr(.redefinition_different_sym, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                break;
            },
            .decl => if (names[i] == name) {
                const prev_ty = s.syms.items(.ty)[i];
                if (!ty.eql(prev_ty, p.comp, true)) {
                    try p.errStr(.redefinition_incompatible, tok, p.tokSlice(tok));
                    try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                }
                break;
            },
            .def, .constexpr => if (names[i] == name) {
                const prev_ty = s.syms.items(.ty)[i];
                if (!ty.eql(prev_ty, p.comp, true)) {
                    try p.errStr(.redefinition_incompatible, tok, p.tokSlice(tok));
                    try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                    break;
                }
                return;
            },
            else => {},
        }
    }
    try s.syms.append(p.gpa, .{
        .kind = .decl,
        .name = name,
        .tok = tok,
        .ty = ty,
        .node = node,
        .val = .{},
    });
}

pub fn defineParam(s: *SymbolStack, p: *Parser, name: StringId, ty: Type, tok: TokenIndex) !void {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .enumeration, .decl, .def, .constexpr => if (names[i] == name) {
                try p.errStr(.redefinition_of_parameter, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                break;
            },
            else => {},
        }
    }
    if (ty.is(.fp16) and !p.comp.hasHalfPrecisionFloatABI()) {
        try p.errStr(.suggest_pointer_for_invalid_fp16, tok, "parameters");
    }
    try s.syms.append(p.gpa, .{
        .kind = .def,
        .name = name,
        .tok = tok,
        .ty = ty,
        .val = .{},
    });
}

pub fn defineTag(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    kind: Token.Id,
    tok: TokenIndex,
) !?Symbol {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .@"enum" => if (names[i] == name) {
                if (kind == .keyword_enum) return s.syms.get(i);
                try p.errStr(.wrong_tag, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                return null;
            },
            .@"struct" => if (names[i] == name) {
                if (kind == .keyword_struct) return s.syms.get(i);
                try p.errStr(.wrong_tag, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                return null;
            },
            .@"union" => if (names[i] == name) {
                if (kind == .keyword_union) return s.syms.get(i);
                try p.errStr(.wrong_tag, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                return null;
            },
            else => {},
        }
    }
    return null;
}

pub fn defineEnumeration(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    ty: Type,
    tok: TokenIndex,
    val: Value,
) !void {
    const kinds = s.syms.items(.kind);
    const names = s.syms.items(.name);
    const end = s.scopeEnd();
    var i = s.syms.len;
    while (i > end) {
        i -= 1;
        switch (kinds[i]) {
            .enumeration => if (names[i] == name) {
                try p.errStr(.redefinition, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                return;
            },
            .decl, .def, .constexpr => if (names[i] == name) {
                try p.errStr(.redefinition_different_sym, tok, p.tokSlice(tok));
                try p.errTok(.previous_definition, s.syms.items(.tok)[i]);
                return;
            },
            else => {},
        }
    }
    try s.syms.append(p.gpa, .{
        .kind = .enumeration,
        .name = name,
        .tok = tok,
        .ty = ty,
        .val = val,
    });
}
