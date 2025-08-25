void (f0) (void *L);
void ((f1)) (void *L);
void (((f2))) (void *L);

// translate-c
// c_frontend=clang,aro
//
// pub extern fn f0(L: ?*anyopaque) void;
// pub extern fn f1(L: ?*anyopaque) void;
// pub extern fn f2(L: ?*anyopaque) void;
