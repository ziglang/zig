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
// :6:5: error: @memmove destination and source have incompatible child types
// :6:14: note: destination has child type 'u8'
// :6:20: note: source has child type 'u16'
// :14:5: error: @memmove destination and source have incompatible child types
// :14:14: note: destination has child type 'u8'
// :14:20: note: source has child type 'u16'
// :22:5: error: @memmove destination and source have incompatible child types
// :22:14: note: destination has child type 'u8'
// :22:20: note: source has child type 'u16'
// :30:5: error: @memmove destination and source have incompatible child types
// :30:14: note: destination has child type 'u8'
// :30:20: note: source has child type 'u16'
// :38:5: error: @memmove destination and source have incompatible child types
// :38:14: note: destination has child type 'u8'
// :38:20: note: source has child type 'u16'
// :46:5: error: @memmove destination and source have incompatible child types
// :46:14: note: destination has child type 'u8'
// :46:20: note: source has child type 'u16'
// :54:5: error: @memmove destination and source have incompatible child types
// :54:14: note: destination has child type 'u16'
// :54:20: note: source has child type 'u8'
// :62:5: error: @memmove destination and source have incompatible child types
// :62:14: note: destination has child type 'u16'
// :62:20: note: source has child type 'u8'
// :70:5: error: @memmove destination and source have incompatible child types
// :70:14: note: destination has child type 'u16'
// :70:20: note: source has child type 'u8'
// :78:5: error: @memmove destination and source have incompatible child types
// :78:14: note: destination has child type 'u16'
// :78:20: note: source has child type 'u8'
// :86:5: error: @memmove destination and source have incompatible child types
// :86:14: note: destination has child type 'u16'
// :86:20: note: source has child type 'u8'
// :94:5: error: @memmove destination and source have incompatible child types
// :94:14: note: destination has child type 'u16'
// :94:20: note: source has child type 'u8'
// :101:5: error: @memmove destination and source have incompatible child types
// :101:14: note: destination has child type 'u8'
// :101:20: note: source has child type 'u16'
// :108:5: error: @memmove destination and source have incompatible child types
// :108:14: note: destination has child type 'u8'
// :108:20: note: source has child type 'u16'
// :115:5: error: @memmove destination and source have incompatible child types
// :115:14: note: destination has child type 'u8'
// :115:20: note: source has child type 'u16'
// :122:5: error: @memmove destination and source have incompatible child types
// :122:14: note: destination has child type 'u8'
// :122:20: note: source has child type 'u16'
// :129:5: error: @memmove destination and source have incompatible child types
// :129:14: note: destination has child type 'u8'
// :129:20: note: source has child type 'u16'
// :136:5: error: @memmove destination and source have incompatible child types
// :136:14: note: destination has child type 'u8'
// :136:20: note: source has child type 'u16'
// :143:5: error: @memmove destination and source have incompatible child types
// :143:14: note: destination has child type 'u16'
// :143:20: note: source has child type 'u8'
// :150:5: error: @memmove destination and source have incompatible child types
// :150:14: note: destination has child type 'u16'
// :150:20: note: source has child type 'u8'
// :157:5: error: @memmove destination and source have incompatible child types
// :157:14: note: destination has child type 'u16'
// :157:20: note: source has child type 'u8'
// :164:5: error: @memmove destination and source have incompatible child types
// :164:14: note: destination has child type 'u16'
// :164:20: note: source has child type 'u8'
// :171:5: error: @memmove destination and source have incompatible child types
// :171:14: note: destination has child type 'u16'
// :171:20: note: source has child type 'u8'
// :178:5: error: @memmove destination and source have incompatible child types
// :178:14: note: destination has child type 'u16'
// :178:20: note: source has child type 'u8'
