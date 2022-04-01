from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """The builtin parser module."""

    applevel_name = 'parser'

    appleveldefs = {
    }

    interpleveldefs = {
        '__name__'     : '(space.newtext("parser"))',
        '__doc__'      : '(space.newtext("parser module"))',
        'suite'        : 'pyparser.suite',
        'expr'         : 'pyparser.expr',
        'issuite'      : 'pyparser.issuite',
        'isexpr'       : 'pyparser.isexpr',
        'STType'       : 'pyparser.W_STType',
        'ast2tuple'    : 'pyparser.st2tuple',
        'st2tuple'     : 'pyparser.st2tuple',
        'ast2list'     : 'pyparser.st2list',
        'ast2tuple'    : 'pyparser.st2tuple',
        'ASTType'      : 'pyparser.W_STType',
        'compilest'    : 'pyparser.compilest',
        'compileast'   : 'pyparser.compilest',
        'tuple2st'     : 'pyparser.tuple2st',
        'sequence2st'  : 'pyparser.tuple2st',
        'ParserError'  : 'pyparser.get_error(space)',
    }
