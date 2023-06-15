export fn a() void {
    asm volatile (""
        :
        : [_] "{al}" (u8),
    );
}
export fn b() void {
    asm volatile (""
        :
        : [_] "{a}" (0),
          [_] "{x}" (&&void),
    );
}
export fn c() void {
    const A = struct {};
    asm volatile (""
        :
        : [_] "{x}" (1),
          [_] "{x}" (A{}),
    );
}
export fn d() void {
    const A = struct { x: u8 };
    asm volatile (""
        :
        : [_] "{x}" (((packed struct { x: u8 }){ .x = 1 })),
          [_] "{x}" (extern struct { x: u8 }{ .x = 1 }),
          [_] "{x}" (A{ .x = 1 }),
    );
}
export fn e() void {
    asm volatile (""
        :
        : [_] "{x}" (@Vector(3, u8){ 1, 2, 3 }),
          [_] "{x}" ([2]*const type{ &u8, &u8 }),
    );
}
export fn f() void {
    asm volatile (""
        :
        : [_] "{x}" (undefined),
    );
}
export fn g() void {
    asm volatile (""
        :
        : [_] "{x}" ({}),
    );
}
export fn h() void {
    asm volatile (""
        :
        : [_] "{x}" (@as([]const u8, "hello")),
    );
}

// error
// backend=stage2
// target=native
//
// :4:23: error: type 'type' is comptime-only and cannot be used for an assembly input operand
// :11:22: error: type '*const *const type' is comptime-only and cannot be used for an assembly input operand
// :19:23: error: type 'tmp.c.A' does not have runtime bits and cannot be used for an assembly input operand
// :15:15: note: struct declared here
// :28:23: error: type 'tmp.d.A' does not have a well-defined memory layout and cannot be used for an assembly input operand
// :23:15: note: struct declared here
// :35:36: error: type '[2]*const type' is comptime-only and cannot be used for an assembly input operand
// :41:22: error: type '@TypeOf(undefined)' is comptime-only and cannot be used for an assembly input operand
// :47:22: error: type 'void' does not have runtime bits and cannot be used for an assembly input operand
// :53:22: error: type '[]const u8' does not have a well-defined memory layout and cannot be used for an assembly input operand
