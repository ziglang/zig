/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_MEM_LIST_HPP
#define ZIG_MEM_LIST_HPP

#include "mem.hpp"

namespace mem {

template<typename T>
struct List {
    void deinit(Allocator *allocator) {
        allocator->deallocate<T>(items, capacity);
        items = nullptr;
        length = 0;
        capacity = 0;
    }

    void append(Allocator *allocator, const T& item) {
        ensure_capacity(allocator, length + 1);
        items[length++] = item;
    }

    // remember that the pointer to this item is invalid after you
    // modify the length of the list
    const T & at(size_t index) const {
        assert(index != SIZE_MAX);
        assert(index < length);
        return items[index];
    }

    T & at(size_t index) {
        assert(index != SIZE_MAX);
        assert(index < length);
        return items[index];
    }

    T pop() {
        assert(length >= 1);
        return items[--length];
    }

    T *add_one() {
        resize(length + 1);
        return &last();
    }

    const T & last() const {
        assert(length >= 1);
        return items[length - 1];
    }

    T & last() {
        assert(length >= 1);
        return items[length - 1];
    }

    void resize(Allocator *allocator, size_t new_length) {
        assert(new_length != SIZE_MAX);
        ensure_capacity(allocator, new_length);
        length = new_length;
    }

    void clear() {
        length = 0;
    }

    void ensure_capacity(Allocator *allocator, size_t new_capacity) {
        if (capacity >= new_capacity)
            return;

        size_t better_capacity = capacity;
        do {
            better_capacity = better_capacity * 5 / 2 + 8;
        } while (better_capacity < new_capacity);

        items = allocator->reallocate_nonzero<T>(items, capacity, better_capacity);
        capacity = better_capacity;
    }

    T swap_remove(size_t index) {
        if (length - 1 == index) return pop();

        assert(index != SIZE_MAX);
        assert(index < length);

        T old_item = items[index];
        items[index] = pop();
        return old_item;
    }

    T *items{nullptr};
    size_t length{0};
    size_t capacity{0};
};

} // namespace mem

#endif
