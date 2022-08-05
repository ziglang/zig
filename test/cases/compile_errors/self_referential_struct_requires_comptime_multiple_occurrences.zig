const S = struct {
	a: S2,
	b: S3,
	c: S4,
};

const S2 = struct {
    a: fn () void,
};

const S3 = struct {
	a: S2,
};

const S4 = struct {
	a: S2,
};

pub export fn entry() void {
    var s: S = undefined;
    _ = s;
}


// error
// backend=stage2
// target=native
//
// :20:12: error: variable of type 'tmp.S' must be const or comptime
// :2:5: note: struct requires comptime because of this field
// :3:5: note: struct requires comptime because of this field
// :12:5: note: struct requires comptime because of this field
// :4:5: note: struct requires comptime because of this field
// :16:5: note: struct requires comptime because of this field
