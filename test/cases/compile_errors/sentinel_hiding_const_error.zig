// from #7816 - in stage1 the wrong error would be displayed

export fn b() void {
    const ptr: [*:0]u8 = "foo";
    _ = &ptr;
}

// error
// target=native
// backend=stage2
//
// :4:26: error: expected type '[*:0]u8', found '*const [3:0]u8'
// :4:26: note: cast discards const qualifier
