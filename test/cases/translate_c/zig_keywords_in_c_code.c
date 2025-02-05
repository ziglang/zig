struct comptime {
    int defer;
};

// translate-c
// c_frontend=aro,clang
//
// pub const struct_comptime = extern struct {
//     @"defer": c_int = @import("std").mem.zeroes(c_int),
// };
// 
// pub const @"comptime" = struct_comptime;
