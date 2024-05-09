
void assert(int x) {}
#define FOO assert(0 && "error message")

// translate-c
// c_frontend=clang
//
// pub const FOO = assert((@as(c_int, 0) != 0) and (@intFromPtr("error message") != 0));
