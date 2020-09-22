/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#ifndef ERROR_HPP
#define ERROR_HPP

#include "stage2.h"

const char *err_str(Error err);

#define assertNoError(err) assert((err) == ErrorNone);

#endif
