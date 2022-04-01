from rpython.jit.backend.zarch import locations as loc
from rpython.rlib.objectmodel import specialize

class ConditionLocation(loc.ImmLocation):
    _immutable_ = True
    def __repr__(self):
        s = ""
        if self.value & 0x1 != 0:
            s += "OF"
        if self.value & 0x2 != 0:
            s += " GT"
        if self.value & 0x4 != 0:
            s += " LT"
        if self.value & 0x8 != 0:
            s += " EQ"
        return "cond(%s)" % s

# normal branch instructions
FLOAT = ConditionLocation(0x10)

VEQI = EQ = ConditionLocation(0x8)
LT = ConditionLocation(0x4)
GT = ConditionLocation(0x2)
OF = ConditionLocation(0x1) # overflow

LE = ConditionLocation(EQ.value | LT.value | OF.value)
FLE = ConditionLocation(EQ.value | LT.value)
GE = ConditionLocation(EQ.value | GT.value | OF.value)
FGE = ConditionLocation(EQ.value | GT.value)
VNEI = NE = ConditionLocation(LT.value | GT.value | OF.value)
NO = ConditionLocation(0xe) # NO overflow

FGT = ConditionLocation(GT.value | OF.value)
FLT = ConditionLocation(LT.value | OF.value)

ANY = ConditionLocation(0xf)

FP_ROUND_DEFAULT = loc.imm(0x0)
FP_TOWARDS_ZERO = loc.imm(0x5)

cond_none = loc.imm(-1)

opposites = [None] * 16
opposites[0] = ANY

opposites[OF.value] = NO
opposites[GT.value] = LE
opposites[LT.value] = GE
opposites[EQ.value] = NE

opposites[NO.value] = OF
opposites[LE.value] = GT
opposites[GE.value] = LT
opposites[NE.value] = EQ

opposites[FGE.value] = FLT
opposites[FLE.value] = FGT

opposites[FGT.value] = FLE
opposites[FLT.value] = FGE

opposites[ANY.value] = ConditionLocation(0)

def negate(cond):
    cc = opposites[cond.value]
    if cc is None:
        assert 0, "provide a sane value to negate"
    return cc

def _assert_value(v1, v2):
    assert v1.value == v2.value
_assert_value(negate(EQ), NE)
_assert_value(negate(NE), EQ)
_assert_value(negate(LT), GE)
_assert_value(negate(LE), GT)
_assert_value(negate(GT), LE)
_assert_value(negate(GE), LT)
_assert_value(negate(NO), OF)
_assert_value(negate(OF), NO)

_assert_value(negate(FLE), FGT)
_assert_value(negate(FGT), FLE)

_assert_value(negate(FGE), FLT)
_assert_value(negate(FLT), FGE)

del _assert_value
