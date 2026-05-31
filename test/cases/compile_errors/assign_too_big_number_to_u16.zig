export fn foo() void {
    const vga_mem: u16 = 0xB8000;
    _ = vga_mem;
}

// error
//
// :2:26: error: type 'u16' cannot represent integer value '753664'
