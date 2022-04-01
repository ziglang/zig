#include <Python.h>

/* Reimplementation of PyFile_WriteString() no calling indirectly
   PyErr_CheckSignals(): avoid the call to PyObject_Str(). */

static int
sys_pyfile_write_unicode(PyObject *unicode, PyObject *file)
{
    PyObject *writer = NULL, *args = NULL, *result = NULL;
    int err;

    if (file == NULL)
        return -1;

    writer = PyObject_GetAttrString(file, "write");
    if (writer == NULL)
        goto error;

    args = PyTuple_Pack(1, unicode);
    if (args == NULL)
        goto error;

    result = PyEval_CallObject(writer, args);
    if (result == NULL) {
        goto error;
    } else {
        err = 0;
        goto finally;
    }

error:
    err = -1;
finally:
    Py_XDECREF(writer);
    Py_XDECREF(args);
    Py_XDECREF(result);
    return err;
}

static int
sys_pyfile_write(const char *text, PyObject *file)
{
    PyObject *unicode = NULL;
    int err;

    if (file == NULL)
        return -1;

    unicode = PyUnicode_FromString(text);
    if (unicode == NULL)
        return -1;

    err = sys_pyfile_write_unicode(unicode, file);
    Py_DECREF(unicode);
    return err;
}

/* APIs to write to sys.stdout or sys.stderr using a printf-like interface.
 */

static void
sys_write(char *name, FILE *fp, const char *format, va_list va)
{
    PyObject *file;
    PyObject *error_type, *error_value, *error_traceback;
    char buffer[1001];
    int written;

    PyErr_Fetch(&error_type, &error_value, &error_traceback);
    file = PySys_GetObject(name);
    written = PyOS_vsnprintf(buffer, sizeof(buffer), format, va);
    if (sys_pyfile_write(buffer, file) != 0) {
        PyErr_Clear();
        fputs(buffer, fp);
    }
    if (written < 0 || (size_t)written >= sizeof(buffer)) {
        const char *truncated = "... truncated";
        if (sys_pyfile_write(truncated, file) != 0)
            fputs(truncated, fp);
    }
    PyErr_Restore(error_type, error_value, error_traceback);
}

void
PySys_WriteStdout(const char *format, ...)
{
    va_list va;

    va_start(va, format);
    sys_write("stdout", stdout, format, va);
    va_end(va);
}

void
PySys_WriteStderr(const char *format, ...)
{
    va_list va;

    va_start(va, format);
    sys_write("stderr", stderr, format, va);
    va_end(va);
}
