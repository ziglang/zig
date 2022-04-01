struct _object;
typedef _object PyObject;

namespace crossing {

class A {
public:
    long unwrap(PyObject* pyobj);
    PyObject* wrap(long l);
};

} // namespace crossing
