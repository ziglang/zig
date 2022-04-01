#include "Python.h"

PyObject *
PyType_FromSpec(PyType_Spec *spec)
{
    return PyType_FromSpecWithBases(spec, NULL);
}
/* 
 * Mangle to _PyPy_subtype_dealloc for translation.
 * For tests, we want to mangle as if it were a c-api function so
 * it will not be confused with the host's similarly named function
 */

#ifdef CPYEXT_TESTS
#define _Py_subtype_dealloc _cpyexttest_subtype_dealloc
#ifdef __GNUC__
__attribute__((visibility("default")))
#else
__declspec(dllexport)
#endif
#else  /* CPYEXT_TESTS */
#define _Py_subtype_dealloc _PyPy_subtype_dealloc
#endif  /* CPYEXT_TESTS */
void
_Py_subtype_dealloc(PyObject *obj)
{
    PyTypeObject *pto = obj->ob_type;
    PyTypeObject *base = pto;
    /* This wrapper is created on a specific type, call it w_A.
       We wish to call the dealloc function from one of the base classes of w_A,
       the first of which is not this function itself.
       w_obj is an instance of w_A or one of its subclasses. So climb up the
       inheritance chain until base.c_tp_dealloc is exactly this_func, and then
       continue on up until they differ.
       */
    while (base->tp_dealloc != &_Py_subtype_dealloc)
    {
        base = base->tp_base;
        assert(base);
    }
    while (base->tp_dealloc == &_Py_subtype_dealloc)
    {
        base = base->tp_base;
        assert(base);
    }
    /* XXX call tp_del if necessary */
    base->tp_dealloc(obj);
    /* XXX cpy decrefs the pto here but we do it in the base-dealloc
       hopefully this does not clash with the memory model assumed in
       extension modules */
}

long
PyType_GetFlags(PyTypeObject *type)
{
    return type->tp_flags;
}

