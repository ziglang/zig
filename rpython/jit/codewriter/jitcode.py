from rpython.jit.metainterp.history import AbstractDescr, ConstInt
from rpython.jit.metainterp.support import adr2int
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib.rarithmetic import base_int


class JitCode(AbstractDescr):
    _empty_i = []
    _empty_r = []
    _empty_f = []

    def __init__(self, name, fnaddr=None, calldescr=None, called_from=None):
        self.name = name
        self.fnaddr = fnaddr
        self.calldescr = calldescr
        self.jitdriver_sd = None # None for non-portals
        self._called_from = called_from   # debugging
        self._ssarepr     = None          # debugging

    def setup(self, code='', constants_i=[], constants_r=[], constants_f=[],
              num_regs_i=255, num_regs_r=255, num_regs_f=255,
              liveness=None, startpoints=None, alllabels=None,
              resulttypes=None):
        self.code = code
        for x in constants_i:
            assert not isinstance(x, base_int), (
                "found constant %r of type %r, must not appear in "
                "JitCode.constants_i" % (x, type(x)))
        # if the following lists are empty, use a single shared empty list
        self.constants_i = constants_i or self._empty_i
        self.constants_r = constants_r or self._empty_r
        self.constants_f = constants_f or self._empty_f
        # encode the three num_regs into a single char each
        assert num_regs_i < 256 and num_regs_r < 256 and num_regs_f < 256
        self.c_num_regs_i = chr(num_regs_i)
        self.c_num_regs_r = chr(num_regs_r)
        self.c_num_regs_f = chr(num_regs_f)
        self.liveness = make_liveness_cache(liveness)
        self._startpoints = startpoints   # debugging
        self._alllabels = alllabels       # debugging
        self._resulttypes = resulttypes   # debugging

    def get_fnaddr_as_int(self):
        return adr2int(self.fnaddr)

    def num_regs_i(self):
        return ord(self.c_num_regs_i)

    def num_regs_r(self):
        return ord(self.c_num_regs_r)

    def num_regs_f(self):
        return ord(self.c_num_regs_f)

    def has_liveness_info(self, pc):
        return pc in self.liveness

    def get_live_vars_info(self, pc):
        # 'pc' gives a position in this bytecode.  This returns an object
        # of class LiveVarsInfo that describes all variables that are live
        # across the instruction boundary at 'pc'.
        try:
            return self.liveness[pc]    # XXX compactify!!
        except KeyError:
            self._missing_liveness(pc)

    def _live_vars(self, pc):
        # for testing only
        info = self.get_live_vars_info(pc)
        lst_i = ['%%i%d' % info.get_register_index_i(index)
                 for index in range(info.get_register_count_i()-1, -1, -1)]
        lst_r = ['%%r%d' % info.get_register_index_r(index)
                 for index in range(info.get_register_count_r()-1, -1, -1)]
        lst_f = ['%%f%d' % info.get_register_index_f(index)
                 for index in range(info.get_register_count_f()-1, -1, -1)]
        return ' '.join(lst_i + lst_r + lst_f)

    def _missing_liveness(self, pc):
        msg = "missing liveness[%d] in %s" % (pc, self.name)
        if we_are_translated():
            print msg
            raise AssertionError
        raise MissingLiveness("%s\n%s" % (msg, self.dump()))

    def follow_jump(self, position):
        """Assuming that 'position' points just after a bytecode
        instruction that ends with a label, follow that label."""
        code = self.code
        position -= 2
        assert position >= 0
        if not we_are_translated():
            assert position in self._alllabels
        labelvalue = ord(code[position]) | (ord(code[position+1])<<8)
        assert labelvalue < len(code)
        return labelvalue

    def dump(self):
        if self._ssarepr is None:
            return '<no dump available for %r>' % (self.name,)
        else:
            from rpython.jit.codewriter.format import format_assembler
            return format_assembler(self._ssarepr)

    def __repr__(self):
        return '<JitCode %r>' % self.name

    def _clone_if_mutable(self):
        raise NotImplementedError

class MissingLiveness(Exception):
    pass


class SwitchDictDescr(AbstractDescr):
    "Get a 'dict' attribute mapping integer values to bytecode positions."

    def attach(self, as_dict):
        self.dict = as_dict
        self.const_keys_in_order = map(ConstInt, sorted(as_dict.keys()))

    def __repr__(self):
        dict = getattr(self, 'dict', '?')
        return '<SwitchDictDescr %s>' % (dict,)

    def _clone_if_mutable(self):
        raise NotImplementedError


class LiveVarsInfo(object):
    def __init__(self, live_i, live_r, live_f):
        self.live_i = live_i
        self.live_r = live_r
        self.live_f = live_f

    def get_register_count_i(self):
        return len(self.live_i)
    def get_register_count_r(self):
        return len(self.live_r)
    def get_register_count_f(self):
        return len(self.live_f)

    def get_register_index_i(self, index):
        return ord(self.live_i[index])
    def get_register_index_r(self, index):
        return ord(self.live_r[index])
    def get_register_index_f(self, index):
        return ord(self.live_f[index])

    def enumerate_vars(self, callback_i, callback_r, callback_f, spec):
        for i in range(self.get_register_count_i()):
            callback_i(self.get_register_index_i(i))
        for i in range(self.get_register_count_r()):
            callback_r(self.get_register_index_r(i))
        for i in range(self.get_register_count_f()):
            callback_f(self.get_register_index_f(i))
    enumerate_vars._annspecialcase_ = 'specialize:arg(4)'

_liveness_cache = {}

def make_liveness_cache(liveness):
    if liveness is None:
        return None
    result = {}
    for key, (value_i, value_r, value_f) in liveness.items():
        # Sort the lists to increase the chances of sharing between unrelated
        # strings that happen to contain the same characters.  We sort in the
        # reversed order just to reduce the risks of tests passing by chance.
        value = (''.join(sorted(value_i, reverse=True)),
                 ''.join(sorted(value_r, reverse=True)),
                 ''.join(sorted(value_f, reverse=True)))
        try:
            info = _liveness_cache[value]
        except KeyError:
            info = _liveness_cache[value] = LiveVarsInfo(*value)
        result[key] = info
    return result
