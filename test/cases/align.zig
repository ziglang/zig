const assert = @import("std").debug.assert;

var foo: u8 align 4 = 100;

test "global variable alignment" {
    assert(@typeOf(&foo) == &align 4 u8);
    const slice = (&foo)[0..1];
    assert(@typeOf(slice) == []align 4 u8);
}

fn derp() align (@sizeOf(usize) * 2) -> i32 { 1234 }

test "function alignment" {
    assert(derp() == 1234);
}


var baz: packed struct {
    a: u32,
    b: u32,
} = undefined;

test "packed struct alignment" {
    assert(@typeOf(&baz.b) == &align 1 u32);
}


const blah: packed struct {
    a: u3,
    b: u3,
    c: u2,
} = undefined;

test "bit field alignment" {
    assert(@typeOf(&blah.b) == &align 1:3:6 const u3);
}

test "default alignment allows unspecified in type syntax" {
    assert(&u32 == &align @alignOf(u32) u32);
}

test "implicitly decreasing pointer alignment" {
    const a: u32 align 4 = 3;
    const b: u32 align 8 = 4;
    assert(addUnaligned(&a, &b) == 7);
}

fn addUnaligned(a: &align 1 const u32, b: &align 1 const u32) -> u32 { *a + *b }

test "implicitly decreasing slice alignment" {
    const a: u32 align 4 = 3;
    const b: u32 align 8 = 4;
    assert(addUnalignedSlice((&a)[0..1], (&b)[0..1]) == 7);
}
fn addUnalignedSlice(a: []align 1 const u32, b: []align 1 const u32) -> u32 { a[0] + b[0] }
