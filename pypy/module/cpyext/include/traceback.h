#ifndef Py_TRACEBACK_H
#define Py_TRACEBACK_H
#ifdef __cplusplus
extern "C" {
#endif

struct _frame;

typedef struct _traceback {
        PyObject_HEAD
        struct _traceback *tb_next;
        struct _frame *tb_frame;
        int tb_lasti;
        int tb_lineno;
} PyTracebackObject;

#ifdef __cplusplus
}
#endif
#endif /* !Py_TRACEBACK_H */
