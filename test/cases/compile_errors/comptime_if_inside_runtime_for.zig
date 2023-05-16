export fn entry() void {
	var x: u32 = 0;
	for(0..1, 1..2) |_, _| {
		var y = x + if(x == 0) 1 else 0;
		_ = y;
	}
}

// error
// backend=stage2
// target=native
//
// :4:15: error: value with comptime-only type 'comptime_int' depends on runtime control flow
// :3:6: note: runtime control flow here
