export fn foo() void {
    var vga_mem: u16 = 0xB8000;
    _ = vga_mem;
}

// error
// backend=stage2
// target=native
//
// :2:24: error: type 'u16' cannot represent integer value '753664'
