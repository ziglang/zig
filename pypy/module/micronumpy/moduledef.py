from pypy.interpreter.mixedmodule import MixedModule


class MultiArrayModule(MixedModule):
    appleveldefs = {
        'arange': 'app_numpy.arange',
        'add_docstring': 'app_numpy.add_docstring'}
    interpleveldefs = {
        'ndarray': 'ndarray.W_NDimArray',
        'dtype': 'descriptor.W_Dtype',
        'flatiter': 'flatiter.W_FlatIterator',
        'flagsobj': 'flagsobj.W_FlagsObject',

        '_reconstruct' : 'ndarray._reconstruct',
        'scalar' : 'ctors.build_scalar',
        'array': 'ctors.array',
        'zeros': 'ctors.zeros',
        'empty': 'ctors.empty',
        'empty_like': 'ctors.empty_like',
        'fromstring': 'ctors.fromstring',
        'frombuffer': 'ctors.frombuffer',

        'concatenate': 'arrayops.concatenate',
        'count_nonzero': 'arrayops.count_nonzero',
        'dot': 'arrayops.dot',
        'where': 'arrayops.where',
        'result_type': 'casting.result_type',
        'can_cast': 'casting.can_cast',
        'min_scalar_type': 'casting.min_scalar_type',
        'promote_types': 'casting.w_promote_types',

        'set_string_function': 'appbridge.set_string_function',
        'typeinfo': 'descriptor.get_dtype_cache(space).w_typeinfo',
        'nditer': 'nditer.W_NDIter',
        'broadcast': 'broadcast.W_Broadcast',

        'set_docstring': 'support.descr_set_docstring',
        'VisibleDeprecationWarning': 'support.W_VisibleDeprecationWarning',
    }
    for c in ['MAXDIMS', 'CLIP', 'WRAP', 'RAISE']:
        interpleveldefs[c] = 'space.wrap(constants.%s)' % c

    def startup(self, space):
        from pypy.module.micronumpy.concrete import _setup
        _setup()


class UMathModule(MixedModule):
    appleveldefs = {}
    interpleveldefs = {
        'FLOATING_POINT_SUPPORT': 'space.newint(1)',
        'frompyfunc': 'ufuncs.frompyfunc',
        }
    # ufuncs
    for exposed, impl in [
        ("absolute", "absolute"),
        ("add", "add"),
        ("arccos", "arccos"),
        ("arcsin", "arcsin"),
        ("arctan", "arctan"),
        ("arctan2", "arctan2"),
        ("arccosh", "arccosh"),
        ("arcsinh", "arcsinh"),
        ("arctanh", "arctanh"),
        ("conj", "conjugate"),
        ("conjugate", "conjugate"),
        ("copysign", "copysign"),
        ("cos", "cos"),
        ("cosh", "cosh"),
        ("divide", "divide"),
        ("true_divide", "true_divide"),
        ("equal", "equal"),
        ("exp", "exp"),
        ("exp2", "exp2"),
        ("expm1", "expm1"),
        ("fabs", "fabs"),
        ("fmax", "fmax"),
        ("fmin", "fmin"),
        ("fmod", "fmod"),
        ("floor", "floor"),
        ("ceil", "ceil"),
        ("trunc", "trunc"),
        ("greater", "greater"),
        ("greater_equal", "greater_equal"),
        ("less", "less"),
        ("less_equal", "less_equal"),
        ("maximum", "maximum"),
        ("minimum", "minimum"),
        ("mod", "mod"),
        ("multiply", "multiply"),
        ("negative", "negative"),
        ("not_equal", "not_equal"),
        ("radians", "radians"),
        ("degrees", "degrees"),
        ("deg2rad", "radians"),
        ("rad2deg", "degrees"),
        ("reciprocal", "reciprocal"),
        ("rint", "rint"),
        ("sign", "sign"),
        ("signbit", "signbit"),
        ("sin", "sin"),
        ("sinh", "sinh"),
        ("subtract", "subtract"),
        ('sqrt', 'sqrt'),
        ('square', 'square'),
        ("tan", "tan"),
        ("tanh", "tanh"),
        ('bitwise_and', 'bitwise_and'),
        ('bitwise_or', 'bitwise_or'),
        ('bitwise_xor', 'bitwise_xor'),
        ('bitwise_not', 'invert'),
        ('left_shift', 'left_shift'),
        ('right_shift', 'right_shift'),
        ('invert', 'invert'),
        ('isnan', 'isnan'),
        ('isinf', 'isinf'),
        ('isfinite', 'isfinite'),
        ('logical_and', 'logical_and'),
        ('logical_xor', 'logical_xor'),
        ('logical_not', 'logical_not'),
        ('logical_or', 'logical_or'),
        ('log', 'log'),
        ('log2', 'log2'),
        ('log10', 'log10'),
        ('log1p', 'log1p'),
        ('power', 'power'),
        ('floor_divide', 'floor_divide'),
        ('logaddexp', 'logaddexp'),
        ('logaddexp2', 'logaddexp2'),
        ('real', 'real'),
        ('imag', 'imag'),
    ]:
        interpleveldefs[exposed] = "ufuncs.get(space).%s" % impl


class Module(MixedModule):
    applevel_name = '_numpypy'
    appleveldefs = {}
    interpleveldefs = {}
    submodules = {
        'multiarray': MultiArrayModule,
        'umath': UMathModule,
    }

    def setup_after_space_initialization(self):
        from pypy.module.micronumpy.support import W_VisibleDeprecationWarning
        for name, w_type in {'VisibleDeprecationWarning': W_VisibleDeprecationWarning}.items():
            setattr(self.space, 'w_' + name, self.space.gettypefor(w_type))

