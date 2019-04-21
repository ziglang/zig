/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


#ifndef ZIG_PARSEC_HPP
#define ZIG_PARSEC_HPP

#include "all_types.hpp"

Error parse_h_file(CodeGen *codegen, AstNode **out_root_node, const char **args_begin, const char **args_end,
        Stage2TranslateMode mode, ZigList<ErrorMsg *> *errors);

#endif
