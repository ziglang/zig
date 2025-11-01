# Copyright (c) 2017 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLD_FOUND
# LLD_INCLUDE_DIRS
# LLD_LIBRARIES

find_path(LLD_INCLUDE_DIRS NAMES lld/Common/Driver.h
    HINTS ${LLVM_INCLUDE_DIRS}
    PATHS
        /usr/lib/llvm-21/include
        /usr/local/llvm210/include
        /usr/local/llvm21/include
        /usr/local/opt/lld@21/include
        /opt/homebrew/opt/lld@21/include
        /home/linuxbrew/.linuxbrew/opt/lld@21/include
        /mingw64/include)

find_library(LLD_LIBRARY NAMES lld-21.0 lld210 lld NAMES_PER_DIR
    HINTS ${LLVM_LIBDIRS}
    PATHS
        /usr/lib/llvm-21/lib
        /usr/local/llvm210/lib
        /usr/local/llvm21/lib
        /usr/local/opt/lld@21/lib
        /opt/homebrew/opt/lld@21/lib
        /home/linuxbrew/.linuxbrew/opt/lld@21/lib
)
if(EXISTS ${LLD_LIBRARY})
    set(LLD_LIBRARIES ${LLD_LIBRARY})
else()
    macro(FIND_AND_ADD_LLD_LIB _libname_)
        string(TOUPPER ${_libname_} _prettylibname_)
        find_library(LLD_${_prettylibname_}_LIB NAMES ${_libname_} NAMES_PER_DIR
            HINTS ${LLVM_LIBDIRS}
            PATHS
                ${LLD_LIBDIRS}
                /usr/lib/llvm-21/lib
                /usr/local/llvm210/lib
                /usr/local/llvm21/lib
                /usr/local/opt/lld@21/lib
                /opt/homebrew/opt/lld@21/lib
                /home/linuxbrew/.linuxbrew/opt/lld@21/lib
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
