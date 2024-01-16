void foo(void);
void bar(void) {
    void *func_ptr = foo;
    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
}

// translate-c
// c_frontends=clang
//
// pub extern fn foo() void;
// pub export fn bar() void {
//     var func_ptr: ?*anyopaque = @as(?*anyopaque, @ptrCast(&foo));
//     _ = &func_ptr;
//     var typed_func_ptr: ?*const fn () callconv(.C) void = @as(?*const fn () callconv(.C) void, @ptrFromInt(@as(usize, @as(c_ulong, @intFromPtr(func_ptr)))));
//     _ = &typed_func_ptr;
// }
