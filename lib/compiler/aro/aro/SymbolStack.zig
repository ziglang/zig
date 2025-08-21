const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const Parser = @import("Parser.zig");
const StringId = @import("StringInterner.zig").StringId;
const Tree = @import("Tree.zig");
const Token = Tree.Token;
const TokenIndex = Tree.TokenIndex;
const Node = Tree.Node;
const QualType = @import("TypeStore.zig").QualType;
const Value = @import("Value.zig");

const SymbolStack = @This();

pub const Symbol = struct {
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    node: Node.OptIndex = .null,
    out_of_scope: bool = false,
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

scopes: std.ArrayList(Scope) = .empty,
/// allocations from nested scopes are retained after popping; `active_len` is the number
/// of currently-active items in `scopes`.
active_len: usize = 0,

const Scope = struct {
    vars: std.AutoHashMapUnmanaged(StringId, Symbol) = .empty,
    tags: std.AutoHashMapUnmanaged(StringId, Symbol) = .empty,

    fn deinit(self: *Scope, allocator: Allocator) void {
        self.vars.deinit(allocator);
        self.tags.deinit(allocator);
    }

    fn clearRetainingCapacity(self: *Scope) void {
        self.vars.clearRetainingCapacity();
        self.tags.clearRetainingCapacity();
    }
};

pub fn deinit(s: *SymbolStack, gpa: Allocator) void {
    std.debug.assert(s.active_len == 0); // all scopes should have been popped
    for (s.scopes.items) |*scope| {
        scope.deinit(gpa);
    }
    s.scopes.deinit(gpa);
    s.* = undefined;
}

pub fn pushScope(s: *SymbolStack, p: *Parser) !void {
    if (s.active_len + 1 > s.scopes.items.len) {
        try s.scopes.append(p.comp.gpa, .{});
        s.active_len = s.scopes.items.len;
    } else {
        s.scopes.items[s.active_len].clearRetainingCapacity();
        s.active_len += 1;
    }
}

pub fn popScope(s: *SymbolStack) void {
    s.active_len -= 1;
}

pub fn findTypedef(s: *SymbolStack, p: *Parser, name: StringId, name_tok: TokenIndex, no_type_yet: bool) !?Symbol {
    const prev = s.lookup(name, .vars) orelse s.lookup(name, .tags) orelse return null;
    switch (prev.kind) {
        .typedef => return prev,
        .@"struct" => {
            if (no_type_yet) return null;
            try p.err(name_tok, .must_use_struct, .{p.tokSlice(name_tok)});
            return prev;
        },
        .@"union" => {
            if (no_type_yet) return null;
            try p.err(name_tok, .must_use_union, .{p.tokSlice(name_tok)});
            return prev;
        },
        .@"enum" => {
            if (no_type_yet) return null;
            try p.err(name_tok, .must_use_enum, .{p.tokSlice(name_tok)});
            return prev;
        },
        else => return null,
    }
}

pub fn findSymbol(s: *SymbolStack, name: StringId) ?Symbol {
    return s.lookup(name, .vars);
}

pub fn findTag(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    kind: Token.Id,
    name_tok: TokenIndex,
    next_tok_id: Token.Id,
) !?Symbol {
    // `tag Name;` should always result in a new type if in a new scope.
    const prev = (if (next_tok_id == .semicolon) s.get(name, .tags) else s.lookup(name, .tags)) orelse return null;
    switch (prev.kind) {
        .@"enum" => if (kind == .keyword_enum) return prev,
        .@"struct" => if (kind == .keyword_struct) return prev,
        .@"union" => if (kind == .keyword_union) return prev,
        else => unreachable,
    }
    if (s.get(name, .tags) == null) return null;
    try p.err(name_tok, .wrong_tag, .{p.tokSlice(name_tok)});
    try p.err(prev.tok, .previous_definition, .{});
    return null;
}

const ScopeKind = enum {
    /// structs, enums, unions
    tags,
    /// everything else
    vars,
};

/// Return the Symbol for `name` (or null if not found) in the innermost scope
pub fn get(s: *SymbolStack, name: StringId, kind: ScopeKind) ?Symbol {
    return switch (kind) {
        .vars => s.scopes.items[s.active_len - 1].vars.get(name),
        .tags => s.scopes.items[s.active_len - 1].tags.get(name),
    };
}

/// Return the Symbol for `name` (or null if not found) in the nearest active scope,
/// starting at the innermost.
fn lookup(s: *SymbolStack, name: StringId, kind: ScopeKind) ?Symbol {
    var i = s.active_len;
    while (i > 0) {
        i -= 1;
        switch (kind) {
            .vars => if (s.scopes.items[i].vars.get(name)) |sym| return sym,
            .tags => if (s.scopes.items[i].tags.get(name)) |sym| return sym,
        }
    }
    return null;
}

/// Define a symbol in the innermost scope. Does not issue diagnostics or check correctness
/// with regard to the C standard.
pub fn define(s: *SymbolStack, allocator: Allocator, symbol: Symbol) !void {
    switch (symbol.kind) {
        .constexpr, .def, .decl, .enumeration, .typedef => {
            try s.scopes.items[s.active_len - 1].vars.put(allocator, symbol.name, symbol);
        },
        .@"struct", .@"union", .@"enum" => {
            try s.scopes.items[s.active_len - 1].tags.put(allocator, symbol.name, symbol);
        },
    }
}

pub fn defineTypedef(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    node: Node.Index,
) !void {
    if (s.get(name, .vars)) |prev| {
        switch (prev.kind) {
            .typedef => {
                if (!prev.qt.isInvalid() and !qt.eqlQualified(prev.qt, p.comp)) {
                    if (qt.isInvalid()) return;
                    const non_typedef_qt = qt.type(p.comp).typedef.base;
                    const non_typedef_prev_qt = prev.qt.type(p.comp).typedef.base;
                    try p.err(tok, .redefinition_of_typedef, .{ non_typedef_qt, non_typedef_prev_qt });
                    if (prev.tok != 0) try p.err(prev.tok, .previous_definition, .{});
                }
            },
            .enumeration, .decl, .def, .constexpr => {
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            else => unreachable,
        }
    }
    try s.define(p.comp.gpa, .{
        .kind = .typedef,
        .name = name,
        .tok = tok,
        .qt = qt,
        .node = .pack(node),
        .val = .{},
    });
}

pub fn defineSymbol(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    node: Node.Index,
    val: Value,
    constexpr: bool,
) !void {
    if (s.get(name, .vars)) |prev| {
        switch (prev.kind) {
            .enumeration => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            .decl => {
                if (!prev.qt.isInvalid() and !qt.eqlQualified(prev.qt, p.comp)) {
                    if (qt.isInvalid()) return;
                    try p.err(tok, .redefinition_incompatible, .{p.tokSlice(tok)});
                    try p.err(prev.tok, .previous_definition, .{});
                } else {
                    if (prev.node.unpack()) |some| p.setTentativeDeclDefinition(some, node);
                }
            },
            .def, .constexpr => if (!prev.qt.isInvalid()) {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            .typedef => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            else => unreachable,
        }
    }

    try s.define(p.comp.gpa, .{
        .kind = if (constexpr) .constexpr else .def,
        .name = name,
        .tok = tok,
        .qt = qt,
        .node = .pack(node),
        .val = val,
    });
}

/// Get a pointer to the named symbol in the innermost scope.
/// Asserts that a symbol with the name exists.
pub fn getPtr(s: *SymbolStack, name: StringId, kind: ScopeKind) *Symbol {
    return switch (kind) {
        .tags => s.scopes.items[s.active_len - 1].tags.getPtr(name).?,
        .vars => s.scopes.items[s.active_len - 1].vars.getPtr(name).?,
    };
}

pub fn declareSymbol(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    node: Node.Index,
) !void {
    if (s.get(name, .vars)) |prev| {
        switch (prev.kind) {
            .enumeration => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            .decl => {
                if (!prev.qt.isInvalid() and !qt.eqlQualified(prev.qt, p.comp)) {
                    if (qt.isInvalid()) return;
                    try p.err(tok, .redefinition_incompatible, .{p.tokSlice(tok)});
                    try p.err(prev.tok, .previous_definition, .{});
                } else {
                    if (prev.node.unpack()) |some| p.setTentativeDeclDefinition(node, some);
                }
            },
            .def, .constexpr => {
                if (!prev.qt.isInvalid() and !qt.eqlQualified(prev.qt, p.comp)) {
                    if (qt.isInvalid()) return;
                    try p.err(tok, .redefinition_incompatible, .{p.tokSlice(tok)});
                    try p.err(prev.tok, .previous_definition, .{});
                } else {
                    if (prev.node.unpack()) |some| p.setTentativeDeclDefinition(node, some);
                    return;
                }
            },
            .typedef => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            else => unreachable,
        }
    }
    try s.define(p.comp.gpa, .{
        .kind = .decl,
        .name = name,
        .tok = tok,
        .qt = qt,
        .node = .pack(node),
        .val = .{},
    });

    // Declare out of scope symbol for functions declared in functions.
    if (s.active_len > 1 and !p.comp.langopts.standard.atLeast(.c23) and qt.is(p.comp, .func)) {
        try s.scopes.items[0].vars.put(p.comp.gpa, name, .{
            .kind = .decl,
            .name = name,
            .tok = tok,
            .qt = qt,
            .node = .pack(node),
            .val = .{},
            .out_of_scope = true,
        });
    }
}

pub fn defineParam(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    node: ?Node.Index,
) !void {
    if (s.get(name, .vars)) |prev| {
        switch (prev.kind) {
            .enumeration, .decl, .def, .constexpr => if (!prev.qt.isInvalid()) {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_of_parameter, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            .typedef => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            else => unreachable,
        }
    }
    try s.define(p.comp.gpa, .{
        .kind = .def,
        .name = name,
        .tok = tok,
        .qt = qt,
        .node = .packOpt(node),
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
    const prev = s.get(name, .tags) orelse return null;
    switch (prev.kind) {
        .@"enum" => {
            if (kind == .keyword_enum) return prev;
            try p.err(tok, .wrong_tag, .{p.tokSlice(tok)});
            try p.err(prev.tok, .previous_definition, .{});
            return null;
        },
        .@"struct" => {
            if (kind == .keyword_struct) return prev;
            try p.err(tok, .wrong_tag, .{p.tokSlice(tok)});
            try p.err(prev.tok, .previous_definition, .{});
            return null;
        },
        .@"union" => {
            if (kind == .keyword_union) return prev;
            try p.err(tok, .wrong_tag, .{p.tokSlice(tok)});
            try p.err(prev.tok, .previous_definition, .{});
            return null;
        },
        else => unreachable,
    }
}

pub fn defineEnumeration(
    s: *SymbolStack,
    p: *Parser,
    name: StringId,
    qt: QualType,
    tok: TokenIndex,
    val: Value,
    node: Node.Index,
) !void {
    if (s.get(name, .vars)) |prev| {
        switch (prev.kind) {
            .enumeration => if (!prev.qt.isInvalid()) {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
                return;
            },
            .decl, .def, .constexpr => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
                return;
            },
            .typedef => {
                if (qt.isInvalid()) return;
                try p.err(tok, .redefinition_different_sym, .{p.tokSlice(tok)});
                try p.err(prev.tok, .previous_definition, .{});
            },
            else => unreachable,
        }
    }
    try s.define(p.comp.gpa, .{
        .kind = .enumeration,
        .name = name,
        .tok = tok,
        .qt = qt,
        .val = val,
        .node = .pack(node),
    });
}
