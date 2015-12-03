# Copyright (c) 2015 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# CLANG_FOUND
# CLANG_INCLUDE_DIR
# CLANG_LIBRARY

find_path(CLANG_INCLUDE_DIR NAMES clang-c/Index.h)

find_library(CLANG_LIBRARY NAMES clang)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(CLANG DEFAULT_MSG CLANG_LIBRARY CLANG_INCLUDE_DIR)

mark_as_advanced(CLANG_INCLUDE_DIR CLANG_LIBRARY)
