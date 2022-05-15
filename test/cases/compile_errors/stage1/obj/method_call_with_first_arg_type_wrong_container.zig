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
// backend=stage1
// target=native
//
// tmp.zig:23:5: error: expected type '*Allocator', found '*List'
