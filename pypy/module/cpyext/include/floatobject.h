
/* Float object interface */

#ifndef Py_FLOATOBJECT_H
#define Py_FLOATOBJECT_H

#ifdef _MSC_VER
#include <math.h>
#include <float.h>
#define copysign _copysign
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    PyObject_HEAD
    double ob_fval;
} PyFloatObject;

#define PyFloat_STR_PRECISION 12

#ifdef Py_NAN
#define Py_RETURN_NAN return PyFloat_FromDouble(Py_NAN)
#endif

#define Py_RETURN_INF(sign) do                                  \
        if (copysign(1., sign) == 1.) {                         \
                return PyFloat_FromDouble(Py_HUGE_VAL); \
        } else {                                                \
                return PyFloat_FromDouble(-Py_HUGE_VAL);        \
        } while(0)

#define PyFloat_Check(op) \
		 _PyPy_Type_FastSubclass(Py_TYPE(op), Py_TPPYPYFLAGS_FLOAT_SUBCLASS)
#define PyFloat_CheckExact(op) (Py_TYPE(op) == &PyFloat_Type)


#ifdef __cplusplus
}
#endif
#endif /* !Py_FLOATOBJECT_H */
