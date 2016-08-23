const assert = @import("std").debug.assert;

pub fn List(inline T: type) -> type {
    SmallList(T, 8)
}

pub struct SmallList(inline T: type, inline STATIC_SIZE: usize) {
    items: []T,
    length: usize,
    prealloc_items: [STATIC_SIZE]T,
}

#attribute("test")
fn functionWithReturnTypeType() {
    var list: List(i32) = undefined;
    var list2: List(i32) = undefined;
    list.length = 10;
    list2.length = 10;
    assert(list.prealloc_items.len == 8);
    assert(list2.prealloc_items.len == 8);
}
