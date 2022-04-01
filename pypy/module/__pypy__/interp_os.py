import os

from pypy.interpreter.gateway import unwrap_spec
from rpython.translator.platform import platform as compiler


@unwrap_spec(name='text0')
def real_getenv(space, name):
    """Get an OS environment value skipping Python cache"""
    return space.newtext_or_none(os.environ.get(name))

# For annotation, pre-build this as a global
_multiarch = compiler.get_multiarch()

def _get_multiarch(space):
    """Get the platform-specific multiarch label.

    On linux, this returns something like "x86_64-linux-gnu"
    On macOS this returns "darwin" for CPython compatibility
    On windows it returns ""
    """
    return space.newtext(_multiarch)


