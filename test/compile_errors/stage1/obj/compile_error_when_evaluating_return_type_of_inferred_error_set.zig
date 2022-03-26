const Car = struct {
    foo: *SymbolThatDoesNotExist,
    pub fn init() !Car {}
};
export fn entry() void {
    const car = Car.init();
    _ = car;
}

// compile error when evaluating return type of inferred error set
//
// tmp.zig:2:11: error: use of undeclared identifier 'SymbolThatDoesNotExist'
