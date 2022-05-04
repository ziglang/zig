export fn foo() void {
    var vga_mem: u16 = 0xB8000;
    _ = vga_mem;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:24: error: integer value 753664 cannot be coerced to type 'u16'
