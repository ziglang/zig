==================================
VMProf: a profiler for RPython VMs
==================================


from rpython.rlib import rvmprof


Your VM must have an interpreter for "code" objects, which can be
of any RPython instance.

Use this as a decorator on the mainloop of the interpreter, to tell vmprof
when you enter and leave a "code" object:

    def vmprof_execute_code(name, get_code_fn, result_class=None):

See its docstring in rvmprof.py.


The class of code objects needs to be registered by calling the
function ``rpython.rlib.rvmprof.register_code_object_class()``
(once, before translation).  It is a global function in __init__.py,
but see the docstring of the method in rvmprof.py.


To support adding new code objects at run-time, whenever a code object is
instantiated, call the function ``rpython.rlib.rvmprof.register_code()``.

If you need JIT support, you also need to add a jitdriver method
``get_unique_id(*greenkey)``, where you call
``rpython.rlib.rvmprof.get_unique_code()``.


Enable/disable the profiler at runtime with:

    def enable(fileno, interval):
    def disable():

The file descriptor must remain open until the profiler is disabled.
The profiler must be disabled before the program exit, otherwise the
file is incompletely written.

You should close the file descriptor after disabling the profiler; it is
not automatically closed.
