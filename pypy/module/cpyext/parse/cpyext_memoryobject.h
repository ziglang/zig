/* The struct is declared here but it shouldn't
   be considered public. Don't access those fields directly,
   use the functions instead! */


/* this is wrong, PyMemoryViewObject should use PyObject_VAR_HEAD, and use
   ob_data[1] to hold the shapes, strides, and offsets for the view. Then
   we should use specialized allocators (that break the cpyext model) to
   allocate ob_data = malloc(sizeof(Py_ssize_t) * view.ndims * 3) */
typedef struct {
    PyObject_HEAD
    Py_buffer view;
} PyMemoryViewObject;
