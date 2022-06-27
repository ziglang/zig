const Item = struct {
    field: SomeNonexistentType,
};
var items: [100]Item = undefined;
export fn entry() void {
    const a = items[0];
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:12: error: use of undeclared identifier 'SomeNonexistentType'
