export fn foo() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];

    @memmove(dest, src);
}

export fn bar() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: *align(1) [8]u16 = @ptrCast(&buf);

    @memmove(dest, src);
}

export fn baz() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: [*]align(1) u16 = @ptrCast(&buf);

    @memmove(dest, src);
}

export fn qux() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];

    @memmove(dest, src);
}

export fn quux() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: *align(1) [8]u16 = @ptrCast(&buf);

    @memmove(dest, src);
}

export fn quuux() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: [*]align(1) u16 = @ptrCast(&buf);

    @memmove(dest, src);
}

export fn foo2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    const src: []u8 = &buf;

    @memmove(dest, src);
}

export fn bar2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *align(1) [8]u16 = @ptrCast(&buf);
    const src: []u8 = &buf;

    @memmove(dest, src);
}

export fn baz2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: [*]align(1) u16 = @ptrCast(&buf);
    const src: []u8 = &buf;

    @memmove(dest, src);
}

export fn qux2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    const src: *[8]u8 = &buf;

    @memmove(dest, src);
}

export fn quux2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *align(1) [8]u16 = @ptrCast(&buf);
    const src: *[8]u8 = &buf;

    @memmove(dest, src);
}

export fn quuux2() void {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: [*]align(1) u16 = @ptrCast(&buf);
    const src: *[8]u8 = &buf;

    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: *align(1) [8]u16 = @ptrCast(&buf);
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []u8 = &buf;
    const src: [*]align(1) u16 = @ptrCast(&buf);
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: *align(1) [8]u16 = @ptrCast(&buf);
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *[8]u8 = &buf;
    const src: [*]align(1) u16 = @ptrCast(&buf);
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    const src: []u8 = &buf;
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *align(1) [8]u16 = @ptrCast(&buf);
    const src: []u8 = &buf;
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: [*]align(1) u16 = @ptrCast(&buf);
    const src: []u8 = &buf;
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: []align(1) u16 = @as([*]align(1) u16, @ptrCast(&buf))[0..4];
    const src: *[8]u8 = &buf;
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: *align(1) [8]u16 = @ptrCast(&buf);
    const src: *[8]u8 = &buf;
    @memmove(dest, src);
}

comptime {
    var buf: [8]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const dest: [*]align(1) u16 = @ptrCast(&buf);
    const src: *[8]u8 = &buf;
    @memmove(dest, src);
}

// error
//
// :6:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :6:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :14:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :14:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :22:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :22:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :30:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :30:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :38:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :38:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :46:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :46:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :54:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :62:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :70:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :78:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :86:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :94:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :101:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :101:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :108:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :108:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :115:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :115:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :122:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :122:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :129:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :129:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :136:5: error: pointer element type 'u16' cannot coerce into element type 'u8'
// :136:5: note: unsigned 8-bit int cannot represent all possible unsigned 16-bit values
// :143:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :150:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :157:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :164:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :171:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
// :178:5: error: pointer element type 'u8' cannot coerce into element type 'u16'
