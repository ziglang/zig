
from pypy.interpreter.mixedmodule import MixedModule
from .interp_time import HAS_MONOTONIC, HAS_THREAD_TIME
from rpython.rlib import rtime
import os

_WIN = os.name == "nt"

class Module(MixedModule):
    applevel_name = 'time'

    interpleveldefs = {
        'time': 'interp_time.time',
        'time_ns': 'interp_time.time_ns',
        'clock': 'interp_time.clock',
        'ctime': 'interp_time.ctime',
        'asctime': 'interp_time.asctime',
        'gmtime': 'interp_time.gmtime',
        'localtime': 'interp_time.localtime',
        'mktime': 'interp_time.mktime',
        'strftime': 'interp_time.strftime',
        'sleep' : 'interp_time.sleep',
        '_STRUCT_TM_ITEMS': 'space.wrap(interp_time._STRUCT_TM_ITEMS)',
        'perf_counter': 'interp_time.perf_counter',
        'perf_counter_ns': 'interp_time.perf_counter_ns',
        'process_time': 'interp_time.process_time',
        'process_time_ns': 'interp_time.process_time_ns',
        '_get_time_info': 'interp_time._get_time_info',
    }

    if rtime.HAS_CLOCK_GETTIME:
        interpleveldefs['clock_gettime'] = 'interp_time.clock_gettime'
        interpleveldefs['clock_gettime_ns'] = 'interp_time.clock_gettime_ns'
        interpleveldefs['clock_settime'] = 'interp_time.clock_settime'
        interpleveldefs['clock_settime_ns'] = 'interp_time.clock_settime_ns'
        interpleveldefs['clock_getres'] = 'interp_time.clock_getres'
        for constant in rtime.ALL_DEFINED_CLOCKS:
            interpleveldefs[constant] = 'space.wrap(%d)' % (
                getattr(rtime, constant),)
    if HAS_MONOTONIC:
        interpleveldefs['monotonic'] = 'interp_time.monotonic'
        interpleveldefs['monotonic_ns'] = 'interp_time.monotonic_ns'
    if HAS_THREAD_TIME:
        interpleveldefs['thread_time'] = 'interp_time.thread_time'
        interpleveldefs['thread_time_ns'] = 'interp_time.thread_time_ns'
    if os.name == "posix":
        interpleveldefs['tzset'] = 'interp_time.tzset'

    appleveldefs = {
        'struct_time': 'app_time.struct_time',
        '__doc__': 'app_time.__doc__',
        'strptime': 'app_time.strptime',
        'get_clock_info': 'app_time.get_clock_info'
    }

    def startup(self, space):
        if _WIN:
            from pypy.module.time.interp_time import State
            space.fromcache(State).startup(space)

        # this machinery is needed to expose constants
        # that have to be initialized one time only
        from pypy.module.time import interp_time

        interp_time._init_timezone(space)

