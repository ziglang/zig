import py
from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem import lltype
from rpython.jit.codewriter.flatten import SSARepr, Label, TLabel, Register
from rpython.jit.codewriter.flatten import ListOfKind, IndirectCallTargets
from rpython.jit.codewriter.jitcode import SwitchDictDescr
from rpython.jit.metainterp.history import AbstractDescr


def format_assembler(ssarepr):
    """For testing: format a SSARepr as a multiline string."""
    from cStringIO import StringIO

    def repr(x):
        if isinstance(x, Register):
            return '%%%s%d' % (x.kind[0], x.index)    # e.g. %i1 or %r2 or %f3
        elif isinstance(x, Constant):
            if (isinstance(x.concretetype, lltype.Ptr) and
                isinstance(x.concretetype.TO, lltype.Struct)):
                return '$<* struct %s>' % (x.concretetype.TO._name,)
            return '$%r' % (x.value,)
        elif isinstance(x, TLabel):
            return getlabelname(x)
        elif isinstance(x, ListOfKind):
            return '%s[%s]' % (x.kind[0].upper(), ', '.join(map(repr, x)))
        elif isinstance(x, SwitchDictDescr):
            return '<SwitchDictDescr %s>' % (
                ', '.join(['%s:%s' % (key, getlabelname(lbl))
                           for key, lbl in x._labels]))
        elif isinstance(x, (AbstractDescr, IndirectCallTargets)):
            return '%r' % (x,)
        else:
            return '<unknown object: %r>' % (x,)

    seenlabels = {}
    for asm in ssarepr.insns:
        for x in asm:
            if isinstance(x, TLabel):
                seenlabels[x.name] = -1
            elif isinstance(x, SwitchDictDescr):
                for _, switch in x._labels:
                    seenlabels[switch.name] = -1
    labelcount = [0]
    def getlabelname(lbl):
        if seenlabels[lbl.name] == -1:
            labelcount[0] += 1
            seenlabels[lbl.name] = labelcount[0]
        return 'L%d' % seenlabels[lbl.name]

    output = StringIO()
    insns = ssarepr.insns
    if insns and insns[-1] == ('---',):
        insns = insns[:-1]
    for i, asm in enumerate(insns):
        if ssarepr._insns_pos:
            prefix = '%4d  ' % ssarepr._insns_pos[i]
        else:
            prefix = ''
        if isinstance(asm[0], Label):
            if asm[0].name in seenlabels:
                print >> output, prefix + '%s:' % getlabelname(asm[0])
        else:
            print >> output, prefix + asm[0],
            if len(asm) > 1:
                if asm[-2] == '->':
                    if len(asm) == 3:
                        print >> output, '->', repr(asm[-1])
                    else:
                        lst = map(repr, asm[1:-2])
                        print >> output, ', '.join(lst), '->', repr(asm[-1])
                else:
                    lst = map(repr, asm[1:])
                    if asm[0] == '-live-': lst.sort()
                    print >> output, ', '.join(lst)
            else:
                print >> output
    res = output.getvalue()
    return res

def assert_format(ssarepr, expected):
    asm = format_assembler(ssarepr)
    if expected != '':
        expected = str(py.code.Source(expected)).strip() + '\n'
    asmlines = asm.split("\n")
    explines = expected.split("\n")
    for asm, exp in zip(asmlines, explines):
        if asm != exp:
            msg = [""]
            msg.append("Got:      " + asm)
            msg.append("Expected: " + exp)
            lgt = 0
            for i in range(min(len(asm), len(exp))):
                if exp[i] == asm[i]:
                    lgt += 1
                else:
                    break
            msg.append("          " + " " * lgt + "^^^^")
            raise AssertionError('\n'.join(msg))
    assert len(asmlines) == len(explines)

def unformat_assembler(text, registers=None):
    # XXX limited to simple assembler right now
    #
    def unformat_arg(s):
        if s.endswith(','):
            s = s[:-1].rstrip()
        if s[0] == '%':
            try:
                return registers[s]
            except KeyError:
                num = int(s[2:])
                if s[1] == 'i': reg = Register('int', num)
                elif s[1] == 'r': reg = Register('ref', num)
                elif s[1] == 'f': reg = Register('float', num)
                else: raise AssertionError("bad register type")
                registers[s] = reg
                return reg
        elif s[0] == '$':
            intvalue = int(s[1:])
            return Constant(intvalue, lltype.Signed)
        elif s[0] == 'L':
            return TLabel(s)
        elif s[0] in 'IRF' and s[1] == '[' and s[-1] == ']':
            items = split_words(s[2:-1])
            items = map(unformat_arg, items)
            return ListOfKind({'I': 'int', 'R': 'ref', 'F': 'float'}[s[0]],
                              items)
        elif s.startswith('<SwitchDictDescr '):
            assert s.endswith('>')
            switchdict = SwitchDictDescr()
            switchdict._labels = []
            items = split_words(s[len('<SwitchDictDescr '):-1])
            for item in items:
                key, value = item.split(':')
                value = value.rstrip(',')
                switchdict._labels.append((int(key), TLabel(value)))
            return switchdict
        else:
            raise AssertionError("unsupported argument: %r" % (s,))
    #
    if registers is None:
        registers = {}
    ssarepr = SSARepr('test')
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith('L') and line.endswith(':'):
            ssarepr.insns.append((Label(line[:-1]),))
        else:
            try:
                opname, line = line.split(None, 1)
            except ValueError:
                opname, line = line, ''
            words = list(split_words(line))
            if '->' in words:
                assert words.index('->') == len(words) - 2
                extra = ['->', unformat_arg(words[-1])]
                del words[-2:]
            else:
                extra = []
            insn = [opname] + [unformat_arg(s) for s in words] + extra
            ssarepr.insns.append(tuple(insn))
    return ssarepr


def split_words(line):
    word = ''
    nested = 0
    for i, c in enumerate(line):
        if c == ' ' and nested == 0:
            if word:
                yield word
                word = ''
        else:
            word += c
            if c in '<([':
                nested += 1
            if c in '])>' and ('  '+line)[i:i+4] != ' -> ':
                nested -= 1
                assert nested >= 0
    if word:
        yield word
    assert nested == 0
