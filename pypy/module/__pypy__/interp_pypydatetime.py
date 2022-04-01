from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app
from rpython.tool.sourcetools import func_with_new_name

def create_class(name):
    class W_Class(W_Root):
        'builtin base class for datetime.%s to allow interop with cpyext' % name
        def descr_new__(space, w_type):
            return space.allocate_instance(W_Class, w_type)

    W_Class.typedef = TypeDef(name,
        __new__ = interp2app(func_with_new_name(
                                    W_Class.descr_new__.im_func,
                                    '%s_new' % (name,))),
        )
    W_Class.typedef.acceptable_as_base_class = True
    return W_Class

W_DateTime_Time = create_class('pypydatetime_time')
W_DateTime_Date = create_class('pypydatetime_date')
W_DateTime_Delta = create_class('pypydatetime_delta')


