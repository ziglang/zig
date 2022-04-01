.. code-block:: c

    #ifndef _PYPY_H_
    #define _PYPY_H_

    /* This header is meant to be included in programs that use PyPy as an
       embedded library.

       NOTE: this is deprecated.  Instead, use cffi's embedding support:
       http://cffi.readthedocs.org/en/latest/embedding.html
    */

    #ifdef __cplusplus
    extern "C" {
    #endif

    // call this first
    void rpython_startup_code(void);

    // pypy_init_threads has to be called in case you want to use threads
    void pypy_init_threads(void);

    /* Initialize the home directory of PyPy.  It is necessary to call this.

       Call it with "home" being the file name of the libpypy.so, for
       example; it will be used as a starting point when searching for the
       lib-python and lib_pypy directories.  They are searched from
       "home/..", "home/../..", etc.  Returns 0 if everything was fine.  If
       an error occurs, returns 1 and (if verbose != 0) prints some
       information to stderr.
     */
    int pypy_setup_home(char *home, int verbose);


    /* If your program has multiple threads, then you need to call
       pypy_thread_attach() once in each other thread that just started
       and in which you want to run Python code (including via callbacks,
       see below). DO NOT CALL IT IN THE MAIN THREAD
     */
    void pypy_thread_attach(void);


    /* The main entry point: executes "source" as plain Python code.
       Returns 0 if everything was fine.  If a Python exception is
       uncaught, it is printed to stderr and 1 is returned.

       Usually, the Python code from "source" should use cffi to fill in
       global variables of "function pointer" type in your program.  Use
       cffi callbacks to do so.  Once it is done, there is no need to call
       pypy_execute_source() any more: from C, you call directly the
       functions (which are "callbacks" from the point of view of Python).
     */
    int pypy_execute_source(char *source);

    /* a similar function, but inside Python code it'll register
       a magic argument c_argument as int, which will be passed as void* from C.
       Useful for passing pointers to arbitrary structs that contain callbacks
       to register */
    int pypy_execute_source_ptr(char *source, void* ptr);


    /* The 3.x versions of PyPy don't include the Windows pragma to
       automatically link python3?.lib.  This is apparently not commonly
       done on Windows anyway. */


    #ifdef __cplusplus
    }
    #endif

    #endif
