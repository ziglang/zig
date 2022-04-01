from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    """Operator Builtin Module. """
    applevel_name = '_operator'

    appleveldefs = {}
    app_names = ['countOf', 'attrgetter', 'itemgetter', 'methodcaller']
    for name in app_names:
        appleveldefs[name] = 'app_operator.%s' % name

    interp_names = ['index', 'abs', 'add', 'and_',
                    'concat', 'contains', 'delitem', 'eq', 'floordiv',
                    'ge', 'getitem', 'gt', 'inv',
                    'invert', 'is_', 'is_not',
                    'le', 'lshift', 'lt', 'mod', 'mul',
                    'ne', 'neg', 'not_', 'or_',
                    'pos', 'pow', 'rshift', 'setitem',
                    'sub', 'truediv', 'matmul', 'truth', 'xor',
                    'iadd', 'iand', 'iconcat', 'ifloordiv',
                    'ilshift', 'imod', 'imul', 'ior', 'ipow',
                    'irshift', 'isub', 'itruediv', 'imatmul', 'ixor',
                    'length_hint', 'indexOf']

    interpleveldefs = {
        '_compare_digest': 'tscmp.compare_digest',
    }

    for name in interp_names:
        interpleveldefs[name] = 'interp_operator.%s' % name
