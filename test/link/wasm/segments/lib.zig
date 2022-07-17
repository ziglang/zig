pub const rodata: u32 = 5;
pub var data: u32 = 10;
pub var bss: u32 = undefined;

export fn foo() void {
    _ = rodata;
    _ = data;
    _ = bss;
}
