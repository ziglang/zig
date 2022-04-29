const Car = struct {
    foo: *SymbolThatDoesNotExist,
    pub fn init() !Car {}
};
export fn entry() void {
    const car = Car.init();
    _ = car;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:11: error: use of undeclared identifier 'SymbolThatDoesNotExist'
