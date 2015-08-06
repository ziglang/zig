/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_LIST_HPP
#define ZIG_LIST_HPP

#include "util.hpp"

#include <assert.h>

template<typename T>
struct ZigList {
    void deinit() {
        free(items);
    }
    void append(T item) {
        ensure_capacity(length + 1);
        items[length++] = item;
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
        ensure_capacity(new_length);
        length = new_length;
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
    }

    T * items;
    int length;
    int capacity;
};

#endif


