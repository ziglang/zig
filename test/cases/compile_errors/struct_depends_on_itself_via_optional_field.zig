const LhsExpr = struct {
    rhsExpr: ?AstObject,
};
const AstObject = union {
    lhsExpr: LhsExpr,
};
export fn entry() void {
    const lhsExpr = LhsExpr{ .rhsExpr = null };
    const obj = AstObject{ .lhsExpr = lhsExpr };
    _ = obj;
}

// error
//
// :1:17: error: struct 'tmp.LhsExpr' depends on itself
