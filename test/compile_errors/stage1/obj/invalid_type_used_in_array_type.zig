const Item = struct {
    field: SomeNonexistentType,
};
var items: [100]Item = undefined;
export fn entry() void {
    const a = items[0];
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:12: error: use of undeclared identifier 'SomeNonexistentType'
