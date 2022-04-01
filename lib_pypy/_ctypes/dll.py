import _rawffi

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f

@builtinify
def dlopen(name, mode):
    # XXX mode is ignored
    return _rawffi.CDLL(name)
