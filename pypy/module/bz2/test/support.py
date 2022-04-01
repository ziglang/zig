class CheckAllocation:
    def teardown_method(self, fun):
        from rpython.rtyper.lltypesystem import ll2ctypes
        import gc
        tries = 20
        # remove the GC strings from ll2ctypes
        for key, value in ll2ctypes.ALLOCATED.items():
            if value._TYPE._gckind == 'gc':
                del ll2ctypes.ALLOCATED[key]
            else:
                try: 
                    tag = value._TYPE.tag
                except AttributeError:
                    pass
                else:
                    if 'RPyOpaque_ThreadLock' in tag:
                        del ll2ctypes.ALLOCATED[key]
        #
        while tries and ll2ctypes.ALLOCATED:
            gc.collect() # to make sure we disallocate buffers
            self.space.getexecutioncontext()._run_finalizers_now()
            tries -= 1
        if ll2ctypes.ALLOCATED:
            import pdb;pdb.set_trace()
        assert not ll2ctypes.ALLOCATED
