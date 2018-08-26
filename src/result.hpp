/*
 * Copyright (c) 2018 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ZIG_RESULT_HPP
#define ZIG_RESULT_HPP

#include "error.hpp"

#include <assert.h>

static inline void assertNoError(Error err) {
    assert(err == ErrorNone);
}

template<typename T>
struct Result {
    T data;
    Error err;

    Result(T x) : data(x), err(ErrorNone) {}

    Result(Error err) : err(err) {
        assert(err != ErrorNone);
    }

    T unwrap() {
        assert(err == ErrorNone);
        return data;
    }
};

#endif
