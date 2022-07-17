pub const List = struct {
    len: usize,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) List {
        return List {
            .len = 0,
            .allocator = allocator,
        };
    }
};

pub var global_allocator = Allocator {
    .field = 1234,
};

pub const Allocator = struct {
    field: i32,
};

export fn foo() void {
    var x = List.init(&global_allocator);
    x.init();
}

// error
// backend=llvm
// target=native
//
// :23:6: error: type 'tmp.List' has no field or member function named 'init'
