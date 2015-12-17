pub struct List#(T: type) {
    items: ?&T,
    length: usize,
    capacity: usize,

    pub fn (l: &List) deinit() {
        free(l.items);
        l.items = None;
    }

    pub fn append(l: &List, item: T) -> error {
        const err = l.ensure_capacity(l.length + 1);
        if err != Error.None {
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
            const new_items = realloc(l.items, better_capacity) ?? { return Error.NoMem };
            l.items = new_items;
            l.capacity = better_capacity;
        }
        Error.None
    }
}

pub fn malloc#(T: type)(count: usize) -> ?&T { realloc(None, count) }

pub fn realloc#(T: type)(ptr: ?&T, new_count: usize) -> ?&T {
    
}

pub fn free#(T: type)(ptr: ?&T) {

}
