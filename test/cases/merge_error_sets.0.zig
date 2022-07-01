pub fn main() void {
    const E = error{ A, B, D } || error{ A, B, C };
    E.A catch {};
    E.B catch {};
    E.C catch {};
    E.D catch {};
    const E2 = error{ X, Y } || @TypeOf(error.Z);
    E2.X catch {};
    E2.Y catch {};
    E2.Z catch {};
    assert(anyerror || error{Z} == anyerror);
}
fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
//
