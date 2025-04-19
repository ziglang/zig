typedef struct {
    int foo;
} Foo;

int Foo_bar(Foo foo);
int baz(Foo *foo);
int libsomething_quux(Foo *foo);
int foo1_bar(Foo *foo);
int foo2_bar(Foo *foo);

typedef union {
    int foo;
    float numb;
} UFoo;

int UFoo_bar(UFoo ufoo);
int ubaz(UFoo *ufoo);
int libsomething_union_quux(UFoo *ufoo);

// translate-c
// c_frontend=clang
//
// pub const Foo = extern struct {
//     foo: c_int = @import("std").mem.zeroes(c_int),
//     pub const bar = Foo_bar;
//     pub const quux = libsomething_quux;
//     pub const bar1 = foo1_bar;
//     pub const bar2 = foo2_bar;
// };
// pub extern fn Foo_bar(foo: Foo) c_int;
// pub extern fn baz(foo: [*c]Foo) c_int;
// pub extern fn libsomething_quux(foo: [*c]Foo) c_int;
// pub extern fn foo1_bar(foo: [*c]Foo) c_int;
// pub extern fn foo2_bar(foo: [*c]Foo) c_int;
// pub const UFoo = extern union {
//     foo: c_int,
//     numb: f32,
//     pub const bar = UFoo_bar;
//     pub const quux = libsomething_union_quux;
// };
// pub extern fn UFoo_bar(ufoo: UFoo) c_int;
// pub extern fn ubaz(ufoo: [*c]UFoo) c_int;
// pub extern fn libsomething_union_quux(ufoo: [*c]UFoo) c_int;
