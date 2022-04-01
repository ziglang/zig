from rpython.jit.metainterp.history import AbstractDescr, getkind
from rpython.jit.metainterp.support import adr2int, int2adr
from rpython.jit.codewriter.flatten import Register, Label, TLabel, KINDS
from rpython.jit.codewriter.flatten import ListOfKind, IndirectCallTargets
from rpython.jit.codewriter.format import format_assembler
from rpython.jit.codewriter.jitcode import SwitchDictDescr, JitCode
from rpython.jit.codewriter import longlong
from rpython.rlib.objectmodel import ComputedIntSymbolic
from rpython.rlib.rarithmetic import r_int
from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper import rclass


class AssemblerError(Exception):
    pass


class Assembler(object):

    def __init__(self):
        self.insns = {}
        self.descrs = []
        self.indirectcalltargets = set()    # set of JitCodes
        self.list_of_addr2name = []
        self._descr_dict = {}
        self._count_jitcodes = 0
        self._seen_raw_objects = set()

    def assemble(self, ssarepr, jitcode=None):
        """Take the 'ssarepr' representation of the code and assemble
        it inside the 'jitcode'.  If jitcode is None, make a new one.
        """
        self.setup(ssarepr.name)
        ssarepr._insns_pos = []
        for insn in ssarepr.insns:
            ssarepr._insns_pos.append(len(self.code))
            self.write_insn(insn)
        self.fix_labels()
        self.check_result()
        if jitcode is None:
            jitcode = JitCode(ssarepr.name)
        jitcode._ssarepr = ssarepr
        self.make_jitcode(jitcode)
        if self._count_jitcodes < 20:    # stop if we have a lot of them
            jitcode._dump = format_assembler(ssarepr)
        self._count_jitcodes += 1
        return jitcode

    def setup(self, name):
        self.code = []
        self.constants_dict = {}
        self.constants_i = []
        self.constants_r = []
        self.constants_f = []
        self.label_positions = {}
        self.tlabel_positions = []
        self.switchdictdescrs = []
        self.count_regs = dict.fromkeys(KINDS, 0)
        self.liveness = {}
        self.startpoints = set()
        self.alllabels = set()
        self.resulttypes = {}
        self.ssareprname = name

    def emit_reg(self, reg):
        if reg.index >= self.count_regs[reg.kind]:
            self.count_regs[reg.kind] = reg.index + 1
        self.code.append(chr(reg.index))

    def emit_const(self, const, kind, allow_short=False):
        value = const.value
        if kind == 'int':
            TYPE = const.concretetype
            if isinstance(TYPE, lltype.Ptr):
                assert TYPE.TO._gckind == 'raw'
                self.see_raw_object(value)
                value = llmemory.cast_ptr_to_adr(value)
                TYPE = llmemory.Address
            if TYPE == llmemory.Address:
                value = adr2int(value)
            if TYPE is lltype.SingleFloat:
                value = longlong.singlefloat2int(value)
            if not isinstance(value, (llmemory.AddressAsInt,
                                      ComputedIntSymbolic)):
                value = lltype.cast_primitive(lltype.Signed, value)
                if type(value) is r_int:
                    value = int(value)
                if allow_short:
                    try:
                        short_num = -128 <= value <= 127
                    except TypeError:    # "Symbolics cannot be compared!"
                        short_num = False
                    if short_num:
                        # emit the constant as a small integer
                        self.code.append(chr(value & 0xFF))
                        return True
            constants = self.constants_i
        elif kind == 'ref':
            value = lltype.cast_opaque_ptr(llmemory.GCREF, value)
            constants = self.constants_r
        elif kind == 'float':
            if const.concretetype == lltype.Float:
                value = longlong.getfloatstorage(value)
            else:
                assert longlong.is_longlong(const.concretetype)
                value = rffi.cast(lltype.SignedLongLong, value)
            constants = self.constants_f
        else:
            raise AssemblerError('unimplemented %r in %r' %
                                 (const, self.ssareprname))
        key = (kind, Constant(value))
        if key not in self.constants_dict:
            constants.append(value)
            val = 256 - len(constants)
            assert val >= 0, "too many constants"
            self.constants_dict[key] = val
        # emit the constant normally, as one byte that is an index in the
        # list of constants
        self.code.append(chr(self.constants_dict[key]))
        return False

    def write_insn(self, insn):
        if insn[0] == '---':
            return
        if isinstance(insn[0], Label):
            self.label_positions[insn[0].name] = len(self.code)
            return
        if insn[0] == '-live-':
            key = len(self.code)
            live_i, live_r, live_f = self.liveness.get(key, ("", "", ""))
            live_i = self.get_liveness_info(live_i, insn[1:], 'int')
            live_r = self.get_liveness_info(live_r, insn[1:], 'ref')
            live_f = self.get_liveness_info(live_f, insn[1:], 'float')
            self.liveness[key] = live_i, live_r, live_f
            return
        startposition = len(self.code)
        self.code.append("temporary placeholder")
        #
        argcodes = []
        allow_short = (insn[0] in USE_C_FORM)
        for x in insn[1:]:
            if isinstance(x, Register):
                self.emit_reg(x)
                argcodes.append(x.kind[0])
            elif isinstance(x, Constant):
                kind = getkind(x.concretetype)
                is_short = self.emit_const(x, kind, allow_short=allow_short)
                if is_short:
                    argcodes.append('c')
                else:
                    argcodes.append(kind[0])
            elif isinstance(x, TLabel):
                self.alllabels.add(len(self.code))
                self.tlabel_positions.append((x.name, len(self.code)))
                self.code.append("temp 1")
                self.code.append("temp 2")
                argcodes.append('L')
            elif isinstance(x, ListOfKind):
                itemkind = x.kind
                lst = list(x)
                assert len(lst) <= 255, "list too long!"
                self.code.append(chr(len(lst)))
                for item in lst:
                    if isinstance(item, Register):
                        assert itemkind == item.kind
                        self.emit_reg(item)
                    elif isinstance(item, Constant):
                        assert itemkind == getkind(item.concretetype)
                        self.emit_const(item, itemkind)
                    else:
                        raise NotImplementedError("found in ListOfKind(): %r"
                                                  % (item,))
                argcodes.append(itemkind[0].upper())
            elif isinstance(x, AbstractDescr):
                if x not in self._descr_dict:
                    self._descr_dict[x] = len(self.descrs)
                    self.descrs.append(x)
                if isinstance(x, SwitchDictDescr):
                    self.switchdictdescrs.append(x)
                num = self._descr_dict[x]
                assert 0 <= num <= 0xFFFF, "too many AbstractDescrs!"
                self.code.append(chr(num & 0xFF))
                self.code.append(chr(num >> 8))
                argcodes.append('d')
            elif isinstance(x, IndirectCallTargets):
                self.indirectcalltargets.update(x.lst)
            elif x == '->':
                assert '>' not in argcodes
                argcodes.append('>')
            else:
                raise NotImplementedError(x)
        #
        opname = insn[0]
        if '>' in argcodes:
            assert argcodes.index('>') == len(argcodes) - 2
            self.resulttypes[len(self.code)] = argcodes[-1]
        key = opname + '/' + ''.join(argcodes)
        num = self.insns.setdefault(key, len(self.insns))
        self.code[startposition] = chr(num)
        self.startpoints.add(startposition)

    def get_liveness_info(self, prevlives, args, kind):
        """Return a string whose characters are register numbers.
        We sort the numbers, too, to increase the chances of duplicate
        strings (which are collapsed into a single string during translation).
        """
        lives = set(prevlives)    # set of characters
        for reg in args:
            if isinstance(reg, Register) and reg.kind == kind:
                lives.add(chr(reg.index))
        return lives

    def fix_labels(self):
        for name, pos in self.tlabel_positions:
            assert self.code[pos  ] == "temp 1"
            assert self.code[pos+1] == "temp 2"
            target = self.label_positions[name]
            assert 0 <= target <= 0xFFFF
            self.code[pos  ] = chr(target & 0xFF)
            self.code[pos+1] = chr(target >> 8)
        for descr in self.switchdictdescrs:
            as_dict = {}
            for key, switchlabel in descr._labels:
                target = self.label_positions[switchlabel.name]
                as_dict[key] = target
            descr.attach(as_dict)

    def check_result(self):
        # Limitation of the number of registers, from the single-byte encoding
        assert self.count_regs['int'] + len(self.constants_i) <= 256
        assert self.count_regs['ref'] + len(self.constants_r) <= 256
        assert self.count_regs['float'] + len(self.constants_f) <= 256

    def make_jitcode(self, jitcode):
        jitcode.setup(''.join(self.code),
                      self.constants_i,
                      self.constants_r,
                      self.constants_f,
                      self.count_regs['int'],
                      self.count_regs['ref'],
                      self.count_regs['float'],
                      liveness=self.liveness,
                      startpoints=self.startpoints,
                      alllabels=self.alllabels,
                      resulttypes=self.resulttypes)

    def see_raw_object(self, value):
        if value._obj not in self._seen_raw_objects:
            self._seen_raw_objects.add(value._obj)
            if not value:    # filter out NULL pointers
                return
            TYPE = lltype.typeOf(value).TO
            if isinstance(TYPE, lltype.FuncType):
                name = value._obj._name
            elif TYPE == rclass.OBJECT_VTABLE:
                if not value.name:    # this is really the "dummy" class
                    return            #   pointer from some dict
                name = ''.join(value.name.chars)
            else:
                return
            addr = llmemory.cast_ptr_to_adr(value)
            self.list_of_addr2name.append((addr, name))

    def finished(self, callinfocollection):
        # Helper called at the end of assembling.  Registers the extra
        # functions shown in _callinfo_for_oopspec.
        for func in callinfocollection.all_function_addresses_as_int():
            func = int2adr(func)
            self.see_raw_object(func.ptr)


# A set of instructions that use the 'c' encoding for small constants.
# Allowing it anywhere causes the number of instruction variants to
# expode, growing past 256.  So we list here only the most common
# instructions where the 'c' variant might be useful.
USE_C_FORM = set([
    'copystrcontent',
    'getarrayitem_gc_pure_i',
    'getarrayitem_gc_pure_r',
    'getarrayitem_gc_i',
    'getarrayitem_gc_r',
    'goto_if_not_int_eq',
    'goto_if_not_int_ge',
    'goto_if_not_int_gt',
    'goto_if_not_int_le',
    'goto_if_not_int_lt',
    'goto_if_not_int_ne',
    'int_add',
    'int_and',
    'int_copy',
    'int_eq',
    'int_ge',
    'int_gt',
    'int_le',
    'int_lt',
    'int_ne',
    'int_return',
    'int_sub',
    'jit_merge_point',
    'new_array',
    'new_array_clear',
    'newstr',
    'setarrayitem_gc_i',
    'setarrayitem_gc_r',
    'setfield_gc_i',
    'strgetitem',
    'strsetitem',

    'foobar', 'baz',    # for tests
])
