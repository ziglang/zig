struct Foo;
struct Foo *some_func(struct Foo *foo, int x);

// translate-c
// c_frontend=clang,aro
//
// pub const struct_Foo = opaque {};
// pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
//
// pub const Foo = struct_Foo;
