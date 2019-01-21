find_path(SoftFloat_INCLUDE_DIR NAMES softfloat.h)
find_library(SoftFloat_LIBRARY NAMES softfloat)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SoftFloat DEFAULT_MSG SoftFloat_LIBRARY SoftFloat_INCLUDE_DIR)

if(SoftFloat_FOUND)
	set(SoftFloat_LIBRARIES ${SoftFloat_LIBRARY})
	set(SoftFloat_INCLUDE_DIRS ${SoftFloat_INCLUDE_DIR})
endif(SoftFloat_FOUND)

mark_as_advanced(SoftFloat_INCLUDE_DIR SoftFloat_LIBRARY)
