/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef GROOVE_LIST_HPP
#define GROOVE_LIST_HPP

#include "util.hpp"

#include <assert.h>

template<typename T>
struct GrooveList {
    void deinit() {
        deallocate(items);
    }
    void append(T item) {
        int err = ensure_capacity(length + 1);
        if (err)
            return err;
        items[length++] = item;
        return 0;
    }
    // remember that the pointer to this item is invalid after you
    // modify the length of the list
    const T & at(int index) const {
        assert(index >= 0);
        assert(index < length);
        return items[index];
    }
    T & at(int index) {
        assert(index >= 0);
        assert(index < length);
        return items[index];
    }
    T pop() {
        assert(length >= 1);
        return items[--length];
    }

    void add_one() {
        return resize(length + 1);
    }

    const T & last() const {
        assert(length >= 1);
        return items[length - 1];
    }

    T & last() {
        assert(length >= 1);
        return items[length - 1];
    }

    void resize(int new_length) {
        assert(new_length >= 0);
        int err = ensure_capacity(new_length);
        if (err)
            return err;
        length = new_length;
        return 0;
    }

    void clear() {
        length = 0;
    }

    void ensure_capacity(int new_capacity) {
        int better_capacity = max(capacity, 16);
        while (better_capacity < new_capacity)
            better_capacity = better_capacity * 2;
        if (better_capacity != capacity) {
            items = reallocate_nonzero(items, better_capacity);
            capacity = better_capacity;
        }
        return 0;
    }

    T * items;
    int length;
    int capacity;
};

#endif


