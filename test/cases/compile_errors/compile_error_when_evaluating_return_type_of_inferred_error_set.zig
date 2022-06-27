const Car = struct {
    foo: *SymbolThatDoesNotExist,
    pub fn init() !Car {}
};
export fn entry() void {
    const car = Car.init();
    _ = car;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: use of undeclared identifier 'SymbolThatDoesNotExist'
