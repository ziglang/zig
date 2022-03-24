const ContextAllocator = MemoryPool(usize);

pub fn MemoryPool(comptime T: type) type {
    const free_list_t = @compileError("aoeu",);

    return struct {
        free_list: free_list_t,
    };
}

export fn entry() void {
    var allocator: ContextAllocator = undefined;
}

// constant inside comptime function has compile error
//
// tmp.zig:4:5: error: unreachable code
// tmp.zig:4:25: note: control flow is diverted here
// tmp.zig:12:9: error: unused local variable
