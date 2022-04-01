class GreenFieldInfo(object):
    def __init__(self, cpu, jd):
        self.cpu = cpu
        self.jitdriver_sd = jd
        # XXX for now, only supports a single instance,
        # but several fields of it can be green
        seen = set()
        for name in jd.jitdriver.greens:
            if '.' in name:
                objname, fieldname = name.split('.')
                seen.add(objname)
        assert len(seen) == 1, (
            "Current limitation: you can only give one instance with green "
            "fields.  Found %r" % list(seen))
        self.red_index = jd.jitdriver.reds.index(objname)
        #
        # a list of (GTYPE, fieldname)
        self.green_fields = jd.jitdriver.ll_greenfields.values()
        self.green_field_descrs = [cpu.fielddescrof(GTYPE, fieldname)
                                   for GTYPE, fieldname in self.green_fields]

    def _freeze_(self):
        return True
