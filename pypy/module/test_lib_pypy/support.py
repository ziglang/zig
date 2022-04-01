import py

from pypy.conftest import option
from pypy.interpreter.error import OperationError

def import_lib_pypy(space, name, skipmsg=None):
    """Import a top level module ensuring it's sourced from the lib_pypy
    package.

    Raises a pytest Skip on ImportError if a skip message was specified.
    """
    try:
        # app-level import should find it from the right place (we
        # assert so afterwards) as long as a builtin module doesn't
        # overshadow it
        failed = ("%s didn't import from lib_pypy. Is a usemodules directive "
                  "overshadowing it?" % name)
        importline = ("import %s; assert 'lib_pypy' in %s.__file__, %r; "
                      "return %s" % (name, name, failed, name))
        if option.runappdirect:
            importline = "from lib_pypy " + importline
        return space.appexec([], "(): " + importline)
    except OperationError as e:
        if skipmsg is None or not e.match(space, space.w_ImportError):
            raise
        py.test.skip('%s (%s))' % (skipmsg, str(e)))
