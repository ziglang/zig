import sys

from pypy.interpreter.mixedmodule import MixedModule
from pypy.module.imp.importing import get_pyc_magic
from rpython.rlib import rtime


class BuildersModule(MixedModule):
    """ Module containing string and unicode builders """

    appleveldefs = {}

    interpleveldefs = {
        "StringBuilder": "interp_builders.W_StringBuilder",
        "BytesBuilder": "interp_builders.W_BytesBuilder",
    }

class TimeModule(MixedModule):
    appleveldefs = {}
    interpleveldefs = {}
    if rtime.HAS_CLOCK_GETTIME:
        interpleveldefs["clock_gettime"] = "interp_time.clock_gettime"
        interpleveldefs["clock_getres"] = "interp_time.clock_getres"
        for name in rtime.ALL_DEFINED_CLOCKS:
            interpleveldefs[name] = "space.wrap(%d)" % getattr(rtime, name)


class ThreadModule(MixedModule):
    appleveldefs = {
        'signals_enabled': 'app_signal.signals_enabled',
    }
    interpleveldefs = {
        '_signals_enter':  'interp_signal.signals_enter',
        '_signals_exit':   'interp_signal.signals_exit',
    }


class IntOpModule(MixedModule):
    """ Module for integer operations that have two-complement overflow
    behaviour instead of overflowing to longs """
    appleveldefs = {}
    interpleveldefs = {
        'int_add':         'interp_intop.int_add',
        'int_sub':         'interp_intop.int_sub',
        'int_mul':         'interp_intop.int_mul',
        'int_floordiv':    'interp_intop.int_floordiv',
        'int_mod':         'interp_intop.int_mod',
        'int_lshift':      'interp_intop.int_lshift',
        'int_rshift':      'interp_intop.int_rshift',
        'uint_rshift':     'interp_intop.uint_rshift',
        'int_mulmod':      'interp_intop.int_mulmod',
    }


class OsModule(MixedModule):
    appleveldefs = {}
    interpleveldefs = {
        'real_getenv': 'interp_os.real_getenv',
        '_get_multiarch': 'interp_os._get_multiarch',
    }


class PyPyDateTime(MixedModule):
    appleveldefs = {}
    interpleveldefs = {
        'dateinterop'  : 'interp_pypydatetime.W_DateTime_Date',
        'timeinterop'  : 'interp_pypydatetime.W_DateTime_Time',
        'deltainterop' : 'interp_pypydatetime.W_DateTime_Delta',
    }

class PyPyBufferable(MixedModule):
    appleveldefs = {}
    interpleveldefs = {
        'bufferable': 'interp_buffer.W_Bufferable',
    }


class Module(MixedModule):
    """ PyPy specific "magic" functions. A lot of them are experimental and
    subject to change, many are internal. """
    appleveldefs = {
    }

    interpleveldefs = {
        'attach_gdb'                : 'interp_magic.attach_gdb',
        'internal_repr'             : 'interp_magic.internal_repr',
        'objects_in_repr'           : 'interp_magic.objects_in_repr',
        'bytebuffer'                : 'bytebuffer.bytebuffer',
        'identity_dict'             : 'interp_identitydict.W_IdentityDict',
        'debug_start'               : 'interp_debug.debug_start',
        'debug_print'               : 'interp_debug.debug_print',
        'debug_stop'                : 'interp_debug.debug_stop',
        'debug_print_once'          : 'interp_debug.debug_print_once',
        'debug_flush'               : 'interp_debug.debug_flush',
        'debug_read_timestamp'      : 'interp_debug.debug_read_timestamp',
        'debug_get_timestamp_unit'  : 'interp_debug.debug_get_timestamp_unit',
        'builtinify'                : 'interp_magic.builtinify',
        'hidden_applevel'           : 'interp_magic.hidden_applevel',
        'lookup_special'            : 'interp_magic.lookup_special',
        'do_what_I_mean'            : 'interp_magic.do_what_I_mean',
        '_internal_crash'           : 'interp_magic._internal_crash',
        'resizelist_hint'           : 'interp_magic.resizelist_hint',
        'newlist_hint'              : 'interp_magic.newlist_hint',
        'add_memory_pressure'       : 'interp_magic.add_memory_pressure',
        'newdict'                   : 'interp_dict.newdict',
        'reversed_dict'             : 'interp_dict.reversed_dict',
        'dict_popitem_first'        : 'interp_dict.dict_popitem_first',
        'delitem_if_value_is'       : 'interp_dict.delitem_if_value_is',
        'move_to_end'               : 'interp_dict.move_to_end',
        'strategy'                  : 'interp_magic.strategy',  # dict,set,list
        'locals_to_fast'            : 'interp_magic.locals_to_fast',
        'set_code_callback'         : 'interp_magic.set_code_callback',
        'decode_long'               : 'interp_magic.decode_long',
        '_promote'                   : 'interp_magic._promote',
        'normalize_exc'             : 'interp_magic.normalize_exc',
        'StdErrPrinter'             : 'interp_stderrprinter.W_StdErrPrinter',
        'side_effects_ok'           : 'interp_magic.side_effects_ok',
        'stack_almost_full'         : 'interp_magic.stack_almost_full',
        'fsencode'                  : 'interp_magic.fsencode',
        'fsdecode'                  : 'interp_magic.fsdecode',
        'pyos_inputhook'            : 'interp_magic.pyos_inputhook',
        'newmemoryview'             : 'interp_buffer.newmemoryview',
        'set_exc_info'              : 'interp_magic.set_exc_info',
        'utf8content'               : 'interp_magic.utf8content',
        'list_get_physical_size'    : 'interp_magic.list_get_physical_size',

        'get_contextvar_context'    : 'interp_magic.get_contextvar_context',
        'set_contextvar_context'    : 'interp_magic.set_contextvar_context',

        'write_unraisable'          : 'interp_magic.write_unraisable',

        'PickleBuffer'              : 'interp_buffer.W_PickleBuffer',
    }
    if sys.platform == 'win32':
        interpleveldefs['get_console_cp'] = 'interp_magic.get_console_cp'
        interpleveldefs['get_osfhandle'] = 'interp_magic.get_osfhandle'

    submodules = {
        "builders": BuildersModule,
        "time": TimeModule,
        "thread": ThreadModule,
        "intop": IntOpModule,
        "os": OsModule,
        '_pypydatetime': PyPyDateTime,
        'bufferable': PyPyBufferable,
    }

    def setup_after_space_initialization(self):
        """NOT_RPYTHON"""
        if self.space.config.objspace.std.withmethodcachecounter:
            self.extra_interpdef('method_cache_counter',
                                 'interp_magic.method_cache_counter')
            self.extra_interpdef('reset_method_cache_counter',
                                 'interp_magic.reset_method_cache_counter')
            self.extra_interpdef('mapdict_cache_counter',
                                 'interp_magic.mapdict_cache_counter')
        PYC_MAGIC = get_pyc_magic(self.space)
        self.extra_interpdef('PYC_MAGIC', 'space.wrap(%d)' % PYC_MAGIC)
        try:
            from rpython.jit.backend import detect_cpu
            model = detect_cpu.autodetect()
            self.extra_interpdef('cpumodel', 'space.wrap(%r)' % model)
        except Exception:
            if self.space.config.translation.jit:
                raise
            else:
                pass   # ok fine to ignore in this case

        if self.space.config.translation.jit:
            features = detect_cpu.getcpufeatures(model)
            self.extra_interpdef('jit_backend_features',
                                    'space.wrap(%r)' % features)
        if self.space.config.translation.reverse_debugger:
            self.extra_interpdef('revdb_stop', 'interp_magic.revdb_stop')
        else:
            self.extra_interpdef('revdb_stop', 'space.w_None')

        if not self.space.config.translating:
            self.extra_interpdef(
                '_testing_clear_audithooks', 'interp_magic._testing_clear_audithooks')
