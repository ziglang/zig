pub const Scope = struct {
    id: Id,
    parent: *Scope,

    pub const Id = enum {
        Decls,
        Block,
        Defer,
        DeferExpr,
        VarDecl,
        CImport,
        Loop,
        FnDef,
        CompTime,
    };
};
