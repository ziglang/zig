/* Complex object interface */

#ifndef Py_COMPLEXOBJECT_H
#define Py_COMPLEXOBJECT_H
#ifdef __cplusplus
extern "C" {
#endif

typedef struct Py_complex_t {
    double real;
    double imag;
} Py_complex;

typedef struct {
    PyObject_HEAD
    Py_complex cval;
} PyComplexObject;

PyAPI_FUNC(Py_complex) PyComplex_AsCComplex(PyObject *obj);
PyAPI_FUNC(PyObject *) PyComplex_FromCComplex(Py_complex c);

#ifdef __cplusplus
}
#endif
#endif /* !Py_COMPLEXOBJECT_H */
