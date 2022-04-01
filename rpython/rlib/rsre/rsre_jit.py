from rpython.rlib.jit import JitDriver


class RSreJitDriver(JitDriver):
    active = True

    def __init__(self, name, debugprint, **kwds):
        JitDriver.__init__(self, name='rsre_' + name, **kwds)
        #
        def get_printable_location(*args):
            # we print based on indices in 'args'.  We first print
            # 'ctx.pattern' from the arg number debugprint[0].
            pattern = args[debugprint[0]]
            s = str(pattern.pattern)
            if len(s) > 120:
                s = s[:110] + '...'
            if len(debugprint) > 1:
                # then we print numbers from the args number
                # debugprint[1] and possibly debugprint[2]
                info = ' at %d' % (args[debugprint[1]],)
                if len(debugprint) > 2:
                    info = '%s/%d' % (info, args[debugprint[2]])
            else:
                info = ''
            return 're %s%s %s' % (name, info, s)
        #
        self.get_printable_location = get_printable_location


def install_jitdriver(name, **kwds):
    from rpython.rlib.rsre.rsre_core import AbstractMatchContext
    jitdriver = RSreJitDriver(name, **kwds)
    setattr(AbstractMatchContext, 'jitdriver_' + name, jitdriver)

def install_jitdriver_spec(name, **kwds):
    from rpython.rlib.rsre.rsre_core import BufMatchContext
    from rpython.rlib.rsre.rsre_core import StrMatchContext
    from rpython.rlib.rsre.rsre_core import UnicodeMatchContext
    from rpython.rlib.rsre.rsre_utf8 import Utf8MatchContext
    for prefix, concreteclass in [('Buf', BufMatchContext),
                                  ('Str', StrMatchContext),
                                  ('Uni', UnicodeMatchContext),
                                  ('Utf8', Utf8MatchContext)]:
        jitdriver = RSreJitDriver(prefix + name, **kwds)
        setattr(concreteclass, 'jitdriver_' + name, jitdriver)
