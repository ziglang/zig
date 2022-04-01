#ifndef HPY_COMMON_RUNTIME_CTX_TYPE_H
#define HPY_COMMON_RUNTIME_CTX_TYPE_H

#include <Python.h>
#include "hpy.h"
#include "hpy/hpytype.h"

_HPy_HIDDEN PyMethodDef *create_method_defs(HPyDef *hpydefs[],
                                            PyMethodDef *legacy_methods);

/* The C structs of pure HPy (i.e. non-legacy) custom types do NOT include
 * PyObject_HEAD. So, the CPython implementation of HPy_New must allocate a
 * memory region which is big enough to contain PyObject_HEAD + any eventual
 * extra padding + the actual user struct. We use union alignment to ensure
 * that the payload is correctly aligned for every possible struct.
 *
 * Legacy custom types already include PyObject_HEAD and so do not need to
 * allocate extra memory region or use HPyPure_PyObject_HEAD_SIZE.
 */
typedef struct {
    PyObject_HEAD
    union {
        unsigned char payload[1];
        // these fields are never accessed: they are present just to ensure
        // the correct alignment of payload
        unsigned short _m_short;
        unsigned int _m_int;
        unsigned long _m_long;
        unsigned long long _m_longlong;
        float _m_float;
        double _m_double;
        long double _m_longdouble;
        void *_m_pointer;
    };
} _HPyPure_FullyAlignedSpaceForPyObject_HEAD;

#define HPyPure_PyObject_HEAD_SIZE (offsetof(_HPyPure_FullyAlignedSpaceForPyObject_HEAD, payload))

#endif /* HPY_COMMON_RUNTIME_CTX_TYPE_H */
