from rpython.jit.metainterp import resoperation

class Renamer(object):
    def __init__(self):
        self.rename_map = {}

    def rename_box(self, box):
        return self.rename_map.get(box, box)

    def start_renaming(self, var, tovar):
        # edge case, it happens that in e.g. jump arguments
        # constants are used to jump to a label, for unrolling
        # we should never apply this renaming, because it is not supported to
        # have a constant in failargs (see compute_vars_longevity in
        # llsupport/regalloc.py)
        if tovar.is_constant():
            return
        self.rename_map[var] = tovar

    def rename(self, op):
        for i, arg in enumerate(op.getarglist()):
            arg = self.rename_map.get(arg, arg)
            op.setarg(i, arg)

        if op.is_guard():
            assert isinstance(op, resoperation.GuardResOp)
            # TODO op.rd_snapshot = self.rename_rd_snapshot(op.rd_snapshot, clone=True)
            failargs = self.rename_failargs(op, clone=True)
            op.setfailargs(failargs)

        return True

    def rename_failargs(self, guard, clone=False):
        if guard.getfailargs() is not None:
            if clone:
                args = guard.getfailargs()[:]
            else:
                args = guard.getfailargs()
            for i,arg in enumerate(args):
                args[i] = self.rename_map.get(arg,arg)
            return args
        return None

    def rename_rd_snapshot(self, snapshot, clone=False):
        # snapshots are nested like the MIFrames
        if snapshot is None:
            return None
        if clone:
            boxes = snapshot.boxes[:]
        else:
            boxes = snapshot.boxes
        for i,box in enumerate(boxes):
            value = self.rename_map.get(box,box)
            boxes[i] = value
        #
        rec_snap = self.rename_rd_snapshot(snapshot.prev, clone)
        return Snapshot(rec_snap, boxes)
