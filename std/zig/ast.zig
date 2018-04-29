const std = @import("../index.zig");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Token = std.zig.Token;
const mem = std.mem;

pub const Node = struct {
    id: Id,
    before_comments: ?&LineComment,
    same_line_comment: ?&Token,

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

    pub fn iterate(base: &Node, index: usize) ?&Node {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).iterate(index);
            }
        }
        unreachable;
    }

    pub fn firstToken(base: &Node) Token {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).firstToken();
            }
        }
        unreachable;
    }

    pub fn lastToken(base: &Node) Token {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (base.id == @field(Id, @memberName(Id, i))) {
                const T = @field(Node, @memberName(Id, i));
                return @fieldParentPtr(T, "base", base).lastToken();
            }
        }
        unreachable;
    }

    pub fn typeToId(comptime T: type) Id {
        comptime var i = 0;
        inline while (i < @memberCount(Id)) : (i += 1) {
            if (T == @field(Node, @memberName(Id, i))) {
                return @field(Id, @memberName(Id, i));
            }
        }
        unreachable;
    }

    pub const Root = struct {
        base: Node,
        decls: ArrayList(&Node),
        eof_token: Token,

        pub fn iterate(self: &Root, index: usize) ?&Node {
            if (index < self.decls.len) {
                return self.decls.items[self.decls.len - index - 1];
            }
            return null;
        }

        pub fn firstToken(self: &Root) Token {
            return if (self.decls.len == 0) self.eof_token else self.decls.at(0).firstToken();
        }

        pub fn lastToken(self: &Root) Token {
            return if (self.decls.len == 0) self.eof_token else self.decls.at(self.decls.len - 1).lastToken();
        }
    };

    pub const VarDecl = struct {
        base: Node,
        visib_token: ?Token,
        name_token: Token,
        eq_token: Token,
        mut_token: Token,
        comptime_token: ?Token,
        extern_export_token: ?Token,
        lib_name: ?&Node,
        type_node: ?&Node,
        align_node: ?&Node,
        init_node: ?&Node,
        semicolon_token: Token,

        pub fn iterate(self: &VarDecl, index: usize) ?&Node {
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

        pub fn firstToken(self: &VarDecl) Token {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.extern_export_token) |extern_export_token| return extern_export_token;
            assert(self.lib_name == null);
            return self.mut_token;
        }

        pub fn lastToken(self: &VarDecl) Token {
            return self.semicolon_token;
        }
    };

    pub const Use = struct {
        base: Node,
        visib_token: ?Token,
        expr: &Node,
        semicolon_token: Token,

        pub fn iterate(self: &Use, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &Use) Token {
            if (self.visib_token) |visib_token| return visib_token;
            return self.expr.firstToken();
        }

        pub fn lastToken(self: &Use) Token {
            return self.semicolon_token;
        }
    };

    pub const ErrorSetDecl = struct {
        base: Node,
        error_token: Token,
        decls: ArrayList(&Node),
        rbrace_token: Token,

        pub fn iterate(self: &ErrorSetDecl, index: usize) ?&Node {
            var i = index;

            if (i < self.decls.len) return self.decls.at(i);
            i -= self.decls.len;

            return null;
        }

        pub fn firstToken(self: &ErrorSetDecl) Token {
            return self.error_token;
        }

        pub fn lastToken(self: &ErrorSetDecl) Token {
            return self.rbrace_token;
        }
    };

    pub const ContainerDecl = struct {
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

        pub fn iterate(self: &ContainerDecl, index: usize) ?&Node {
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

        pub fn firstToken(self: &ContainerDecl) Token {
            return self.ltoken;
        }

        pub fn lastToken(self: &ContainerDecl) Token {
            return self.rbrace_token;
        }
    };

    pub const StructField = struct {
        base: Node,
        visib_token: ?Token,
        name_token: Token,
        type_expr: &Node,

        pub fn iterate(self: &StructField, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.type_expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &StructField) Token {
            if (self.visib_token) |visib_token| return visib_token;
            return self.name_token;
        }

        pub fn lastToken(self: &StructField) Token {
            return self.type_expr.lastToken();
        }
    };

    pub const UnionTag = struct {
        base: Node,
        name_token: Token,
        type_expr: ?&Node,

        pub fn iterate(self: &UnionTag, index: usize) ?&Node {
            var i = index;

            if (self.type_expr) |type_expr| {
                if (i < 1) return type_expr;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &UnionTag) Token {
            return self.name_token;
        }

        pub fn lastToken(self: &UnionTag) Token {
            if (self.type_expr) |type_expr| {
                return type_expr.lastToken();
            }

            return self.name_token;
        }
    };

    pub const EnumTag = struct {
        base: Node,
        name_token: Token,
        value: ?&Node,

        pub fn iterate(self: &EnumTag, index: usize) ?&Node {
            var i = index;

            if (self.value) |value| {
                if (i < 1) return value;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &EnumTag) Token {
            return self.name_token;
        }

        pub fn lastToken(self: &EnumTag) Token {
            if (self.value) |value| {
                return value.lastToken();
            }

            return self.name_token;
        }
    };

    pub const Identifier = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &Identifier, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &Identifier) Token {
            return self.token;
        }

        pub fn lastToken(self: &Identifier) Token {
            return self.token;
        }
    };

    pub const AsyncAttribute = struct {
        base: Node,
        async_token: Token,
        allocator_type: ?&Node,
        rangle_bracket: ?Token,

        pub fn iterate(self: &AsyncAttribute, index: usize) ?&Node {
            var i = index;

            if (self.allocator_type) |allocator_type| {
                if (i < 1) return allocator_type;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &AsyncAttribute) Token {
            return self.async_token;
        }

        pub fn lastToken(self: &AsyncAttribute) Token {
            if (self.rangle_bracket) |rangle_bracket| {
                return rangle_bracket;
            }

            return self.async_token;
        }
    };

    pub const FnProto = struct {
        base: Node,
        visib_token: ?Token,
        fn_token: Token,
        name_token: ?Token,
        params: ArrayList(&Node),
        return_type: ReturnType,
        var_args_token: ?Token,
        extern_export_inline_token: ?Token,
        cc_token: ?Token,
        async_attr: ?&AsyncAttribute,
        body_node: ?&Node,
        lib_name: ?&Node, // populated if this is an extern declaration
        align_expr: ?&Node, // populated if align(A) is present

        pub const ReturnType = union(enum) {
            Explicit: &Node,
            InferErrorSet: &Node,
        };

        pub fn iterate(self: &FnProto, index: usize) ?&Node {
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

        pub fn firstToken(self: &FnProto) Token {
            if (self.visib_token) |visib_token| return visib_token;
            if (self.extern_export_inline_token) |extern_export_inline_token| return extern_export_inline_token;
            assert(self.lib_name == null);
            if (self.cc_token) |cc_token| return cc_token;
            return self.fn_token;
        }

        pub fn lastToken(self: &FnProto) Token {
            if (self.body_node) |body_node| return body_node.lastToken();
            switch (self.return_type) {
                // TODO allow this and next prong to share bodies since the types are the same
                ReturnType.Explicit => |node| return node.lastToken(),
                ReturnType.InferErrorSet => |node| return node.lastToken(),
            }
        }
    };

    pub const ParamDecl = struct {
        base: Node,
        comptime_token: ?Token,
        noalias_token: ?Token,
        name_token: ?Token,
        type_node: &Node,
        var_args_token: ?Token,

        pub fn iterate(self: &ParamDecl, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.type_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &ParamDecl) Token {
            if (self.comptime_token) |comptime_token| return comptime_token;
            if (self.noalias_token) |noalias_token| return noalias_token;
            if (self.name_token) |name_token| return name_token;
            return self.type_node.firstToken();
        }

        pub fn lastToken(self: &ParamDecl) Token {
            if (self.var_args_token) |var_args_token| return var_args_token;
            return self.type_node.lastToken();
        }
    };

    pub const Block = struct {
        base: Node,
        label: ?Token,
        lbrace: Token,
        statements: ArrayList(&Node),
        rbrace: Token,

        pub fn iterate(self: &Block, index: usize) ?&Node {
            var i = index;

            if (i < self.statements.len) return self.statements.items[i];
            i -= self.statements.len;

            return null;
        }

        pub fn firstToken(self: &Block) Token {
            if (self.label) |label| {
                return label;
            }

            return self.lbrace;
        }

        pub fn lastToken(self: &Block) Token {
            return self.rbrace;
        }
    };

    pub const Defer = struct {
        base: Node,
        defer_token: Token,
        kind: Kind,
        expr: &Node,

        const Kind = enum {
            Error,
            Unconditional,
        };

        pub fn iterate(self: &Defer, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &Defer) Token {
            return self.defer_token;
        }

        pub fn lastToken(self: &Defer) Token {
            return self.expr.lastToken();
        }
    };

    pub const Comptime = struct {
        base: Node,
        comptime_token: Token,
        expr: &Node,

        pub fn iterate(self: &Comptime, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &Comptime) Token {
            return self.comptime_token;
        }

        pub fn lastToken(self: &Comptime) Token {
            return self.expr.lastToken();
        }
    };

    pub const Payload = struct {
        base: Node,
        lpipe: Token,
        error_symbol: &Node,
        rpipe: Token,

        pub fn iterate(self: &Payload, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.error_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &Payload) Token {
            return self.lpipe;
        }

        pub fn lastToken(self: &Payload) Token {
            return self.rpipe;
        }
    };

    pub const PointerPayload = struct {
        base: Node,
        lpipe: Token,
        ptr_token: ?Token,
        value_symbol: &Node,
        rpipe: Token,

        pub fn iterate(self: &PointerPayload, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &PointerPayload) Token {
            return self.lpipe;
        }

        pub fn lastToken(self: &PointerPayload) Token {
            return self.rpipe;
        }
    };

    pub const PointerIndexPayload = struct {
        base: Node,
        lpipe: Token,
        ptr_token: ?Token,
        value_symbol: &Node,
        index_symbol: ?&Node,
        rpipe: Token,

        pub fn iterate(self: &PointerIndexPayload, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.value_symbol;
            i -= 1;

            if (self.index_symbol) |index_symbol| {
                if (i < 1) return index_symbol;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &PointerIndexPayload) Token {
            return self.lpipe;
        }

        pub fn lastToken(self: &PointerIndexPayload) Token {
            return self.rpipe;
        }
    };

    pub const Else = struct {
        base: Node,
        else_token: Token,
        payload: ?&Node,
        body: &Node,

        pub fn iterate(self: &Else, index: usize) ?&Node {
            var i = index;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.body;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &Else) Token {
            return self.else_token;
        }

        pub fn lastToken(self: &Else) Token {
            return self.body.lastToken();
        }
    };

    pub const Switch = struct {
        base: Node,
        switch_token: Token,
        expr: &Node,
        cases: ArrayList(&SwitchCase),
        rbrace: Token,

        pub fn iterate(self: &Switch, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            if (i < self.cases.len) return &self.cases.at(i).base;
            i -= self.cases.len;

            return null;
        }

        pub fn firstToken(self: &Switch) Token {
            return self.switch_token;
        }

        pub fn lastToken(self: &Switch) Token {
            return self.rbrace;
        }
    };

    pub const SwitchCase = struct {
        base: Node,
        items: ArrayList(&Node),
        payload: ?&Node,
        expr: &Node,

        pub fn iterate(self: &SwitchCase, index: usize) ?&Node {
            var i = index;

            if (i < self.items.len) return self.items.at(i);
            i -= self.items.len;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &SwitchCase) Token {
            return self.items.at(0).firstToken();
        }

        pub fn lastToken(self: &SwitchCase) Token {
            return self.expr.lastToken();
        }
    };

    pub const SwitchElse = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &SwitchElse, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &SwitchElse) Token {
            return self.token;
        }

        pub fn lastToken(self: &SwitchElse) Token {
            return self.token;
        }
    };

    pub const While = struct {
        base: Node,
        label: ?Token,
        inline_token: ?Token,
        while_token: Token,
        condition: &Node,
        payload: ?&Node,
        continue_expr: ?&Node,
        body: &Node,
        @"else": ?&Else,

        pub fn iterate(self: &While, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
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

        pub fn firstToken(self: &While) Token {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.while_token;
        }

        pub fn lastToken(self: &While) Token {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const For = struct {
        base: Node,
        label: ?Token,
        inline_token: ?Token,
        for_token: Token,
        array_expr: &Node,
        payload: ?&Node,
        body: &Node,
        @"else": ?&Else,

        pub fn iterate(self: &For, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.array_expr;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
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

        pub fn firstToken(self: &For) Token {
            if (self.label) |label| {
                return label;
            }

            if (self.inline_token) |inline_token| {
                return inline_token;
            }

            return self.for_token;
        }

        pub fn lastToken(self: &For) Token {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const If = struct {
        base: Node,
        if_token: Token,
        condition: &Node,
        payload: ?&Node,
        body: &Node,
        @"else": ?&Else,

        pub fn iterate(self: &If, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.condition;
            i -= 1;

            if (self.payload) |payload| {
                if (i < 1) return payload;
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

        pub fn firstToken(self: &If) Token {
            return self.if_token;
        }

        pub fn lastToken(self: &If) Token {
            if (self.@"else") |@"else"| {
                return @"else".body.lastToken();
            }

            return self.body.lastToken();
        }
    };

    pub const InfixOp = struct {
        base: Node,
        op_token: Token,
        lhs: &Node,
        op: Op,
        rhs: &Node,

        pub const Op = union(enum) {
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
            Catch: ?&Node,
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

        pub fn iterate(self: &InfixOp, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                Op.Catch => |maybe_payload| {
                    if (maybe_payload) |payload| {
                        if (i < 1) return payload;
                        i -= 1;
                    }
                },

                Op.Add,
                Op.AddWrap,
                Op.ArrayCat,
                Op.ArrayMult,
                Op.Assign,
                Op.AssignBitAnd,
                Op.AssignBitOr,
                Op.AssignBitShiftLeft,
                Op.AssignBitShiftRight,
                Op.AssignBitXor,
                Op.AssignDiv,
                Op.AssignMinus,
                Op.AssignMinusWrap,
                Op.AssignMod,
                Op.AssignPlus,
                Op.AssignPlusWrap,
                Op.AssignTimes,
                Op.AssignTimesWarp,
                Op.BangEqual,
                Op.BitAnd,
                Op.BitOr,
                Op.BitShiftLeft,
                Op.BitShiftRight,
                Op.BitXor,
                Op.BoolAnd,
                Op.BoolOr,
                Op.Div,
                Op.EqualEqual,
                Op.ErrorUnion,
                Op.GreaterOrEqual,
                Op.GreaterThan,
                Op.LessOrEqual,
                Op.LessThan,
                Op.MergeErrorSets,
                Op.Mod,
                Op.Mult,
                Op.MultWrap,
                Op.Period,
                Op.Range,
                Op.Sub,
                Op.SubWrap,
                Op.UnwrapMaybe => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &InfixOp) Token {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: &InfixOp) Token {
            return self.rhs.lastToken();
        }
    };

    pub const PrefixOp = struct {
        base: Node,
        op_token: Token,
        op: Op,
        rhs: &Node,

        const Op = union(enum) {
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

        pub fn iterate(self: &PrefixOp, index: usize) ?&Node {
            var i = index;

            switch (self.op) {
                Op.SliceType => |addr_of_info| {
                    if (addr_of_info.align_expr) |align_expr| {
                        if (i < 1) return align_expr;
                        i -= 1;
                    }
                },
                Op.AddrOf => |addr_of_info| {
                    if (addr_of_info.align_expr) |align_expr| {
                        if (i < 1) return align_expr;
                        i -= 1;
                    }
                },
                Op.ArrayType => |size_expr| {
                    if (i < 1) return size_expr;
                    i -= 1;
                },
                Op.Await,
                Op.BitNot,
                Op.BoolNot,
                Op.Cancel,
                Op.Deref,
                Op.MaybeType,
                Op.Negation,
                Op.NegationWrap,
                Op.Try,
                Op.Resume,
                Op.UnwrapMaybe => {},
            }

            if (i < 1) return self.rhs;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &PrefixOp) Token {
            return self.op_token;
        }

        pub fn lastToken(self: &PrefixOp) Token {
            return self.rhs.lastToken();
        }
    };

    pub const FieldInitializer = struct {
        base: Node,
        period_token: Token,
        name_token: Token,
        expr: &Node,

        pub fn iterate(self: &FieldInitializer, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &FieldInitializer) Token {
            return self.period_token;
        }

        pub fn lastToken(self: &FieldInitializer) Token {
            return self.expr.lastToken();
        }
    };

    pub const SuffixOp = struct {
        base: Node,
        lhs: &Node,
        op: Op,
        rtoken: Token,

        const Op = union(enum) {
            Call: CallInfo,
            ArrayAccess: &Node,
            Slice: SliceRange,
            ArrayInitializer: ArrayList(&Node),
            StructInitializer: ArrayList(&FieldInitializer),
        };

        const CallInfo = struct {
            params: ArrayList(&Node),
            async_attr: ?&AsyncAttribute,
        };

        const SliceRange = struct {
            start: &Node,
            end: ?&Node,
        };

        pub fn iterate(self: &SuffixOp, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.lhs;
            i -= 1;

            switch (self.op) {
                Op.Call => |call_info| {
                    if (i < call_info.params.len) return call_info.params.at(i);
                    i -= call_info.params.len;
                },
                Op.ArrayAccess => |index_expr| {
                    if (i < 1) return index_expr;
                    i -= 1;
                },
                Op.Slice => |range| {
                    if (i < 1) return range.start;
                    i -= 1;

                    if (range.end) |end| {
                        if (i < 1) return end;
                        i -= 1;
                    }
                },
                Op.ArrayInitializer => |exprs| {
                    if (i < exprs.len) return exprs.at(i);
                    i -= exprs.len;
                },
                Op.StructInitializer => |fields| {
                    if (i < fields.len) return &fields.at(i).base;
                    i -= fields.len;
                },
            }

            return null;
        }

        pub fn firstToken(self: &SuffixOp) Token {
            return self.lhs.firstToken();
        }

        pub fn lastToken(self: &SuffixOp) Token {
            return self.rtoken;
        }
    };

    pub const GroupedExpression = struct {
        base: Node,
        lparen: Token,
        expr: &Node,
        rparen: Token,

        pub fn iterate(self: &GroupedExpression, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &GroupedExpression) Token {
            return self.lparen;
        }

        pub fn lastToken(self: &GroupedExpression) Token {
            return self.rparen;
        }
    };

    pub const ControlFlowExpression = struct {
        base: Node,
        ltoken: Token,
        kind: Kind,
        rhs: ?&Node,

        const Kind = union(enum) {
            Break: ?&Node,
            Continue: ?&Node,
            Return,
        };

        pub fn iterate(self: &ControlFlowExpression, index: usize) ?&Node {
            var i = index;

            switch (self.kind) {
                Kind.Break => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                Kind.Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        if (i < 1) return label;
                        i -= 1;
                    }
                },
                Kind.Return => {},
            }

            if (self.rhs) |rhs| {
                if (i < 1) return rhs;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &ControlFlowExpression) Token {
            return self.ltoken;
        }

        pub fn lastToken(self: &ControlFlowExpression) Token {
            if (self.rhs) |rhs| {
                return rhs.lastToken();
            }

            switch (self.kind) {
                Kind.Break => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                Kind.Continue => |maybe_label| {
                    if (maybe_label) |label| {
                        return label.lastToken();
                    }
                },
                Kind.Return => return self.ltoken,
            }

            return self.ltoken;
        }
    };

    pub const Suspend = struct {
        base: Node,
        suspend_token: Token,
        payload: ?&Node,
        body: ?&Node,

        pub fn iterate(self: &Suspend, index: usize) ?&Node {
            var i = index;

            if (self.payload) |payload| {
                if (i < 1) return payload;
                i -= 1;
            }

            if (self.body) |body| {
                if (i < 1) return body;
                i -= 1;
            }

            return null;
        }

        pub fn firstToken(self: &Suspend) Token {
            return self.suspend_token;
        }

        pub fn lastToken(self: &Suspend) Token {
            if (self.body) |body| {
                return body.lastToken();
            }

            if (self.payload) |payload| {
                return payload.lastToken();
            }

            return self.suspend_token;
        }
    };

    pub const IntegerLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &IntegerLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &IntegerLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &IntegerLiteral) Token {
            return self.token;
        }
    };

    pub const FloatLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &FloatLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &FloatLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &FloatLiteral) Token {
            return self.token;
        }
    };

    pub const BuiltinCall = struct {
        base: Node,
        builtin_token: Token,
        params: ArrayList(&Node),
        rparen_token: Token,

        pub fn iterate(self: &BuiltinCall, index: usize) ?&Node {
            var i = index;

            if (i < self.params.len) return self.params.at(i);
            i -= self.params.len;

            return null;
        }

        pub fn firstToken(self: &BuiltinCall) Token {
            return self.builtin_token;
        }

        pub fn lastToken(self: &BuiltinCall) Token {
            return self.rparen_token;
        }
    };

    pub const StringLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &StringLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &StringLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &StringLiteral) Token {
            return self.token;
        }
    };

    pub const MultilineStringLiteral = struct {
        base: Node,
        tokens: ArrayList(Token),

        pub fn iterate(self: &MultilineStringLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &MultilineStringLiteral) Token {
            return self.tokens.at(0);
        }

        pub fn lastToken(self: &MultilineStringLiteral) Token {
            return self.tokens.at(self.tokens.len - 1);
        }
    };

    pub const CharLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &CharLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &CharLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &CharLiteral) Token {
            return self.token;
        }
    };

    pub const BoolLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &BoolLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &BoolLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &BoolLiteral) Token {
            return self.token;
        }
    };

    pub const NullLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &NullLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &NullLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &NullLiteral) Token {
            return self.token;
        }
    };

    pub const UndefinedLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &UndefinedLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &UndefinedLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &UndefinedLiteral) Token {
            return self.token;
        }
    };

    pub const ThisLiteral = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &ThisLiteral, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &ThisLiteral) Token {
            return self.token;
        }

        pub fn lastToken(self: &ThisLiteral) Token {
            return self.token;
        }
    };

    pub const AsmOutput = struct {
        base: Node,
        symbolic_name: &Node,
        constraint: &Node,
        kind: Kind,

        const Kind = union(enum) {
            Variable: &Identifier,
            Return: &Node
        };

        pub fn iterate(self: &AsmOutput, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
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

        pub fn firstToken(self: &AsmOutput) Token {
            return self.symbolic_name.firstToken();
        }

        pub fn lastToken(self: &AsmOutput) Token {
            return switch (self.kind) {
                Kind.Variable => |variable_name| variable_name.lastToken(),
                Kind.Return => |return_type| return_type.lastToken(),
            };
        }
    };

    pub const AsmInput = struct {
        base: Node,
        symbolic_name: &Node,
        constraint: &Node,
        expr: &Node,

        pub fn iterate(self: &AsmInput, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.symbolic_name;
            i -= 1;

            if (i < 1) return self.constraint;
            i -= 1;

            if (i < 1) return self.expr;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &AsmInput) Token {
            return self.symbolic_name.firstToken();
        }

        pub fn lastToken(self: &AsmInput) Token {
            return self.expr.lastToken();
        }
    };

    pub const Asm = struct {
        base: Node,
        asm_token: Token,
        volatile_token: ?Token,
        template: &Node,
        //tokens: ArrayList(AsmToken),
        outputs: ArrayList(&AsmOutput),
        inputs: ArrayList(&AsmInput),
        cloppers: ArrayList(&Node),
        rparen: Token,

        pub fn iterate(self: &Asm, index: usize) ?&Node {
            var i = index;

            if (i < self.outputs.len) return &self.outputs.at(index).base;
            i -= self.outputs.len;

            if (i < self.inputs.len) return &self.inputs.at(index).base;
            i -= self.inputs.len;

            if (i < self.cloppers.len) return self.cloppers.at(index);
            i -= self.cloppers.len;

            return null;
        }

        pub fn firstToken(self: &Asm) Token {
            return self.asm_token;
        }

        pub fn lastToken(self: &Asm) Token {
            return self.rparen;
        }
    };

    pub const Unreachable = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &Unreachable, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &Unreachable) Token {
            return self.token;
        }

        pub fn lastToken(self: &Unreachable) Token {
            return self.token;
        }
    };

    pub const ErrorType = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &ErrorType, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &ErrorType) Token {
            return self.token;
        }

        pub fn lastToken(self: &ErrorType) Token {
            return self.token;
        }
    };

    pub const VarType = struct {
        base: Node,
        token: Token,

        pub fn iterate(self: &VarType, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &VarType) Token {
            return self.token;
        }

        pub fn lastToken(self: &VarType) Token {
            return self.token;
        }
    };

    pub const LineComment = struct {
        base: Node,
        lines: ArrayList(Token),

        pub fn iterate(self: &LineComment, index: usize) ?&Node {
            return null;
        }

        pub fn firstToken(self: &LineComment) Token {
            return self.lines.at(0);
        }

        pub fn lastToken(self: &LineComment) Token {
            return self.lines.at(self.lines.len - 1);
        }
    };

    pub const TestDecl = struct {
        base: Node,
        test_token: Token,
        name: &Node,
        body_node: &Node,

        pub fn iterate(self: &TestDecl, index: usize) ?&Node {
            var i = index;

            if (i < 1) return self.body_node;
            i -= 1;

            return null;
        }

        pub fn firstToken(self: &TestDecl) Token {
            return self.test_token;
        }

        pub fn lastToken(self: &TestDecl) Token {
            return self.body_node.lastToken();
        }
    };
};

