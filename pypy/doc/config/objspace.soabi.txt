This option controls the tag included into extension module file names.  The
default is something like `pypy-14`, which means that `import foo` will look for
a file named `foo.pypy-14.so` (or `foo.pypy-14.pyd` on Windows).

This is an implementation of PEP3149_, with two differences:

 * the filename without tag `foo.so` is not considered.
 * the feature is also available on Windows.

When set to the empty string (with `--soabi=`), the interpreter will only look
for a file named `foo.so`, and will crash if this file was compiled for another
Python interpreter.

.. _PEP3149: http://www.python.org/dev/peps/pep-3149/
