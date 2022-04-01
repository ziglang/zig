
from rpython.jit.metainterp.resoperation import rop
from rpython.jit.metainterp.optimizeopt.optimizer import BasicLoopInfo
from rpython.jit.metainterp.compile import (send_bridge_to_backend, record_loop_or_bridge,
        ResumeGuardDescr, create_empty_loop)
from rpython.jit.metainterp.history import AbstractFailDescr


class LoopVersionInfo(BasicLoopInfo):
    def __init__(self, info):
        assert isinstance(info, BasicLoopInfo)
        #self.target_token = info.target_token
        self.label_op = info.label_op
        self.extra_same_as = info.extra_same_as
        self.quasi_immutable_deps = info.quasi_immutable_deps
        self.descrs = []
        self.leads_to = {}
        self.insert_index = -1
        self.versions = []

    def mark(self):
        self.insert_index = len(self.descrs)

    def clear(self):
        self.insert_index = -1

    def track(self, op, descr, version):
        assert descr.loop_version()
        i = self.insert_index
        if i >= 0:
            assert i >= 0
            self.descrs.insert(i, descr)
        else:
            self.descrs.append(descr)
        assert descr not in self.leads_to
        self.leads_to[descr] = version

    def remove(self, descr):
        if descr in self.leads_to:
            del self.leads_to[descr]
        else:
            assert 0, "could not remove %s" % descr

    def get(self, descr):
        return self.leads_to.get(descr, None)

    def snapshot(self, loop):
        newloop = loop.clone()
        version = LoopVersion(newloop)
        version.setup_once(self)
        self.versions.append(version)
        # register the faildescr for later stitching
        return version

    def post_loop_compilation(self, loop, jitdriver_sd, metainterp, jitcell_token):
        """ if a loop version is created for a guard instruction (e.g. they are known
            to fail frequently) then a version can be created that is immediatly compiled
            and stitched to the guard.
        """
        metainterp_sd = metainterp.staticdata
        cpu = metainterp_sd.cpu
        if not self.versions:
            return
        # compile each version once for the first fail descr!
        # this assumes that the root trace (= loop) is already compiled
        compiled = {}
        for descr in self.descrs:
            version = self.get(descr)
            if not version:
                # the guard might have been removed from the trace
                continue
            if version not in compiled:
                assert isinstance(descr, AbstractFailDescr)
                vl = version.create_backend_loop(metainterp, jitcell_token)
                asminfo = send_bridge_to_backend(jitdriver_sd, metainterp_sd,
                                                 descr, vl.inputargs,
                                                 vl.operations, jitcell_token,
                                                 metainterp.box_names_memo)
                record_loop_or_bridge(metainterp_sd, vl)
                assert asminfo is not None
                compiled[version] = (asminfo, descr, version, jitcell_token)
            else:
                param = compiled[version]
                cpu.stitch_bridge(descr, param)

        self.versions = [] # dismiss versions


class LoopVersion(object):
    """ A special version of a trace loop. Use loop.snaphost() to
        create one instance and attach it to a guard descr.
        If not attached to a descriptor, it will not be compiled.
    """
    _attrs_ = ('label', 'loop', 'inputargs')

    def __init__(self, loop):
        self.loop = loop
        self.inputargs = loop.label.getarglist()

    def setup_once(self, info):
        for op in self.loop.operations:
            if not op.is_guard():
                continue
            olddescr = op.getdescr()
            if not olddescr:
                continue
            descr = olddescr.clone()
            op.setdescr(descr)
            if descr.loop_version():
                toversion = info.leads_to.get(olddescr,None)
                if toversion:
                    info.track(op, descr, toversion)
                else:
                    assert 0, "olddescr must be found"

    def create_backend_loop(self, metainterp, jitcell_token):
        vl = create_empty_loop(metainterp)
        vl.operations = self.loop.finaloplist(jitcell_token,True,True)
        vl.inputargs = self.loop.label.getarglist_copy()
        vl.original_jitcell_token = jitcell_token
        return vl

