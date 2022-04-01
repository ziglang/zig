
this directory contains PyPy's builtin module implementation
that require access to interpreter level.  See here
for more information: 

    http://doc.pypy.org/en/latest/coding-guide.html#modules-in-pypy

ATTENTION: don't put any '.py' files directly into pypy/module 
because you can easily get import mixups on e.g. "import sys" 
then (Python tries relative imports first). 
