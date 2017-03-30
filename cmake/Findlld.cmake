# Copyright (c) 2017 Andrew Kelley
# This file is MIT licensed.
# See http://opensource.org/licenses/MIT

# LLD_FOUND
# LLD_INCLUDE_DIRS
# LLD_LIBRARIES

find_path(LLD_INCLUDE_DIRS NAMES lld/Driver/Driver.h
    PATHS
        /usr/lib/llvm-4.0/include
        /mingw64/include)

    macro(FIND_AND_ADD_LLD_LIB _libname_)
    string(TOUPPER ${_libname_} _prettylibname_)
    find_library(LLD_${_prettylibname_}_LIB NAMES ${_libname_}
        PATHS
            /usr/lib/llvm-4.0/lib
            /mingw64/lib)
        if(LLD_${_prettylibname_}_LIB)
            set(LLD_LIBRARIES ${LLD_LIBRARIES} ${LLD_${_prettylibname_}_LIB})
    endif()
endmacro(FIND_AND_ADD_LLD_LIB)

FIND_AND_ADD_LLD_LIB(lldDriver)
FIND_AND_ADD_LLD_LIB(lldELF)
FIND_AND_ADD_LLD_LIB(lldCOFF)
FIND_AND_ADD_LLD_LIB(lldMachO)
FIND_AND_ADD_LLD_LIB(lldReaderWriter)
FIND_AND_ADD_LLD_LIB(lldCore)
FIND_AND_ADD_LLD_LIB(lldYAML)
FIND_AND_ADD_LLD_LIB(lldConfig)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(LLD DEFAULT_MSG LLD_LIBRARIES LLD_INCLUDE_DIRS)

mark_as_advanced(LLD_INCLUDE_DIRS LLD_LIBRARIES)

