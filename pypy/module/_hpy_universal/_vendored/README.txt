This directory contains files which are copied verbatim and vendored from
https://github.com/pyhandle/hpy

One important difference is the presence of hpy/__init__.py, which is NOT
present in the original hpy repository.  The original hpy repo runs on py3.x,
qwheere hpy is a namespace package.  However, PyPy runs on py27, where
namespace packages do not exist, so hpy/__init__.py is required to import the
_vendored package (e.g., support.py imports hpy.devel)
