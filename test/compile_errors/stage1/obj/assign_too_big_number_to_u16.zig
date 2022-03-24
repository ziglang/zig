export fn foo() void {
    var vga_mem: u16 = 0xB8000;
    _ = vga_mem;
}

// assign too big number to u16
//
// tmp.zig:2:24: error: integer value 753664 cannot be coerced to type 'u16'
