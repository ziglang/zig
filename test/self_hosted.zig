// TODO not passing
fn genericFnWithImplicitCast() {
    @setFnTest(this);

    assert(getFirstByte(u8, []u8 {13}) == 13);
    assert(getFirstByte(u16, []u16 {0, 13}) == 0);
}
fn getByte(ptr: ?&u8) -> u8 {*??ptr}
fn getFirstByte(inline T: type, mem: []T) -> u8 {
    getByte((&u8)(&mem[0]))
}
