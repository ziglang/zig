Embedding PyPy (DEPRECATED)
===========================

PyPy has a very minimal and a very strange embedding interface, based on
the usage of `cffi`_ and the philosophy that Python is a better language than
C. It was developed in collaboration with Roberto De Ioris from the `uwsgi`_
project. The `PyPy uwsgi plugin`_ is a good example of using the embedding API.

**NOTE**: You need a PyPy compiled with the option ``--shared``, i.e.
with a ``libpypy*-c.so`` or ``pypy*-c.dll`` file.  This is the default.

.. note::

   The interface described in this page is kept for backward compatibility.
   From PyPy 4.1, it is recommended to use instead CFFI's `native embedding
   support,`__ which gives a simpler approach that works on CPython as well
   as PyPy.

.. __: https://cffi.readthedocs.org/en/latest/embedding.html

The resulting shared library exports very few functions. These are defined in
``PyPy.h`` which was removed in v7.3.8, but `is still available`_.
They are enough to accomplish everything you need, provided you follow a few
principles. The API is:

.. function:: void rpython_startup_code(void);

   This is a function that you have to call (once) before calling anything else.
   It initializes the RPython/PyPy GC and does a bunch of necessary startup
   code. This function cannot fail.

.. function:: int pypy_setup_home(char* home, int verbose);

   This function searches the PyPy standard library starting from the given
   "PyPy home directory".  The arguments are:

   * ``home``: path to an executable inside the pypy directory
     (can be a .so name, can be made up).  Used to look up the standard
     library, and is also set as ``sys.executable``.  From PyPy 5.5, you can
     just say NULL here, as long as the ``libpypy-c.so/dylib/dll`` is itself
     inside this directory.

   * ``verbose``: if non-zero, it will print error messages to stderr

   Function returns 0 on success or -1 on failure, can be called multiple times
   until the library is found.

.. function:: void pypy_init_threads(void);

   Initialize threads. Only need to be called if there are any threads involved.
   *Must be called after pypy_setup_home()*

.. function:: int pypy_execute_source(char* source);

   Execute the Python source code given in the ``source`` argument. In case of
   exceptions, it will print the Python traceback to stderr and return 1,
   otherwise return 0.  You should really do your own error handling in the
   source. It'll acquire the GIL.

   Note: this is meant to be called *only once* or a few times at most.  See
   the `more complete example`_ below.  In PyPy <= 2.6.0, the globals
   dictionary is *reused* across multiple calls, giving potentially
   strange results (e.g. objects dying too early).  In PyPy >= 2.6.1,
   you get a new globals dictionary for every call (but then, all globals
   dictionaries are all kept alive forever, in ``sys._pypy_execute_source``).

.. function:: int pypy_execute_source_ptr(char* source, void* ptr);

   .. note:: added in PyPy 2.3.1, June 2014 
   
   Just like the above, except it registers a magic argument in the source
   scope as ``c_argument``, where ``void*`` is encoded as Python int.

.. function:: void pypy_thread_attach(void);

   In case your application uses threads that are initialized outside of PyPy,
   you need to call this function to tell the PyPy GC to track this thread.
   Note that this function is not thread-safe itself, so you need to guard it
   with a mutex.


Minimal example
---------------

Note that this API is a lot more minimal than say CPython C API, so at first
it's obvious to think that you can't do much. However, the trick is to do
all the logic in Python and expose it via `cffi`_ callbacks.
We write a little C program:

.. code-block:: c

    #include "PyPy.h"
    #include <stdio.h>
    #include <stdlib.h>

    static char source[] = "print 'hello from pypy'";

    int main(void)
    {
        int res;

        rpython_startup_code();
        /* Before PyPy 5.5, you may need to say e.g. "/opt/pypy/bin" instead
         * of NULL. */
        res = pypy_setup_home(NULL, 1);
        if (res) {
            printf("Error setting pypy home!\n");
            return 1;
        }

        res = pypy_execute_source((char*)source);
        if (res) {
            printf("Error calling pypy_execute_source!\n");
        }
        return res;
    }

If we save it as ``x.c`` now, compile it and run it (on linux) with::

    $ gcc -g -o x x.c -lpypy-c -L/opt/pypy/bin -I/opt/pypy/include
    $ LD_LIBRARY_PATH=/opt/pypy/bin ./x
    hello from pypy

On OSX it is necessary to set the rpath of the binary if one wants to link to it,
with a command like::

    gcc -o x x.c -lpypy-c -L. -Wl,-rpath -Wl,@executable_path
    ./x
    hello from pypy


More complete example
---------------------

.. note:: Note that we do not make use of ``extern "Python"``, the new
   way to do callbacks in CFFI 1.4: this is because these examples use
   the ABI mode, not the API mode, and with the ABI mode you still have
   to use ``ffi.callback()``.  It is work in progress to integrate
   ``extern "Python"`` with the idea of embedding (and it is expected
   to ultimately lead to a better way to do embedding than the one
   described here, and that would work equally well on CPython and PyPy).

Typically we need something more to do than simply execute source. The following
is a fully fledged example, please consult cffi documentation for details.
It's a bit longish, but it captures a gist what can be done with the PyPy
embedding interface:

.. code-block:: python

    # file "interface.py"
    
    import cffi

    ffi = cffi.FFI()
    ffi.cdef('''
    struct API {
        double (*add_numbers)(double x, double y);
    };
    ''')

    # Better define callbacks at module scope, it's important to
    # keep this object alive.
    @ffi.callback("double (double, double)")
    def add_numbers(x, y):
        return x + y

    def fill_api(ptr):
        global api
        api = ffi.cast("struct API*", ptr)
        api.add_numbers = add_numbers

.. code-block:: c

    /* C example */
    #include "PyPy.h"
    #include <stdio.h>
    #include <stdlib.h>

    struct API {
        double (*add_numbers)(double x, double y);
    };

    struct API api;   /* global var */

    int initialize_api(void)
    {
        static char source[] =
            "import sys; sys.path.insert(0, '.'); "
            "import interface; interface.fill_api(c_argument)";
        int res;

        rpython_startup_code();
        res = pypy_setup_home(NULL, 1);
        if (res) {
            fprintf(stderr, "Error setting pypy home!\n");
            return -1;
        }
        res = pypy_execute_source_ptr(source, &api);
        if (res) {
            fprintf(stderr, "Error calling pypy_execute_source_ptr!\n");
            return -1;
        }
        return 0;
    }

    int main(void)
    {
        if (initialize_api() < 0)
            return 1;

        printf("sum: %f\n", api.add_numbers(12.3, 45.6));

        return 0;
    }

you can compile and run it with::

    $ gcc -g -o x x.c -lpypy-c -L/opt/pypy/bin -I/opt/pypy/include
    $ LD_LIBRARY_PATH=/opt/pypy/bin ./x
    sum: 57.900000

As you can see, what we did is create a ``struct API`` that contains
the custom API that we need in our particular case.  This struct is
filled by Python to contain a function pointer that is then called
form the C side.  It is also possible to do have other function
pointers that are filled by the C side and called by the Python side,
or even non-function-pointer fields: basically, the two sides
communicate via this single C structure that defines your API.


Finding pypy_home
-----------------

**You can usually skip this section if you are running PyPy >= 5.5, released
Oct 2016** 

The function pypy_setup_home() takes as first parameter the path to a
file from which it can deduce the location of the standard library.
More precisely, it tries to remove final components until it finds
``lib-python`` and ``lib_pypy``.  There is currently no "clean" way
(pkg-config comes to mind) to find this path.  You can try the following
(GNU-specific) hack (don't forget to link against *dl*), which assumes
that the ``libpypy-c.so`` is inside the standard library directory.
(This must more-or-less be the case anyway, otherwise the ``pypy``
program itself would not run.)

.. code-block:: c

    #if !(_GNU_SOURCE)
    #define _GNU_SOURCE
    #endif

    #include <dlfcn.h>
    #include <limits.h>
    #include <stdlib.h>

    // caller should free returned pointer to avoid memleaks
    // returns NULL on error
    char* guess_pypyhome(void) {
        // glibc-only (dladdr is why we #define _GNU_SOURCE)
        Dl_info info;
        void *_rpython_startup_code = dlsym(0,"rpython_startup_code");
        if (_rpython_startup_code == 0) {
            return 0;
        }
        if (dladdr(_rpython_startup_code, &info) != 0) {
            const char* lib_path = info.dli_fname;
            char* lib_realpath = realpath(lib_path, 0);
            return lib_realpath;
        }
        return 0;
    }


Threading
---------

In case you want to use pthreads, what you need to do is to call
``pypy_thread_attach`` from each of the threads that you created (but not
from the main thread) and call ``pypy_init_threads`` from the main thread.

.. _`cffi`: https://cffi.readthedocs.org/
.. _`uwsgi`: https://uwsgi-docs.readthedocs.org/en/latest/
.. _`PyPy uwsgi plugin`: https://uwsgi-docs.readthedocs.org/en/latest/PyPy.html
.. _`how to compile PyPy`: getting-started.html
.. _`is still available`: pypy.h.html
