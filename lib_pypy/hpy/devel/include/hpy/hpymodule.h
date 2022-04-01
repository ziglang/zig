#ifndef HPY_UNIVERSAL_HPYMODULE_H
#define HPY_UNIVERSAL_HPYMODULE_H
// Copied from Python's exports.h
#ifndef Py_EXPORTED_SYMBOL
    #if defined(_WIN32) || defined(__CYGWIN__)
        #define Py_EXPORTED_SYMBOL __declspec(dllexport)
    #else
        #define Py_EXPORTED_SYMBOL __attribute__ ((visibility ("default")))
    #endif
#endif


// this is defined by HPy_MODINIT
extern HPyContext *_ctx_for_trampolines;

#define HPyModuleDef_HEAD_INIT NULL

typedef struct {
    void *dummy; // this is needed because we put a comma after HPyModuleDef_HEAD_INIT :(
    const char* m_name;
    const char* m_doc;
    HPy_ssize_t m_size;
    cpy_PyMethodDef *legacy_methods;
    HPyDef **defines;   /* points to an array of 'HPyDef *' */
} HPyModuleDef;



#ifdef HPY_UNIVERSAL_ABI

// module initialization in the universal case
#define HPy_MODINIT(modname)                                   \
    _HPy_HIDDEN HPyContext *_ctx_for_trampolines;              \
    static HPy init_##modname##_impl(HPyContext *ctx);         \
    Py_EXPORTED_SYMBOL                                         \
    HPy HPyInit_##modname(HPyContext *ctx)                     \
    {                                                          \
        _ctx_for_trampolines = ctx;                            \
        return init_##modname##_impl(ctx);                     \
    }

#else // HPY_UNIVERSAL_ABI

// module initialization in the CPython case
#define HPy_MODINIT(modname)                                   \
    static HPy init_##modname##_impl(HPyContext *ctx);         \
    PyMODINIT_FUNC                                             \
    PyInit_##modname(void)                                     \
    {                                                          \
        return _h2py(init_##modname##_impl(_HPyGetContext())); \
    }

#endif // HPY_UNIVERSAL_ABI

#endif // HPY_UNIVERSAL_HPYMODULE_H
