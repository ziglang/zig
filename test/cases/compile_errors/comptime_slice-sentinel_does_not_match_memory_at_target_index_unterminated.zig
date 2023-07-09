export fn foo_array() void {
    comptime {
        var target = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_ptr_array() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target = &buf;
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = &buf;
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_vector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*]u8 = @ptrCast(&buf);
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialBaseArray() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = &buf;
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_cvector_ConstPtrSpecialRef() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: [*c]u8 = @ptrCast(&buf);
        const slice = target[0..3 :0];
        _ = slice;
    }
}
export fn foo_slice() void {
    comptime {
        var buf = [_]u8{ 'a', 'b', 'c', 'd' } ++ [_]u8{undefined} ** 10;
        var target: []u8 = &buf;
        const slice = target[0..3 :0];
        _ = slice;
    }
}

// error
// backend=stage2
// target=native
//
// :4:29: error: value in memory does not match slice sentinel
// :4:29: note: expected '0', found '100'
// :12:29: error: value in memory does not match slice sentinel
// :12:29: note: expected '0', found '100'
// :20:29: error: value in memory does not match slice sentinel
// :20:29: note: expected '0', found '100'
// :28:29: error: value in memory does not match slice sentinel
// :28:29: note: expected '0', found '100'
// :36:29: error: value in memory does not match slice sentinel
// :36:29: note: expected '0', found '100'
// :44:29: error: value in memory does not match slice sentinel
// :44:29: note: expected '0', found '100'
// :52:29: error: value in memory does not match slice sentinel
// :52:29: note: expected '0', found '100'
