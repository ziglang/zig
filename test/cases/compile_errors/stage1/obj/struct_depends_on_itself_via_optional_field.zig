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
// backend=stage1
// target=native
//
// tmp.zig:1:17: error: struct 'LhsExpr' depends on itself
// tmp.zig:5:5: note: while checking this field
// tmp.zig:2:5: note: while checking this field
