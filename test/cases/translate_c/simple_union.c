union Foo {
    int x;
};

// translate-c
// c_frontend=clang
//
// pub const union_Foo = extern union {
//     x: c_int,
// };
// 
// pub const Foo = union_Foo;
