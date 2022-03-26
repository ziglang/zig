const Item = struct {
    field: SomeNonexistentType,
};
var items: [100]Item = undefined;
export fn entry() void {
    const a = items[0];
    _ = a;
}

// invalid type used in array type
//
// tmp.zig:2:12: error: use of undeclared identifier 'SomeNonexistentType'
