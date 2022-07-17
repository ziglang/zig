# Copyright (c) 2017 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLD_FOUND
# LLD_INCLUDE_DIRS
# LLD_LIBRARIES

find_path(LLD_INCLUDE_DIRS NAMES lld/Common/Driver.h
    PATHS
        /usr/lib/llvm-14/include
        /usr/local/llvm140/include
        /usr/local/llvm14/include
        /usr/local/opt/llvm@14/include
        /opt/homebrew/opt/llvm@14/include
        /mingw64/include)

find_library(LLD_LIBRARY NAMES lld-14.0 lld140 lld NAMES_PER_DIR
    PATHS
        /usr/lib/llvm-14/lib
        /usr/local/llvm140/lib
        /usr/local/llvm14/lib
        /usr/local/opt/llvm@14/lib
        /opt/homebrew/opt/llvm@14/lib
)
if(EXISTS ${LLD_LIBRARY})
    set(LLD_LIBRARIES ${LLD_LIBRARY})
else()
    macro(FIND_AND_ADD_LLD_LIB _libname_)
        string(TOUPPER ${_libname_} _prettylibname_)
        find_library(LLD_${_prettylibname_}_LIB NAMES ${_libname_} NAMES_PER_DIR
            PATHS
                ${LLD_LIBDIRS}
                /usr/lib/llvm-14/lib
                /usr/local/llvm140/lib
                /usr/local/llvm14/lib
                /usr/local/opt/llvm@14/lib
                /opt/homebrew/opt/llvm@14/lib
                /mingw64/lib
                /c/msys64/mingw64/lib
                c:/msys64/mingw64/lib)
            if(LLD_${_prettylibname_}_LIB)
                set(LLD_LIBRARIES ${LLD_LIBRARIES} ${LLD_${_prettylibname_}_LIB})
        endif()
    endmacro(FIND_AND_ADD_LLD_LIB)

    FIND_AND_ADD_LLD_LIB(lldMinGW)
    FIND_AND_ADD_LLD_LIB(lldELF)
    FIND_AND_ADD_LLD_LIB(lldCOFF)
    FIND_AND_ADD_LLD_LIB(lldWasm)
    FIND_AND_ADD_LLD_LIB(lldMachO)
    FIND_AND_ADD_LLD_LIB(lldCommon)
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(lld DEFAULT_MSG LLD_LIBRARIES LLD_INCLUDE_DIRS)

mark_as_advanced(LLD_INCLUDE_DIRS LLD_LIBRARIES)
