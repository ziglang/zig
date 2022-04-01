from pypy.interpreter.error import oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.gateway import interp2app, unwrap_spec
from pypy.interpreter.typedef import TypeDef, GetSetProperty
from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.tool import rffi_platform
from rpython.translator.tool.cbuild import ExternalCompilationInfo
import math

time_t = rffi_platform.getsimpletype('time_t', '#include <time.h>', rffi.SIGNED)

eci = ExternalCompilationInfo(includes=['time.h'])
time = rffi.llexternal('time', [lltype.Signed], time_t,
                       compilation_info=eci)

def get(space, name):
    w_module = space.getbuiltinmodule('_demo')
    return space.getattr(w_module, space.newtext(name))


@unwrap_spec(repetitions=int)
def measuretime(space, repetitions, w_callable):
    if repetitions <= 0:
        w_DemoError = get(space, 'DemoError')
        raise oefmt(w_DemoError, "repetition count must be > 0")
    starttime = time(0)
    for i in range(repetitions):
        space.call_function(w_callable)
    endtime = time(0)
    return space.newint(endtime - starttime)

@unwrap_spec(n=int)
def sieve(space, n):
    lst = range(2, n + 1)
    head = 0
    while 1:
        first = lst[head]
        if first > math.sqrt(n) + 1:
            lst_w = [space.newint(i) for i in lst]
            return space.newlist(lst_w)
        newlst = []
        for element in lst:
            if element <= first:
                newlst.append(element)
            elif element % first != 0:
                newlst.append(element)
        lst = newlst
        head += 1

class W_MyType(W_Root):
    def __init__(self, space, x=1):
        self.space = space
        self.x = x

    def multiply(self, w_y):
        space = self.space
        y = space.int_w(w_y)
        return space.newint(self.x * y)

    def fget_x(self, space):
        return space.newint(self.x)

    def fset_x(self, space, w_value):
        self.x = space.int_w(w_value)

@unwrap_spec(x=int)
def mytype_new(space, w_subtype, x):
    if x == 3:
        return MySubType(space, x)
    return W_MyType(space, x)

getset_x = GetSetProperty(W_MyType.fget_x, W_MyType.fset_x, cls=W_MyType)

class MySubType(W_MyType):
    pass

W_MyType.typedef = TypeDef('MyType',
    __new__ = interp2app(mytype_new),
    x = getset_x,
    multiply = interp2app(W_MyType.multiply),
)
