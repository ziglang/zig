# Copyright (c) 2015 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# CLANG_FOUND
# CLANG_INCLUDE_DIR
# CLANG_LIBRARY

find_path(CLANG_INCLUDE_DIR NAMES clang-c/Index.h PATHS /usr/lib/llvm-3.7/include/)

find_library(CLANG_LIBRARY NAMES clang PATHS /usr/lib/llvm-3.7/lib/)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CLANG DEFAULT_MSG CLANG_LIBRARY CLANG_INCLUDE_DIR)

mark_as_advanced(CLANG_INCLUDE_DIR CLANG_LIBRARY)
