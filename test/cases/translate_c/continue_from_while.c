void foo() {
    for (;;) {
        continue;
    }
}

// translate-c
// c_frontend=clang
//
// pub export fn foo() void {
//     while (true) {
//         continue;
//     }
// }
