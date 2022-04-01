
# Package initialisation
from pypy.interpreter.mixedmodule import MixedModule

names_and_docstrings = {
    'sqrt': "Return the square root of x.",
    'acos': "Return the arc cosine of x.",
    'acosh': "Return the hyperbolic arc cosine of x.",
    'asin': "Return the arc sine of x.",
    'asinh': "Return the hyperbolic arc sine of x.",
    'atan': "Return the arc tangent of x.",
    'atanh': "Return the hyperbolic arc tangent of x.",
    'log': ("log(x[, base]) -> the logarithm of x to the given base.\n"
            "If the base not specified, returns the natural logarithm "
            "(base e) of x."),
    'log10': "Return the base-10 logarithm of x.",
    'exp': "Return the exponential value e**x.",
    'cosh': "Return the hyperbolic cosine of x.",
    'sinh': "Return the hyperbolic sine of x.",
    'tanh': "Return the hyperbolic tangent of x.",
    'cos': "Return the cosine of x.",
    'sin': "Return the sine of x.",
    'tan': "Return the tangent of x.",
    'rect': "Convert from polar coordinates to rectangular coordinates.",
    'polar': ("polar(z) -> r: float, phi: float\n"
              "Convert a complex from rectangular coordinates "
              "to polar coordinates. r is\n"
              "the distance from 0 and phi the phase angle."),
    'phase': "Return argument, also known as the phase angle, of a complex.",
    'isinf': "Checks if the real or imaginary part of z is infinite.",
    'isnan': "Checks if the real or imaginary part of z is not a number (NaN)",
    'isfinite': "isfinite(z) -> bool\nReturn True if both the real and imaginary parts of z are finite, else False.",
}


class Module(MixedModule):
    appleveldefs = {
    }

    interpleveldefs = {
        'pi': 'space.newfloat(interp_cmath.pi)',
        'e':  'space.newfloat(interp_cmath.e)',
        'inf':  'space.newfloat(interp_cmath.inf)',
        'nan':  'space.newfloat(interp_cmath.nan)',
        'infj':  'space.newcomplex(0.0, interp_cmath.inf)',
        'nanj':  'space.newcomplex(0.0, interp_cmath.nan)',
        'isclose': 'interp_cmath.isclose',
    }
    interpleveldefs.update(dict([(name, 'interp_cmath.wrapped_' + name)
                                 for name in names_and_docstrings]))
