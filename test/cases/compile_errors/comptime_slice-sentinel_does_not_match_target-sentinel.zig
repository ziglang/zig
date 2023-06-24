export fn foo_array() void {
    comptime {
        var target = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_ptr_array() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast(&buf);
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast(&buf);
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn foo_slice() void {
    comptime {
        var buf = [_:0]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..14 :255];
        _ = slice;
    }
}
export fn undefined_slice() void {
    const arr: [100]u16 = undefined;
    const slice = arr[0..12 :0];
    _ = slice;
}
export fn string_slice() void {
    const str = "abcdefg";
    const slice = str[0..1 :12];
    _ = slice;
}
export fn typeName_slice() void {
    const arr = @typeName(usize);
    const slice = arr[0..2 :0];
    _ = slice;
}

// error
// backend=stage2
// target=native
//
// :4:29: error: value in memory does not match slice sentinel
// :4:29: note: expected '255', found '0'
// :12:29: error: value in memory does not match slice sentinel
// :12:29: note: expected '255', found '0'
// :20:29: error: value in memory does not match slice sentinel
// :20:29: note: expected '255', found '0'
// :28:29: error: value in memory does not match slice sentinel
// :28:29: note: expected '255', found '0'
// :36:29: error: value in memory does not match slice sentinel
// :36:29: note: expected '255', found '0'
// :44:29: error: value in memory does not match slice sentinel
// :44:29: note: expected '255', found '0'
// :52:29: error: value in memory does not match slice sentinel
// :52:29: note: expected '255', found '0'
// :58:22: error: value in memory does not match slice sentinel
// :58:22: note: expected '0', found 'undefined'
// :63:22: error: value in memory does not match slice sentinel
// :63:22: note: expected '12', found '98'
// :68:22: error: value in memory does not match slice sentinel
// :68:22: note: expected '0', found '105'
