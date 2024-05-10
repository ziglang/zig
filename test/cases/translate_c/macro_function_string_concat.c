#define bar() ""
#define FOO bar() "," bar()

// translate-c
// target=x86_64-linux
// c_frontend=clang
//
// pub inline fn bar() @TypeOf("") {
//     return "";
// }
// pub const FOO = bar() ++ "," ++ bar();
