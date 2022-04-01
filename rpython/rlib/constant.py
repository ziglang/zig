import math
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo


class CConfig:
    _compilation_info_ = ExternalCompilationInfo(includes=['float.h'])

    DBL_MAX = rffi_platform.DefinedConstantDouble('DBL_MAX')
    DBL_MIN = rffi_platform.DefinedConstantDouble('DBL_MIN')
    DBL_MANT_DIG = rffi_platform.ConstantInteger('DBL_MANT_DIG')


for k, v in rffi_platform.configure(CConfig).items():
    assert v is not None, "no value found for %r" % k
    globals()[k] = v


assert 0.0 < DBL_MAX < (1e200*1e200)
assert math.isinf(DBL_MAX * 1.0001)
assert DBL_MIN > 0.0
assert DBL_MIN * (2**-53) == 0.0


# Constants.
M_LN2 = 0.6931471805599453094   # natural log of 2
M_LN10 = 2.302585092994045684   # natural log of 10


# CM_LARGE_DOUBLE is used to avoid spurious overflow in the sqrt, log,
# inverse trig and inverse hyperbolic trig functions.  Its log is used in the
# evaluation of exp, cos, cosh, sin, sinh, tan, and tanh to avoid unecessary
# overflow.
CM_LARGE_DOUBLE = DBL_MAX/4.
CM_SQRT_LARGE_DOUBLE = math.sqrt(CM_LARGE_DOUBLE)
CM_LOG_LARGE_DOUBLE = math.log(CM_LARGE_DOUBLE)
CM_SQRT_DBL_MIN = math.sqrt(DBL_MIN)

# CM_SCALE_UP is an odd integer chosen such that multiplication by
# 2**CM_SCALE_UP is sufficient to turn a subnormal into a normal.
# CM_SCALE_DOWN is (-(CM_SCALE_UP+1)/2).  These scalings are used to compute
# square roots accurately when the real and imaginary parts of the argument
# are subnormal.
CM_SCALE_UP = (2*(DBL_MANT_DIG/2) + 1)
CM_SCALE_DOWN = -(CM_SCALE_UP+1)/2
