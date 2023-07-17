threadlocal var some_tls_global: u32 = 1;

export fn foo() void {
    some_tls_global = 2;
}
