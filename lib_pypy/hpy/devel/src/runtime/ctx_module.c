#include <Python.h>
#include "hpy.h"
#include "hpy/runtime/ctx_type.h"

#ifdef HPY_UNIVERSAL_ABI
   // for _h2py and _py2h
#  include "handles.h"
#endif

static PyModuleDef empty_moduledef = {
    PyModuleDef_HEAD_INIT
};

_HPy_HIDDEN HPy
ctx_Module_Create(HPyContext *ctx, HPyModuleDef *hpydef)
{
    // create a new PyModuleDef

    // we can't free this memory because it is stitched into moduleobject. We
    // just make it immortal for now, eventually we should think whether or
    // not to free it if/when we unload the module
    PyModuleDef *def = PyMem_Malloc(sizeof(PyModuleDef));
    if (def == NULL) {
        PyErr_NoMemory();
        return HPy_NULL;
    }
    memcpy(def, &empty_moduledef, sizeof(PyModuleDef));
    def->m_name = hpydef->m_name;
    def->m_doc = hpydef->m_doc;
    def->m_size = hpydef->m_size;
    def->m_methods = create_method_defs(hpydef->defines, hpydef->legacy_methods);
    if (def->m_methods == NULL) {
        PyMem_Free(def);
        return HPy_NULL;
    }
    PyObject *result = PyModule_Create(def);
    return _py2h(result);
}
