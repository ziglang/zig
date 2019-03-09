/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_PARSEC_HPP
#define ZIG_PARSEC_HPP

#include "all_types.hpp"

Error parse_h_file(AstNode **out_root_node, ZigList<ErrorMsg *> *errors, const char *target_file,
        CodeGen *codegen, Buf *tmp_dep_file);

#endif
