from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.astcompiler import ast, consts


class Module(MixedModule):

    interpleveldefs = {
        "PyCF_ONLY_AST" : "space.wrap(%s)" % consts.PyCF_ONLY_AST,
        "PyCF_TYPE_COMMENTS" : "space.wrap(%s)" % consts.PyCF_TYPE_COMMENTS,
        "PyCF_ALLOW_TOP_LEVEL_AWAIT" : "space.wrap(%s)" % consts.PyCF_ALLOW_TOP_LEVEL_AWAIT,
        "PyCF_ACCEPT_NULL_BYTES":
                          "space.wrap(%s)" % consts.PyCF_ACCEPT_NULL_BYTES,
        "__version__"   : "space.wrap('82160')",  # from CPython's svn.
        }
    appleveldefs = {}


def _setup():
    defs = Module.interpleveldefs
    defs['AST'] = "pypy.interpreter.astcompiler.ast.get(space).w_AST"
    for tup in ast.State.AST_TYPES:
        name = tup[0]
        defs[name] = "pypy.interpreter.astcompiler.ast.get(space).w_" + name
_setup()
