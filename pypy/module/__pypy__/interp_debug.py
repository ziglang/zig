from pypy.interpreter.gateway import unwrap_spec
from rpython.rlib import debug, jit
from rpython.rlib import rtimer

@jit.dont_look_inside
@unwrap_spec(category='text', timestamp=bool)
def debug_start(space, category, timestamp=False):
    res = debug.debug_start(category, timestamp=timestamp)
    if timestamp:
        return space.newint(res)
    return space.w_None

@jit.dont_look_inside
def debug_print(space, args_w):
    parts = [space.text_w(space.str(w_item)) for w_item in args_w]
    debug.debug_print(' '.join(parts))

@jit.dont_look_inside
@unwrap_spec(category='text', timestamp=bool)
def debug_stop(space, category, timestamp=False):
    res = debug.debug_stop(category, timestamp=timestamp)
    if timestamp:
        return space.newint(res)
    return space.w_None

@unwrap_spec(category='text')
def debug_print_once(space, category, args_w):
    debug_start(space, category)
    debug_print(space, args_w)
    debug_stop(space, category)


@jit.dont_look_inside
def debug_flush(space):
    debug.debug_flush()

def debug_read_timestamp(space):
    return space.newint(rtimer.read_timestamp())

def debug_get_timestamp_unit(space):
    unit = rtimer.get_timestamp_unit()
    if unit == rtimer.UNIT_TSC:
        unit_str = 'tsc'
    elif unit == rtimer.UNIT_NS:
        unit_str = 'ns'
    elif unit == rtimer.UNIT_QUERY_PERFORMANCE_COUNTER:
        unit_str = 'QueryPerformanceCounter'
    else:
        unit_str = 'UNKNOWN(%d)' % unit
    return space.newtext(unit_str)
