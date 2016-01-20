pub struct List#(T: type) {
    items: ?&T,
    length: isize,
    capacity: isize,

    pub fn deinit(l: &List) {
        free(l.items);
        l.items = null;
    }

    pub fn append(l: &List, item: T) -> error {
        const err = l.ensure_capacity(l.length + 1);
        if err != error.None {
            return err;
        }
        const raw_items = l.items ?? unreachable;
        l.raw_items[l.length] = item;
        l.length += 1;
        return 0;
    }

    pub fn at(l: List, index: usize) -> T {
        assert(index < l.length);
        const raw_items = l.items ?? unreachable;
        return raw_items[index];
    }

    pub fn ptr_at(l: &List, index: usize) -> &T {
        assert(index < l.length);
        const raw_items = l.items ?? unreachable;
        return &raw_items[index];
    }

    pub fn clear(l: &List) {
        l.length = 0;
    }

    pub fn pop(l: &List) -> T {
        assert(l.length >= 1);
        l.length -= 1;
        return l.items[l.length];
    }

    fn ensure_capacity(l: &List, new_capacity: usize) -> error {
        var better_capacity = max(l.capacity, 16);
        while better_capacity < new_capacity {
            better_capacity *= 2;
        }
        if better_capacity != l.capacity {
            const new_items = realloc(l.items, better_capacity) ?? { return error.NoMem };
            l.items = new_items;
            l.capacity = better_capacity;
        }
        error.None
    }
}

pub fn malloc#(T: type)(count: usize) -> ?&T { realloc(None, count) }

pub fn realloc#(T: type)(ptr: ?&T, new_count: usize) -> ?&T {
    
}

pub fn free#(T: type)(ptr: ?&T) {

}


////////////////// alternate

// previously proposed but without ->
fn max#(T: type)(a: T, b: T) T {
    if (a > b) a else b
}

// andy's new idea
// parameters can reference other inline parameters.
fn max(inline T: type, a: T, b: T) T {
    if (a > b) a else b
}

fn f() {
    const x: i32 = 1234;
    const y: i32 = 5678;
    const z = max(@typeof(x), x, y);
}

// So, type-generic functions don't need any fancy syntax. type-generic
// containers still do, though:

pub struct List(T: type) {
    items: ?&T,
    length: isize,
    capacity: isize,
}

// we don't need '#' to indicate type generic parameters.

fn f() {
    var list: List(u8);
}

