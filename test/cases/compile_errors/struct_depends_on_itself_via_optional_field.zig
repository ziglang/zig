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
// backend=stage2
// target=native
//
// :1:17: error: struct 'tmp.LhsExpr' depends on itself
// :5:5: note: while checking this field
// :2:5: note: while checking this field
