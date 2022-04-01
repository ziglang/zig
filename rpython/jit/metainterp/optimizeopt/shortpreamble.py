
from collections import OrderedDict
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.metainterp.resoperation import ResOperation, OpHelpers,\
     rop, AbstractResOp, AbstractInputArg
from rpython.jit.metainterp.history import Const, make_hashable_int,\
     TreeLoop
from rpython.jit.metainterp.optimizeopt import info

class PreambleOp(AbstractResOp):
    """ An operations that's only found in preamble and not
    in the list of constructed operations. When encountered (can be found
    either in pure ops or heap ops), it must be put in inputargs as well
    as short preamble (together with corresponding guards). Extra_ops is
    for extra things to be found in the label, for now only inputargs
    of the preamble that have to be propagated further.

    See force_op_from_preamble for details how the extra things are put.
    """
    op = None
    
    def __init__(self, op, preamble_op, invented_name):
        self.op = op
        self.preamble_op = preamble_op
        self.invented_name = invented_name

    def numargs(self):
        if self.op is None:
            return 0
        return self.op.numargs()

    def getarglist(self):
        if self.op is None:
            return []
        return self.op.getarglist()

    def getarg(self, i):
        if self.op is None:
            return None
        return self.op.getarg(i)

    def getdescr(self):
        if self.op is None:
            return None
        return self.op.getdescr()

    def __repr__(self):
        return "Preamble(%r)" % (self.op,)


class AbstractShortOp(object):
    """ An operation that is potentially produced by the short preamble
    """
    pass

class HeapOp(AbstractShortOp):
    def __init__(self, res, getfield_op):
        self.res = res
        self.getfield_op = getfield_op

    def produce_op(self, opt, preamble_op, exported_infos, invented_name):
        optheap = opt.optimizer.optheap
        if optheap is None:
            return
        g = preamble_op.copy_and_change(preamble_op.getopnum(),
                                        args=self.getfield_op.getarglist())
        if g.getarg(0) in exported_infos:
            opt.optimizer.setinfo_from_preamble(g.getarg(0),
                                                exported_infos[g.getarg(0)],
                                                exported_infos)
        opinfo = opt.optimizer.ensure_ptr_info_arg0(g)
        pop = PreambleOp(self.res, preamble_op, invented_name)
        assert not opinfo.is_virtual()
        descr = self.getfield_op.getdescr()
        if rop.is_getfield(g.opnum):
            cf = optheap.field_cache(descr)
            opinfo.setfield(preamble_op.getdescr(), g.getarg(0), pop,
                            optheap, cf)
        else:
            index = g.getarg(1).getint()
            assert index >= 0
            cf = optheap.arrayitem_cache(descr, index)
            opinfo.setitem(self.getfield_op.getdescr(), index, g.getarg(0),
                           pop, optheap, cf)

    def repr(self, memo):
        return "HeapOp(%s, %s)" % (self.res.repr(memo),
                                   self.getfield_op.repr(memo))

    def add_op_to_short(self, sb):
        sop = self.getfield_op
        preamble_arg = sb.produce_arg(sop.getarg(0))
        if preamble_arg is None:
            return None
        if rop.is_getfield(sop.opnum):
            preamble_op = ResOperation(sop.getopnum(), [preamble_arg],
                                       descr=sop.getdescr())
        else:
            preamble_op = ResOperation(sop.getopnum(), [preamble_arg,
                                                        sop.getarg(1)],
                                       descr=sop.getdescr())
        return ProducedShortOp(self, preamble_op)

    def __repr__(self):
        return "HeapOp(%r)" % (self.res,)

class PureOp(AbstractShortOp):
    def __init__(self, res):
        self.res = res

    def produce_op(self, opt, preamble_op, exported_infos, invented_name):
        optpure = opt.optimizer.optpure
        if optpure is None:
            return
        if invented_name:
            op = self.orig_op.copy_and_change(self.orig_op.getopnum())
            op.set_forwarded(self.res)
        else:
            op = self.res
        if rop.is_call(preamble_op.opnum):
            optpure.extra_call_pure.append(PreambleOp(op, preamble_op,
                                                      invented_name))
        else:
            opt.pure(op.getopnum(), PreambleOp(op, preamble_op,
                                               invented_name))

    def add_op_to_short(self, sb):
        op = self.res
        arglist = []
        for arg in op.getarglist():
            newarg = sb.produce_arg(arg)
            if newarg is None:
                return None
            arglist.append(newarg)
        if rop.is_call(op.opnum):
            opnum = OpHelpers.call_pure_for_descr(op.getdescr())
        else:
            opnum = op.getopnum()
        return ProducedShortOp(self, op.copy_and_change(opnum, args=arglist))

    def repr(self, memo):
        return "PureOp(%s)" % (self.res.repr(memo),)

    def __repr__(self):
        return "PureOp(%r)" % (self.res,)

class LoopInvariantOp(AbstractShortOp):
    def __init__(self, res):
        self.res = res

    def produce_op(self, opt, preamble_op, exported_infos, invented_name):
        optrewrite = opt.optimizer.optrewrite
        if optrewrite is None:
            return
        op = self.res
        key = make_hashable_int(op.getarg(0).getint())
        optrewrite.loop_invariant_results[key] = PreambleOp(op, preamble_op,
                                                            invented_name)

    def add_op_to_short(self, sb):
        op = self.res
        arglist = []
        for arg in op.getarglist():
            newarg = sb.produce_arg(arg)
            if newarg is None:
                return None
            arglist.append(newarg)
        opnum = OpHelpers.call_loopinvariant_for_descr(op.getdescr())
        return ProducedShortOp(self, op.copy_and_change(opnum, args=arglist))

    def repr(self, memo):
        return "LoopInvariantOp(%s)" % (self.res.repr(memo),)

    def __repr__(self):
        return "LoopInvariantOp(%r)" % (self.res,)

class CompoundOp(AbstractShortOp):
    def __init__(self, res, one, two):
        self.res = res
        self.one = one
        self.two = two

    def flatten(self, sb, l):
        pop = self.one.add_op_to_short(sb)
        if pop is not None:
            l.append(pop)
        two = self.two
        if isinstance(two, CompoundOp):
            two.flatten(sb, l)
        else:
            pop = two.add_op_to_short(sb)
            if pop is not None:
                l.append(pop)
        return l

    def repr(self, memo):
        return "CompoundOp(%s, %s, %s)" % (self.res.repr(memo),
                                           self.one.repr(memo),
                                           self.two.repr(memo))

class AbstractProducedShortOp(object):
    pass

class ProducedShortOp(AbstractProducedShortOp):
    invented_name = False
    
    def __init__(self, short_op, preamble_op):
        self.short_op = short_op
        self.preamble_op = preamble_op

    def produce_op(self, opt, exported_infos):
        self.short_op.produce_op(opt, self.preamble_op, exported_infos,
                                 invented_name=self.invented_name)

    def repr(self, memo):
        return self.short_op.repr(memo)

    def __repr__(self):
        return "%r -> %r" % (self.short_op, self.preamble_op)

dummy_short_op = ProducedShortOp(None, None)


class ShortInputArg(AbstractShortOp):
    def __init__(self, res, preamble_op):
        self.res = res
        self.preamble_op = preamble_op

    def add_op_to_short(self, sb):
        return ProducedShortOp(self, self.preamble_op)

    def produce_op(self, opt, preamble_op, exported_infos, invented_name):
        assert not invented_name

    def repr(self, memo):
        return "INP(%s)" % (self.res.repr(memo),)

    def __repr__(self):
        return "INP(%r -> %r)" % (self.res, self.preamble_op)

class ShortBoxes(object):
    """ This is a container used for creating all the exported short
    boxes from the preamble
    """
    def create_short_boxes(self, optimizer, inputargs, label_args):
        # all the potential operations that can be produced, subclasses
        # of AbstractShortOp
        self.potential_ops = OrderedDict()
        self.produced_short_boxes = {}
        # a way to produce const boxes, e.g. setfield_gc(p0, Const).
        # We need to remember those, but they don't produce any new boxes
        self.const_short_boxes = []
        self.short_inputargs = []
        for i in range(len(label_args)):
            box = label_args[i]
            renamed = OpHelpers.inputarg_from_tp(box.type)
            self.short_inputargs.append(renamed)
            self.potential_ops[box] = ShortInputArg(box, renamed)

        optimizer.produce_potential_short_preamble_ops(self)

        short_boxes = []
        self.boxes_in_production = {}

        for shortop in self.potential_ops.values():
            self.add_op_to_short(shortop)
        #
        for op, produced_op in self.produced_short_boxes.iteritems():
            short_boxes.append(produced_op)

        for short_op in self.const_short_boxes:
            getfield_op = short_op.getfield_op
            args = getfield_op.getarglist()
            preamble_arg = self.produce_arg(args[0])
            if preamble_arg is not None:
                preamble_op = getfield_op.copy_and_change(
                      getfield_op.getopnum(), [preamble_arg] + args[1:])
                produced_op = ProducedShortOp(short_op, preamble_op)
                short_boxes.append(produced_op)
        return short_boxes

    def produce_arg(self, op):
        if op in self.produced_short_boxes:
            return self.produced_short_boxes[op].preamble_op
        elif op in self.boxes_in_production:
            return None
        elif isinstance(op, Const):
            return op
        elif op in self.potential_ops:
            r = self.add_op_to_short(self.potential_ops[op])
            if r is None:
                return None
            return r.preamble_op
        else:
            return None

    def _pick_op_index(self, lst, pick_other=True):
        index = -1
        for i, item in enumerate(lst):
            if (not isinstance(item.short_op, HeapOp) and
                (pick_other or isinstance(item.short_op, ShortInputArg))):
                if index != -1:
                    assert pick_other
                    return self._pick_op_index(lst, False)
                index = i
        if index == -1:
            index = 0
        return index

    def add_op_to_short(self, shortop):
        if shortop.res in self.produced_short_boxes:
            return # already added due to dependencies
        self.boxes_in_production[shortop.res] = None
        try:
            if isinstance(shortop, CompoundOp):
                lst = shortop.flatten(self, [])
                if len(lst) == 0:
                    return None
                else:
                    index = self._pick_op_index(lst)
                    pop = lst[index]
                    for i in range(len(lst)):
                        if i == index:
                            continue
                        opnum = OpHelpers.same_as_for_type(shortop.res.type)
                        new_name = ResOperation(opnum, [shortop.res])
                        assert lst[i].short_op is not pop.short_op
                        orig_op = lst[i].short_op.res
                        lst[i].short_op.res = new_name
                        lst[i].short_op.orig_op = orig_op
                        lst[i].invented_name = True
                        self.produced_short_boxes[new_name] = lst[i]
            else:
                pop = shortop.add_op_to_short(self)
            if pop is None:
                return
            self.produced_short_boxes[shortop.res] = pop
        finally:
            del self.boxes_in_production[shortop.res]
        return pop

    def create_short_inputargs(self, label_args):
        return self.short_inputargs
        short_inpargs = []
        for i in range(len(label_args)):
            inparg = self.produced_short_boxes.get(label_args[i], None)
            if inparg is None:
                renamed = OpHelpers.inputarg_from_tp(label_args[i].type)
                short_inpargs.append(renamed)
            else:
                assert isinstance(inparg.short_op, ShortInputArg)
                short_inpargs.append(inparg.preamble_op)
        return short_inpargs

    def add_potential_op(self, op, pop):
        prev_op = self.potential_ops.get(op, None)
        if prev_op is None:
            self.potential_ops[op] = pop
            return
        self.potential_ops[op] = CompoundOp(op, pop, prev_op)

    def add_pure_op(self, op):
        self.add_potential_op(op, PureOp(op))

    def add_loopinvariant_op(self, op):
        self.add_potential_op(op, LoopInvariantOp(op))

    def add_heap_op(self, op, getfield_op):
        # or an inputarg
        if isinstance(op, Const):
            self.const_short_boxes.append(HeapOp(op, getfield_op))
            return # we should not be called from anywhere
        self.add_potential_op(op, HeapOp(op, getfield_op))

class EmptyInfo(info.AbstractInfo):
    pass

empty_info = EmptyInfo()

class AbstractShortPreambleBuilder(object):
    def use_box(self, box, preamble_op, optimizer=None):
        for arg in preamble_op.getarglist():
            if isinstance(arg, Const):
                continue
            if isinstance(arg, AbstractInputArg):
                info = arg.get_forwarded()
                if info is not None and info is not empty_info:
                    info.make_guards(arg, self.short, optimizer)
            elif arg.get_forwarded() is None:
                pass
            else:
                self.short.append(arg)
                info = arg.get_forwarded()
                if info is not empty_info:
                    info.make_guards(arg, self.short, optimizer)
                arg.set_forwarded(None)
        self.short.append(preamble_op)
        if preamble_op.is_ovf():
            self.short.append(ResOperation(rop.GUARD_NO_OVERFLOW, []))
        info = preamble_op.get_forwarded()
        preamble_op.set_forwarded(None)
        if optimizer is not None:
            optimizer.setinfo_from_preamble(box, info, None)
        if info is not empty_info:
            info.make_guards(preamble_op, self.short, optimizer)
        return preamble_op

class ShortPreambleBuilder(AbstractShortPreambleBuilder):
    """ ShortPreambleBuilder is used during optimizing of the peeled loop,
    starting from short_boxes exported from the preamble. It will build
    the short preamble and necessary extra label arguments
    """
    def __init__(self, label_args, short_boxes, short_inputargs,
                 exported_infos, optimizer=None):
        for produced_op in short_boxes:
            op = produced_op.short_op.res
            preamble_op = produced_op.preamble_op
            if isinstance(op, Const):
                info = optimizer.getinfo(op)
            else:
                info = exported_infos.get(op, None)
                if info is None:
                    info = empty_info
            preamble_op.set_forwarded(info)
        self.short = []
        self.used_boxes = []
        self.short_preamble_jump = []
        self.extra_same_as = []
        self.short_inputargs = short_inputargs

    def add_preamble_op(self, preamble_op):
        """ Notice that we're actually using the preamble_op, add it to
        label and jump
        """
        op = preamble_op.op.get_box_replacement()
        if preamble_op.invented_name:
            self.extra_same_as.append(op)
        self.used_boxes.append(op)
        self.short_preamble_jump.append(preamble_op.preamble_op)

    def build_short_preamble(self):
        label_op = ResOperation(rop.LABEL, self.short_inputargs[:])
        jump_op = ResOperation(rop.JUMP, self.short_preamble_jump[:])
        if not we_are_translated():
            TreeLoop.check_consistency_of(self.short_inputargs,
                                self.short + [jump_op], check_descr=False)
        return [label_op] + self.short + [jump_op]

class ExtendedShortPreambleBuilder(AbstractShortPreambleBuilder):
    """ A special preamble builder that is called while we're building
    short preamble
    """
    def __init__(self, target_token, sb):
        self.sb = sb
        self.extra_same_as = self.sb.extra_same_as
        self.target_token = target_token

    def setup(self, jump_args, short, label_args):
        self.jump_args = jump_args
        self.short = short
        self.label_args = label_args

    def add_preamble_op(self, preamble_op):
        """ Notice that we're actually using the preamble_op, add it to
        label and jump
        """
        op = preamble_op.op.get_box_replacement()
        if preamble_op.invented_name:
            self.extra_same_as.append(op)
        self.label_args.append(op)
        self.jump_args.append(preamble_op.preamble_op)

    def use_box(self, box, preamble_op, optimizer=None):
        jump_op = self.short.pop()
        AbstractShortPreambleBuilder.use_box(self, box, preamble_op, optimizer)
        self.short.append(jump_op)
