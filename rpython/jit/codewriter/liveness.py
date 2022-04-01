from rpython.jit.codewriter.flatten import Register, ListOfKind, Label, TLabel
from rpython.jit.codewriter.jitcode import SwitchDictDescr


# Some instructions require liveness information (the ones that can end up
# in generate_guard() in pyjitpl.py).  This is done by putting special
# space operations called '-live-' in the graph.  They turn into '-live-'
# operation in the ssarepr.  Then the present module expands the arguments
# of the '-live-' operations to also include all values that are alive at
# this point (written to before, and read afterwards).  You can also force
# extra variables to be alive by putting them as args of the '-live-'
# operation in the first place.

# For this to work properly, a special operation called '---' must be
# used to mark unreachable places (e.g. just after a 'goto').

# ____________________________________________________________

def compute_liveness(ssarepr):
    label2alive = {}
    while _compute_liveness_must_continue(ssarepr, label2alive):
        pass

def _compute_liveness_must_continue(ssarepr, label2alive):
    alive = set()
    must_continue = False

    def follow_label(lbl):
        alive_at_point = label2alive.get(lbl.name, ())
        alive.update(alive_at_point)

    for i in range(len(ssarepr.insns)-1, -1, -1):
        insn = ssarepr.insns[i]

        if isinstance(insn[0], Label):
            alive_at_point = label2alive.setdefault(insn[0].name, set())
            prevlength = len(alive_at_point)
            alive_at_point.update(alive)
            if prevlength != len(alive_at_point):
                must_continue = True
            continue

        if insn[0] == '-live-':
            labels = []
            for x in insn[1:]:
                if isinstance(x, Register):
                    alive.add(x)
                elif isinstance(x, TLabel):
                    follow_label(x)
                    labels.append(x)
            ssarepr.insns[i] = insn[:1] + tuple(alive) + tuple(labels)
            continue

        if insn[0] == '---':
            alive = set()
            continue

        args = insn[1:]
        #
        if len(args) >= 2 and args[-2] == '->':
            reg = args[-1]
            assert isinstance(reg, Register)
            alive.discard(reg)
            args = args[:-2]
        #
        for x in args:
            if isinstance(x, Register):
                alive.add(x)
            elif isinstance(x, ListOfKind):
                for y in x:
                    if isinstance(y, Register):
                        alive.add(y)
            elif isinstance(x, TLabel):
                follow_label(x)
            elif isinstance(x, SwitchDictDescr):
                for key, label in x._labels:
                    follow_label(label)

    return must_continue
