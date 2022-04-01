#include "crossing.h"
#include <stdlib.h>

extern "C" long bar_unwrap(PyObject*);
extern "C" PyObject* bar_wrap(long);


long crossing::A::unwrap(PyObject* pyobj)
{
    return bar_unwrap(pyobj);
}

PyObject* crossing::A::wrap(long l)
{
    return bar_wrap(l);
}
