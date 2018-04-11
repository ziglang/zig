const std = @import("../index.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Token = std.zig.Token;
const mem = std.mem;

pub const Node = struct {
    id: Id,
    comment: ?&NodeLineComment,

    pub const Id = enum {
        // Top level
        Root,
        Use,
        TestDecl,

        // Statements
        VarDecl,
        Defer,

        // Operators
        InfixOp,
        PrefixOp,
        SuffixOp,

        // Control flow
        Switch,
        While,
        For,
        If,
        ControlFlowExpression,
        Suspend,

        // Type expressions
        VarType,
        ErrorType,
        FnProto,

        // Primary expressions
        IntegerLiteral,
        FloatLiteral,
        StringLiteral,
        MultilineStringLiteral,
        CharLiteral,
        BoolLiteral,
        NullLiteral,
        UndefinedLiteral,
        ThisLiteral,
        Unreachable,
        Identifier,
        GroupedExpression,
        BuiltinCall,
        ErrorSetDecl,
        ContainerDecl,
        Asm,
        Comptime,
        Block,

        // Misc
        LineComment,
        SwitchCase,
        SwitchElse,
        Else,
        Payload,
        PointerPayload,
        PointerIndexPayload,
        StructField,
        UnionTag,
        EnumTag,
        AsmInput,
        AsmOutput,
        AsyncAttribute,
        ParamDecl,
        FieldInitializer,
    };

    const IdTypePair = struct {
        id: Id,
        Type: type,
    };

    // TODO: When @field exists, we could generate this by iterating over all members of `Id`,
    //       and making an array of `IdTypePair { .id = @field(Id, @memberName(Id, i)), .Type = @field(ast, "Node" ++ @memberName(Id, i)) }`
    const idTypeTable = []IdTypePair {
        IdTypePair { .id = Id.Root, .Type = NodeRoot },
        IdTypePair { .id = Id.Use, .Type = NodeUse },
        IdTypePair { .id = Id.TestDecl, .Type = NodeTestDecl },

        IdTypePair { .id = Id.VarDecl, .Type = NodeVarDecl },
        IdTypePair { .id = Id.Defer, .Type = NodeDefer },

        IdTypePair { .id = Id.InfixOp, .Type = NodeInfixOp },
        IdTypePair { .id = Id.PrefixOp, .Type = NodePrefixOp },
        IdTypePair { .id = Id.SuffixOp, .Type = NodeSuffixOp },

        IdTypePair { .id = Id.Switch, .Type = NodeSwitch },
        IdTypePair { .id = Id.While, .Type = NodeWhile },
        IdTypePair { .id = Id.For, .Type = NodeFor },
        IdTypePair { .id = Id.If, .Type = NodeIf },
        IdTypePair { .id = Id.ControlFlowExpression, .Type = NodeControlFlowExpression },
        IdTypePair { .id = Id.Suspend, .Type = NodeSuspend },

        IdTypePair { .id = Id.VarType, .Type = NodeVarType },
        IdTypePair { .id = Id.ErrorType, .Type = NodeErrorType },
        IdTypePair { .id = Id.FnProto, .Type = NodeFnProto },

        IdTypePair { .id = Id.IntegerLiteral, .Type = NodeIntegerLiteral },
        IdTypePair { .id = Id.FloatLiteral, .Type = NodeFloatLiteral },
        IdTypePair { .id = Id.StringLiteral, .Type = NodeStringLiteral },
        IdTypePair { .id = Id.MultilineStringLiteral, .Type = NodeMultilineStringLiteral },
        IdTypePair { .id = Id.CharLiteral, .Type = NodeCharLiteral },
        IdTypePair { .id = Id.BoolLiteral, .Type = NodeBoolLiteral },
        IdTypePair { .id = Id.NullLiteral, .Type = NodeNullLiteral },
        IdTypePair { .id = Id.UndefinedLiteral, .Type = NodeUndefinedLiteral },
        IdTypePair { .id = Id.ThisLiteral, .Type = NodeThisLiteral },
        IdTypePair { .id = Id.Unreachable, .Type = NodeUnreachable },
        IdTypePair { .id = Id.Identifier, .Type = NodeIdentifier },
        IdTypePair { .id = Id.GroupedExpression, .Type = NodeGroupedExpression },
        IdTypePair { .id = Id.BuiltinCall, .Type = NodeBuiltinCall },
        IdTypePair { .id = Id.ErrorSetDecl, .Type = NodeErrorSetDecl },
        IdTypePair { .id = Id.ContainerDecl, .Type = NodeContainerDecl },
        IdTypePair { .id = Id.Asm, .Type = NodeAsm },
        IdTypePair { .id = Id.Comptime, .Type = NodeComptime },
        IdTypePair { .id = Id.Block, .Type = NodeBlock },

        IdTypePair { .id = Id.LineComment, .Type = NodeLineComment },
        IdTypePair { .id = Id.SwitchCase, .Type = NodeSwitchCase },
        IdTypePair { .id = Id.SwitchElse, .Type = NodeSwitchElse },
        IdTypePair { .id = Id.Else, .Type = NodeElse },
        IdTypePair { .id = Id.Payload, .Type = NodePayload },
        IdTypePair { .id = Id.PointerPayload, .Type = NodePointerPayload },
        IdTypePair { .id = Id.PointerIndexPayload, .Type = NodePointerIndexPayload },
        IdTypePair { .id = Id.StructField, .Type = NodeStructField },
        IdTypePair { .id = Id.UnionTag, .Type = NodeUnionTag },
        IdTypePair { .id = Id.EnumTag, .Type = NodeEnumTag },
        IdTypePair { .id = Id.AsmInput, .Type = NodeAsmInput },
        IdTypePair { .id = Id.AsmOutput, .Type = NodeAsmOutput },
        IdTypePair { .id = Id.AsyncAttribute, .Type = NodeAsyncAttribute },
        IdTypePair { .id = Id.ParamDecl, .Type = NodeParamDecl },
        IdTypePair { .id = Id.FieldInitializer, .Type = NodeFieldInitializer },
    };

    pub fn IdToType(comptime id: Id) type {
        inline for (idTypeTable) |id_type_pair| {
            if (id == id_type_pair.id)
                return id_type_pair.Type;
        }

        unreachable;
    }

    pub fn typeToId(comptime T: type) Id {
        inline for (idTypeTable) |id_type_pair| {
            if (T == id_type_pair.Type)
                return id_type_pair.id;
        }

        unreachable;
    }

    pub fn iterate(base: &Node, index: usize) ?&Node {
        inline for (idTypeTable) |id_type_pair| {
            if (base.id == id_type_pair.id)
                return @fieldParentPtr(id_type_pair.Type, "base", base).iterate(index);
        }

        unreachable;
    }

    pub fn firstToken(base: &Node) Token {
        inline for (idTypeTable) |id_type_pair| {
            if (base.id == id_type_pair.id)
                return @fieldParentPtr(id_type_pair.Type, "base", base).firstToken();
        }

        unreachable;
    }

    pub fn lastToken(base: &Node) Token {
        inline for (idTypeTable) |id_type_pair| {
            if (base.id == id_type_pair.id)
                return @fieldParentPtr(id_type_pair.Type, "base", base).lastToken();
        }

        unreachable;
    }
};

pub const NodeRoot = struct {
    base: Node,
    decls: ArrayList(&Node),
    eof_token: Token,

    pub fn iterate(self: &NodeRoot, index: usize) ?&Node {
        if (index < self.decls.len) {
            return self.decls.items[self.decls.len - index - 1];
        }
        return null;
    }

    pub fn firstToken(self: &NodeRoot) Token {
        return if (self.decls.len == 0) self.eof_token else self.decls.at(0).firstToken();
    }

    pub fn lastToken(self: &NodeRoot) Token {
        return if (self.decls.len == 0) self.eof_token else self.decls.at(self.decls.len - 1).lastToken();
    }
};

pub const NodeVarDecl = struct {
    base: Node,
    visib_token: ?Token,
    name_token: Token,
    eq_token: Token,
    mut_token: Token,
    comptime_token: ?Token,
    extern_token: ?Token,
    lib_name: ?&Node,
    type_node: ?&Node,
    align_node: ?&Node,
    init_node: ?&Node,
    semicolon_token: Token,

    pub fn iterate(self: &NodeVarDecl, index: usize) ?&Node {
        var i = index;

        if (self.type_node) |type_node| {
            if (i < 1) return type_node;
            i -= 1;
        }

        if (self.align_node) |align_node| {
            if (i < 1) return align_node;
            i -= 1;
        }

        if (self.init_node) |init_node| {
            if (i < 1) return init_node;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeVarDecl) Token {
        if (self.visib_token) |visib_token| return visib_token;
        if (self.comptime_token) |comptime_token| return comptime_token;
        if (self.extern_token) |extern_token| return extern_token;
        assert(self.lib_name == null);
        return self.mut_token;
    }

    pub fn lastToken(self: &NodeVarDecl) Token {
        return self.semicolon_token;
    }
};

pub const NodeUse = struct {
    base: Node,
    visib_token: ?Token,
    expr: &Node,
    semicolon_token: Token,

    pub fn iterate(self: &NodeUse, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeUse) Token {
        if (self.visib_token) |visib_token| return visib_token;
        return self.expr.firstToken();
    }

    pub fn lastToken(self: &NodeUse) Token {
        return self.semicolon_token;
    }
};

pub const NodeErrorSetDecl = struct {
    base: Node,
    error_token: Token,
    decls: ArrayList(&NodeIdentifier),
    rbrace_token: Token,

    pub fn iterate(self: &NodeErrorSetDecl, index: usize) ?&Node {
        var i = index;

        if (i < self.decls.len) return &self.decls.at(i).base;
        i -= self.decls.len;

        return null;
    }

    pub fn firstToken(self: &NodeErrorSetDecl) Token {
        return self.error_token;
    }

    pub fn lastToken(self: &NodeErrorSetDecl) Token {
        return self.rbrace_token;
    }
};

pub const NodeContainerDecl = struct {
    base: Node,
    ltoken: Token,
    layout: Layout,
    kind: Kind,
    init_arg_expr: InitArg,
    fields_and_decls: ArrayList(&Node),
    rbrace_token: Token,

    const Layout = enum {
        Auto,
        Extern,
        Packed,
    };

    const Kind = enum {
        Struct,
        Enum,
        Union,
    };

    const InitArg = union(enum) {
        None,
        Enum,
        Type: &Node,
    };

    pub fn iterate(self: &NodeContainerDecl, index: usize) ?&Node {
        var i = index;

        switch (self.init_arg_expr) {
            InitArg.Type => |t| {
                if (i < 1) return t;
                i -= 1;
            },
            InitArg.None,
            InitArg.Enum => { }
        }

        if (i < self.fields_and_decls.len) return self.fields_and_decls.at(i);
        i -= self.fields_and_decls.len;

        return null;
    }

    pub fn firstToken(self: &NodeContainerDecl) Token {
        return self.ltoken;
    }

    pub fn lastToken(self: &NodeContainerDecl) Token {
        return self.rbrace_token;
    }
};

pub const NodeStructField = struct {
    base: Node,
    name_token: Token,
    type_expr: &Node,

    pub fn iterate(self: &NodeStructField, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.type_expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeStructField) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeStructField) Token {
        return self.type_expr.lastToken();
    }
};

pub const NodeUnionTag = struct {
    base: Node,
    name_token: Token,
    type_expr: ?&Node,

    pub fn iterate(self: &NodeUnionTag, index: usize) ?&Node {
        var i = index;

        if (self.type_expr) |type_expr| {
            if (i < 1) return type_expr;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeUnionTag) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeUnionTag) Token {
        if (self.type_expr) |type_expr| {
            return type_expr.lastToken();
        }

        return self.name_token;
    }
};

pub const NodeEnumTag = struct {
    base: Node,
    name_token: Token,
    value: ?&Node,

    pub fn iterate(self: &NodeEnumTag, index: usize) ?&Node {
        var i = index;

        if (self.value) |value| {
            if (i < 1) return value;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeEnumTag) Token {
        return self.name_token;
    }

    pub fn lastToken(self: &NodeEnumTag) Token {
        if (self.value) |value| {
            return value.lastToken();
        }

        return self.name_token;
    }
};

pub const NodeIdentifier = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeIdentifier, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeIdentifier) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeIdentifier) Token {
        return self.token;
    }
};

pub const NodeAsyncAttribute = struct {
    base: Node,
    async_token: Token,
    allocator_type: ?&Node,
    rangle_bracket: ?Token,

    pub fn iterate(self: &NodeAsyncAttribute, index: usize) ?&Node {
        var i = index;

        if (self.allocator_type) |allocator_type| {
            if (i < 1) return allocator_type;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeAsyncAttribute) Token {
        return self.async_token;
    }

    pub fn lastToken(self: &NodeAsyncAttribute) Token {
        if (self.rangle_bracket) |rangle_bracket| {
            return rangle_bracket;
        }

        return self.async_token;
    }
};

pub const NodeFnProto = struct {
    base: Node,
    visib_token: ?Token,
    fn_token: Token,
    name_token: ?Token,
    params: ArrayList(&Node),
    return_type: ReturnType,
    var_args_token: ?Token,
    extern_token: ?Token,
    inline_token: ?Token,
    cc_token: ?Token,
    async_attr: ?&NodeAsyncAttribute,
    body_node: ?&Node,
    lib_name: ?&Node, // populated if this is an extern declaration
    align_expr: ?&Node, // populated if align(A) is present

    pub const ReturnType = union(enum) {
        Explicit: &Node,
        InferErrorSet: &Node,
    };

    pub fn iterate(self: &NodeFnProto, index: usize) ?&Node {
        var i = index;

        if (self.body_node) |body_node| {
            if (i < 1) return body_node;
            i -= 1;
        }

        switch (self.return_type) {
            // TODO allow this and next prong to share bodies since the types are the same
            ReturnType.Explicit => |node| {
                if (i < 1) return node;
                i -= 1;
            },
            ReturnType.InferErrorSet => |node| {
                if (i < 1) return node;
                i -= 1;
            },
        }

        if (self.align_expr) |align_expr| {
            if (i < 1) return align_expr;
            i -= 1;
        }

        if (i < self.params.len) return self.params.items[self.params.len - i - 1];
        i -= self.params.len;

        if (self.lib_name) |lib_name| {
            if (i < 1) return lib_name;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeFnProto) Token {
        if (self.visib_token) |visib_token| return visib_token;
        if (self.extern_token) |extern_token| return extern_token;
        assert(self.lib_name == null);
        if (self.inline_token) |inline_token| return inline_token;
        if (self.cc_token) |cc_token| return cc_token;
        return self.fn_token;
    }

    pub fn lastToken(self: &NodeFnProto) Token {
        if (self.body_node) |body_node| return body_node.lastToken();
        switch (self.return_type) {
            // TODO allow this and next prong to share bodies since the types are the same
            ReturnType.Explicit => |node| return node.lastToken(),
            ReturnType.InferErrorSet => |node| return node.lastToken(),
        }
    }
};

pub const NodeParamDecl = struct {
    base: Node,
    comptime_token: ?Token,
    noalias_token: ?Token,
    name_token: ?Token,
    type_node: &Node,
    var_args_token: ?Token,

    pub fn iterate(self: &NodeParamDecl, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.type_node;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeParamDecl) Token {
        if (self.comptime_token) |comptime_token| return comptime_token;
        if (self.noalias_token) |noalias_token| return noalias_token;
        if (self.name_token) |name_token| return name_token;
        return self.type_node.firstToken();
    }

    pub fn lastToken(self: &NodeParamDecl) Token {
        if (self.var_args_token) |var_args_token| return var_args_token;
        return self.type_node.lastToken();
    }
};

pub const NodeBlock = struct {
    base: Node,
    label: ?Token,
    lbrace: Token,
    statements: ArrayList(&Node),
    rbrace: Token,

    pub fn iterate(self: &NodeBlock, index: usize) ?&Node {
        var i = index;

        if (i < self.statements.len) return self.statements.items[i];
        i -= self.statements.len;

        return null;
    }

    pub fn firstToken(self: &NodeBlock) Token {
        if (self.label) |label| {
            return label;
        }

        return self.lbrace;
    }

    pub fn lastToken(self: &NodeBlock) Token {
        return self.rbrace;
    }
};

pub const NodeDefer = struct {
    base: Node,
    defer_token: Token,
    kind: Kind,
    expr: &Node,

    const Kind = enum {
        Error,
        Unconditional,
    };

    pub fn iterate(self: &NodeDefer, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeDefer) Token {
        return self.defer_token;
    }

    pub fn lastToken(self: &NodeDefer) Token {
        return self.expr.lastToken();
    }
};

pub const NodeComptime = struct {
    base: Node,
    comptime_token: Token,
    expr: &Node,

    pub fn iterate(self: &NodeComptime, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeComptime) Token {
        return self.comptime_token;
    }

    pub fn lastToken(self: &NodeComptime) Token {
        return self.expr.lastToken();
    }
};

pub const NodePayload = struct {
    base: Node,
    lpipe: Token,
    error_symbol: &NodeIdentifier,
    rpipe: Token,

    pub fn iterate(self: &NodePayload, index: usize) ?&Node {
        var i = index;

        if (i < 1) return &self.error_symbol.base;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodePayload) Token {
        return self.lpipe;
    }

    pub fn lastToken(self: &NodePayload) Token {
        return self.rpipe;
    }
};

pub const NodePointerPayload = struct {
    base: Node,
    lpipe: Token,
    is_ptr: bool,
    value_symbol: &NodeIdentifier,
    rpipe: Token,

    pub fn iterate(self: &NodePointerPayload, index: usize) ?&Node {
        var i = index;

        if (i < 1) return &self.value_symbol.base;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodePointerPayload) Token {
        return self.lpipe;
    }

    pub fn lastToken(self: &NodePointerPayload) Token {
        return self.rpipe;
    }
};

pub const NodePointerIndexPayload = struct {
    base: Node,
    lpipe: Token,
    is_ptr: bool,
    value_symbol: &NodeIdentifier,
    index_symbol: ?&NodeIdentifier,
    rpipe: Token,

    pub fn iterate(self: &NodePointerIndexPayload, index: usize) ?&Node {
        var i = index;

        if (i < 1) return &self.value_symbol.base;
        i -= 1;

        if (self.index_symbol) |index_symbol| {
            if (i < 1) return &index_symbol.base;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodePointerIndexPayload) Token {
        return self.lpipe;
    }

    pub fn lastToken(self: &NodePointerIndexPayload) Token {
        return self.rpipe;
    }
};

pub const NodeElse = struct {
    base: Node,
    else_token: Token,
    payload: ?&NodePayload,
    body: &Node,

    pub fn iterate(self: &NodeElse, index: usize) ?&Node {
        var i = index;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (i < 1) return self.body;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeElse) Token {
        return self.else_token;
    }

    pub fn lastToken(self: &NodeElse) Token {
        return self.body.lastToken();
    }
};

pub const NodeSwitch = struct {
    base: Node,
    switch_token: Token,
    expr: &Node,
    cases: ArrayList(&NodeSwitchCase),
    rbrace: Token,

    pub fn iterate(self: &NodeSwitch, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        if (i < self.cases.len) return &self.cases.at(i).base;
        i -= self.cases.len;

        return null;
    }

    pub fn firstToken(self: &NodeSwitch) Token {
        return self.switch_token;
    }

    pub fn lastToken(self: &NodeSwitch) Token {
        return self.rbrace;
    }
};

pub const NodeSwitchCase = struct {
    base: Node,
    items: ArrayList(&Node),
    payload: ?&NodePointerPayload,
    expr: &Node,

    pub fn iterate(self: &NodeSwitchCase, index: usize) ?&Node {
        var i = index;

        if (i < self.items.len) return self.items.at(i);
        i -= self.items.len;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeSwitchCase) Token {
        return self.items.at(0).firstToken();
    }

    pub fn lastToken(self: &NodeSwitchCase) Token {
        return self.expr.lastToken();
    }
};

pub const NodeSwitchElse = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeSwitchElse, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeSwitchElse) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeSwitchElse) Token {
        return self.token;
    }
};

pub const NodeWhile = struct {
    base: Node,
    label: ?Token,
    inline_token: ?Token,
    while_token: Token,
    condition: &Node,
    payload: ?&NodePointerPayload,
    continue_expr: ?&Node,
    body: &Node,
    @"else": ?&NodeElse,

    pub fn iterate(self: &NodeWhile, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.condition;
        i -= 1;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (self.continue_expr) |continue_expr| {
            if (i < 1) return continue_expr;
            i -= 1;
        }

        if (i < 1) return self.body;
        i -= 1;

        if (self.@"else") |@"else"| {
            if (i < 1) return &@"else".base;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeWhile) Token {
        if (self.label) |label| {
            return label;
        }

        if (self.inline_token) |inline_token| {
            return inline_token;
        }

        return self.while_token;
    }

    pub fn lastToken(self: &NodeWhile) Token {
        if (self.@"else") |@"else"| {
            return @"else".body.lastToken();
        }

        return self.body.lastToken();
    }
};

pub const NodeFor = struct {
    base: Node,
    label: ?Token,
    inline_token: ?Token,
    for_token: Token,
    array_expr: &Node,
    payload: ?&NodePointerIndexPayload,
    body: &Node,
    @"else": ?&NodeElse,

    pub fn iterate(self: &NodeFor, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.array_expr;
        i -= 1;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (i < 1) return self.body;
        i -= 1;

        if (self.@"else") |@"else"| {
            if (i < 1) return &@"else".base;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeFor) Token {
        if (self.label) |label| {
            return label;
        }

        if (self.inline_token) |inline_token| {
            return inline_token;
        }

        return self.for_token;
    }

    pub fn lastToken(self: &NodeFor) Token {
        if (self.@"else") |@"else"| {
            return @"else".body.lastToken();
        }

        return self.body.lastToken();
    }
};

pub const NodeIf = struct {
    base: Node,
    if_token: Token,
    condition: &Node,
    payload: ?&NodePointerPayload,
    body: &Node,
    @"else": ?&NodeElse,

    pub fn iterate(self: &NodeIf, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.condition;
        i -= 1;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (i < 1) return self.body;
        i -= 1;

        if (self.@"else") |@"else"| {
            if (i < 1) return &@"else".base;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeIf) Token {
        return self.if_token;
    }

    pub fn lastToken(self: &NodeIf) Token {
        if (self.@"else") |@"else"| {
            return @"else".body.lastToken();
        }

        return self.body.lastToken();
    }
};

pub const NodeInfixOp = struct {
    base: Node,
    op_token: Token,
    lhs: &Node,
    op: InfixOp,
    rhs: &Node,

    const InfixOp = union(enum) {
        Add,
        AddWrap,
        ArrayCat,
        ArrayMult,
        Assign,
        AssignBitAnd,
        AssignBitOr,
        AssignBitShiftLeft,
        AssignBitShiftRight,
        AssignBitXor,
        AssignDiv,
        AssignMinus,
        AssignMinusWrap,
        AssignMod,
        AssignPlus,
        AssignPlusWrap,
        AssignTimes,
        AssignTimesWarp,
        BangEqual,
        BitAnd,
        BitOr,
        BitShiftLeft,
        BitShiftRight,
        BitXor,
        BoolAnd,
        BoolOr,
        Catch: ?&NodePayload,
        Div,
        EqualEqual,
        ErrorUnion,
        GreaterOrEqual,
        GreaterThan,
        LessOrEqual,
        LessThan,
        MergeErrorSets,
        Mod,
        Mult,
        MultWrap,
        Period,
        Range,
        Sub,
        SubWrap,
        UnwrapMaybe,
    };

    pub fn iterate(self: &NodeInfixOp, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.lhs;
        i -= 1;

        switch (self.op) {
            InfixOp.Catch => |maybe_payload| {
                if (maybe_payload) |payload| {
                    if (i < 1) return &payload.base;
                    i -= 1;
                }
            },

            InfixOp.Add,
            InfixOp.AddWrap,
            InfixOp.ArrayCat,
            InfixOp.ArrayMult,
            InfixOp.Assign,
            InfixOp.AssignBitAnd,
            InfixOp.AssignBitOr,
            InfixOp.AssignBitShiftLeft,
            InfixOp.AssignBitShiftRight,
            InfixOp.AssignBitXor,
            InfixOp.AssignDiv,
            InfixOp.AssignMinus,
            InfixOp.AssignMinusWrap,
            InfixOp.AssignMod,
            InfixOp.AssignPlus,
            InfixOp.AssignPlusWrap,
            InfixOp.AssignTimes,
            InfixOp.AssignTimesWarp,
            InfixOp.BangEqual,
            InfixOp.BitAnd,
            InfixOp.BitOr,
            InfixOp.BitShiftLeft,
            InfixOp.BitShiftRight,
            InfixOp.BitXor,
            InfixOp.BoolAnd,
            InfixOp.BoolOr,
            InfixOp.Div,
            InfixOp.EqualEqual,
            InfixOp.ErrorUnion,
            InfixOp.GreaterOrEqual,
            InfixOp.GreaterThan,
            InfixOp.LessOrEqual,
            InfixOp.LessThan,
            InfixOp.MergeErrorSets,
            InfixOp.Mod,
            InfixOp.Mult,
            InfixOp.MultWrap,
            InfixOp.Period,
            InfixOp.Range,
            InfixOp.Sub,
            InfixOp.SubWrap,
            InfixOp.UnwrapMaybe => {},
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeInfixOp) Token {
        return self.lhs.firstToken();
    }

    pub fn lastToken(self: &NodeInfixOp) Token {
        return self.rhs.lastToken();
    }
};

pub const NodePrefixOp = struct {
    base: Node,
    op_token: Token,
    op: PrefixOp,
    rhs: &Node,

    const PrefixOp = union(enum) {
        AddrOf: AddrOfInfo,
        ArrayType: &Node,
        Await,
        BitNot,
        BoolNot,
        Cancel,
        Deref,
        MaybeType,
        Negation,
        NegationWrap,
        Resume,
        SliceType: AddrOfInfo,
        Try,
        UnwrapMaybe,
    };

    const AddrOfInfo = struct {
        align_expr: ?&Node,
        bit_offset_start_token: ?Token,
        bit_offset_end_token: ?Token,
        const_token: ?Token,
        volatile_token: ?Token,
    };

    pub fn iterate(self: &NodePrefixOp, index: usize) ?&Node {
        var i = index;

        switch (self.op) {
            PrefixOp.SliceType => |addr_of_info| {
                if (addr_of_info.align_expr) |align_expr| {
                    if (i < 1) return align_expr;
                    i -= 1;
                }
            },
            PrefixOp.AddrOf => |addr_of_info| {
                if (addr_of_info.align_expr) |align_expr| {
                    if (i < 1) return align_expr;
                    i -= 1;
                }
            },
            PrefixOp.ArrayType => |size_expr| {
                if (i < 1) return size_expr;
                i -= 1;
            },
            PrefixOp.Await,
            PrefixOp.BitNot,
            PrefixOp.BoolNot,
            PrefixOp.Cancel,
            PrefixOp.Deref,
            PrefixOp.MaybeType,
            PrefixOp.Negation,
            PrefixOp.NegationWrap,
            PrefixOp.Try,
            PrefixOp.Resume,
            PrefixOp.UnwrapMaybe => {},
        }

        if (i < 1) return self.rhs;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodePrefixOp) Token {
        return self.op_token;
    }

    pub fn lastToken(self: &NodePrefixOp) Token {
        return self.rhs.lastToken();
    }
};

pub const NodeFieldInitializer = struct {
    base: Node,
    period_token: Token,
    name_token: Token,
    expr: &Node,

    pub fn iterate(self: &NodeFieldInitializer, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeFieldInitializer) Token {
        return self.period_token;
    }

    pub fn lastToken(self: &NodeFieldInitializer) Token {
        return self.expr.lastToken();
    }
};

pub const NodeSuffixOp = struct {
    base: Node,
    lhs: &Node,
    op: SuffixOp,
    rtoken: Token,

    const SuffixOp = union(enum) {
        Call: CallInfo,
        ArrayAccess: &Node,
        Slice: SliceRange,
        ArrayInitializer: ArrayList(&Node),
        StructInitializer: ArrayList(&NodeFieldInitializer),
    };

    const CallInfo = struct {
        params: ArrayList(&Node),
        async_attr: ?&NodeAsyncAttribute,
    };

    const SliceRange = struct {
        start: &Node,
        end: ?&Node,
    };

    pub fn iterate(self: &NodeSuffixOp, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.lhs;
        i -= 1;

        switch (self.op) {
            SuffixOp.Call => |call_info| {
                if (i < call_info.params.len) return call_info.params.at(i);
                i -= call_info.params.len;
            },
            SuffixOp.ArrayAccess => |index_expr| {
                if (i < 1) return index_expr;
                i -= 1;
            },
            SuffixOp.Slice => |range| {
                if (i < 1) return range.start;
                i -= 1;

                if (range.end) |end| {
                    if (i < 1) return end;
                    i -= 1;
                }
            },
            SuffixOp.ArrayInitializer => |exprs| {
                if (i < exprs.len) return exprs.at(i);
                i -= exprs.len;
            },
            SuffixOp.StructInitializer => |fields| {
                if (i < fields.len) return &fields.at(i).base;
                i -= fields.len;
            },
        }

        return null;
    }

    pub fn firstToken(self: &NodeSuffixOp) Token {
        return self.lhs.firstToken();
    }

    pub fn lastToken(self: &NodeSuffixOp) Token {
        return self.rtoken;
    }
};

pub const NodeGroupedExpression = struct {
    base: Node,
    lparen: Token,
    expr: &Node,
    rparen: Token,

    pub fn iterate(self: &NodeGroupedExpression, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeGroupedExpression) Token {
        return self.lparen;
    }

    pub fn lastToken(self: &NodeGroupedExpression) Token {
        return self.rparen;
    }
};

pub const NodeControlFlowExpression = struct {
    base: Node,
    ltoken: Token,
    kind: Kind,
    rhs: ?&Node,

    const Kind = union(enum) {
        Break: ?Token,
        Continue: ?Token,
        Return,
    };

    pub fn iterate(self: &NodeControlFlowExpression, index: usize) ?&Node {
        var i = index;

        if (self.rhs) |rhs| {
            if (i < 1) return rhs;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeControlFlowExpression) Token {
        return self.ltoken;
    }

    pub fn lastToken(self: &NodeControlFlowExpression) Token {
        if (self.rhs) |rhs| {
            return rhs.lastToken();
        }

        switch (self.kind) {
            Kind.Break => |maybe_blk_token| {
                if (maybe_blk_token) |blk_token| {
                    return blk_token;
                }
            },
            Kind.Continue => |maybe_blk_token| {
                if (maybe_blk_token) |blk_token| {
                    return blk_token;
                }
            },
            Kind.Return => return self.ltoken,
        }

        return self.ltoken;
    }
};

pub const NodeSuspend = struct {
    base: Node,
    suspend_token: Token,
    payload: ?&NodePayload,
    body: ?&Node,

    pub fn iterate(self: &NodeSuspend, index: usize) ?&Node {
        var i = index;

        if (self.payload) |payload| {
            if (i < 1) return &payload.base;
            i -= 1;
        }

        if (self.body) |body| {
            if (i < 1) return body;
            i -= 1;
        }

        return null;
    }

    pub fn firstToken(self: &NodeSuspend) Token {
        return self.suspend_token;
    }

    pub fn lastToken(self: &NodeSuspend) Token {
        if (self.body) |body| {
            return body.lastToken();
        }

        if (self.payload) |payload| {
            return payload.lastToken();
        }

        return self.suspend_token;
    }
};

pub const NodeIntegerLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeIntegerLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeIntegerLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeIntegerLiteral) Token {
        return self.token;
    }
};

pub const NodeFloatLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeFloatLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeFloatLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeFloatLiteral) Token {
        return self.token;
    }
};

pub const NodeBuiltinCall = struct {
    base: Node,
    builtin_token: Token,
    params: ArrayList(&Node),
    rparen_token: Token,

    pub fn iterate(self: &NodeBuiltinCall, index: usize) ?&Node {
        var i = index;

        if (i < self.params.len) return self.params.at(i);
        i -= self.params.len;

        return null;
    }

    pub fn firstToken(self: &NodeBuiltinCall) Token {
        return self.builtin_token;
    }

    pub fn lastToken(self: &NodeBuiltinCall) Token {
        return self.rparen_token;
    }
};

pub const NodeStringLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeStringLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeStringLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeStringLiteral) Token {
        return self.token;
    }
};

pub const NodeMultilineStringLiteral = struct {
    base: Node,
    tokens: ArrayList(Token),

    pub fn iterate(self: &NodeMultilineStringLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeMultilineStringLiteral) Token {
        return self.tokens.at(0);
    }

    pub fn lastToken(self: &NodeMultilineStringLiteral) Token {
        return self.tokens.at(self.tokens.len - 1);
    }
};

pub const NodeCharLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeCharLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeCharLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeCharLiteral) Token {
        return self.token;
    }
};

pub const NodeBoolLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeBoolLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeBoolLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeBoolLiteral) Token {
        return self.token;
    }
};

pub const NodeNullLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeNullLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeNullLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeNullLiteral) Token {
        return self.token;
    }
};

pub const NodeUndefinedLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeUndefinedLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeUndefinedLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeUndefinedLiteral) Token {
        return self.token;
    }
};

pub const NodeThisLiteral = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeThisLiteral, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeThisLiteral) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeThisLiteral) Token {
        return self.token;
    }
};

pub const NodeAsmOutput = struct {
    base: Node,
    symbolic_name: &NodeIdentifier,
    constraint: &NodeStringLiteral,
    kind: Kind,

    const Kind = union(enum) {
        Variable: &NodeIdentifier,
        Return: &Node
    };

    pub fn iterate(self: &NodeAsmOutput, index: usize) ?&Node {
        var i = index;

        if (i < 1) return &self.symbolic_name.base;
        i -= 1;

        if (i < 1) return &self.constraint.base;
        i -= 1;

        switch (self.kind) {
            Kind.Variable => |variable_name| {
                if (i < 1) return &variable_name.base;
                i -= 1;
            },
            Kind.Return => |return_type| {
                if (i < 1) return return_type;
                i -= 1;
            }
        }

        return null;
    }

    pub fn firstToken(self: &NodeAsmOutput) Token {
        return self.symbolic_name.firstToken();
    }

    pub fn lastToken(self: &NodeAsmOutput) Token {
        return switch (self.kind) {
            Kind.Variable => |variable_name| variable_name.lastToken(),
            Kind.Return => |return_type| return_type.lastToken(),
        };
    }
};

pub const NodeAsmInput = struct {
    base: Node,
    symbolic_name: &NodeIdentifier,
    constraint: &NodeStringLiteral,
    expr: &Node,

    pub fn iterate(self: &NodeAsmInput, index: usize) ?&Node {
        var i = index;

        if (i < 1) return &self.symbolic_name.base;
        i -= 1;

        if (i < 1) return &self.constraint.base;
        i -= 1;

        if (i < 1) return self.expr;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeAsmInput) Token {
        return self.symbolic_name.firstToken();
    }

    pub fn lastToken(self: &NodeAsmInput) Token {
        return self.expr.lastToken();
    }
};

pub const NodeAsm = struct {
    base: Node,
    asm_token: Token,
    is_volatile: bool,
    template: Token,
    //tokens: ArrayList(AsmToken),
    outputs: ArrayList(&NodeAsmOutput),
    inputs: ArrayList(&NodeAsmInput),
    cloppers: ArrayList(&NodeStringLiteral),
    rparen: Token,

    pub fn iterate(self: &NodeAsm, index: usize) ?&Node {
        var i = index;

        if (i < self.outputs.len) return &self.outputs.at(index).base;
        i -= self.outputs.len;

        if (i < self.inputs.len) return &self.inputs.at(index).base;
        i -= self.inputs.len;

        if (i < self.cloppers.len) return &self.cloppers.at(index).base;
        i -= self.cloppers.len;

        return null;
    }

    pub fn firstToken(self: &NodeAsm) Token {
        return self.asm_token;
    }

    pub fn lastToken(self: &NodeAsm) Token {
        return self.rparen;
    }
};

pub const NodeUnreachable = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeUnreachable, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeUnreachable) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeUnreachable) Token {
        return self.token;
    }
};

pub const NodeErrorType = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeErrorType, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeErrorType) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeErrorType) Token {
        return self.token;
    }
};

pub const NodeVarType = struct {
    base: Node,
    token: Token,

    pub fn iterate(self: &NodeVarType, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeVarType) Token {
        return self.token;
    }

    pub fn lastToken(self: &NodeVarType) Token {
        return self.token;
    }
};

pub const NodeLineComment = struct {
    base: Node,
    lines: ArrayList(Token),

    pub fn iterate(self: &NodeLineComment, index: usize) ?&Node {
        return null;
    }

    pub fn firstToken(self: &NodeLineComment) Token {
        return self.lines.at(0);
    }

    pub fn lastToken(self: &NodeLineComment) Token {
        return self.lines.at(self.lines.len - 1);
    }
};

pub const NodeTestDecl = struct {
    base: Node,
    test_token: Token,
    name: &Node,
    body_node: &Node,

    pub fn iterate(self: &NodeTestDecl, index: usize) ?&Node {
        var i = index;

        if (i < 1) return self.body_node;
        i -= 1;

        return null;
    }

    pub fn firstToken(self: &NodeTestDecl) Token {
        return self.test_token;
    }

    pub fn lastToken(self: &NodeTestDecl) Token {
        return self.body_node.lastToken();
    }
};
