
from rpython.jit.backend.x86.regloc import ImmediateAssemblerLocation,\
     FrameLoc

def remap_frame_layout(assembler, src_locations, dst_locations, tmpreg):
    pending_dests = len(dst_locations)
    srccount = {}    # maps dst_locations to how many times the same
                     # location appears in src_locations
    num_moves = 0
    for dst in dst_locations:
        key = dst._getregkey()
        assert key not in srccount, "duplicate value in dst_locations!"
        srccount[key] = 0
    for i in range(len(dst_locations)):
        src = src_locations[i]
        if isinstance(src, ImmediateAssemblerLocation):
            continue
        key = src._getregkey()
        if key in srccount:
            if key == dst_locations[i]._getregkey():
                # ignore a move "x = x"
                # setting any "large enough" negative value is ok, but
                # be careful of overflows, don't use -sys.maxint
                srccount[key] = -len(dst_locations) - 1
                pending_dests -= 1
            else:
                srccount[key] += 1

    while pending_dests > 0:
        progress = False
        for i in range(len(dst_locations)):
            dst = dst_locations[i]
            key = dst._getregkey()
            if srccount[key] == 0:
                srccount[key] = -1       # means "it's done"
                pending_dests -= 1
                src = src_locations[i]
                if not isinstance(src, ImmediateAssemblerLocation):
                    key = src._getregkey()
                    if key in srccount:
                        srccount[key] -= 1
                _move(assembler, src, dst, tmpreg)
                num_moves += 1
                progress = True
        if not progress:
            # we are left with only pure disjoint cycles
            sources = {}     # maps dst_locations to src_locations
            for i in range(len(dst_locations)):
                src = src_locations[i]
                dst = dst_locations[i]
                sources[dst._getregkey()] = src
            #
            for i in range(len(dst_locations)):
                dst = dst_locations[i]
                originalkey = dst._getregkey()
                if srccount[originalkey] >= 0:
                    assembler.regalloc_push(dst)
                    num_moves += 1
                    while True:
                        key = dst._getregkey()
                        assert srccount[key] == 1
                        # ^^^ because we are in a simple cycle
                        srccount[key] = -1
                        pending_dests -= 1
                        src = sources[key]
                        if src._getregkey() == originalkey:
                            break
                        _move(assembler, src, dst, tmpreg)
                        num_moves += 1
                        dst = src
                    assembler.regalloc_pop(dst)
                    num_moves += 1
            assert pending_dests == 0
    return num_moves

def _move(assembler, src, dst, tmpreg):
    if dst.is_memory_reference() and src.is_memory_reference():
        if isinstance(src, ImmediateAssemblerLocation):
            assembler.regalloc_immedmem2mem(src, dst)
            return
        if tmpreg is None:
            assembler.regalloc_push(src)
            assembler.regalloc_pop(dst)
            return
        assembler.regalloc_mov(src, tmpreg)
        assembler.mc.forget_scratch_register()
        src = tmpreg
    assembler.regalloc_mov(src, dst)

def remap_frame_layout_mixed(assembler,
                             src_locations1, dst_locations1, tmpreg1,
                             src_locations2, dst_locations2, tmpreg2):
    # find and push the xmm stack locations from src_locations2 that
    # are going to be overwritten by dst_locations1
    from rpython.jit.backend.x86.arch import WORD
    extrapushes = []
    dst_keys = {}
    for loc in dst_locations1:
        dst_keys[loc._getregkey()] = None
    src_locations2red = []
    dst_locations2red = []
    num_moves = 0
    for i in range(len(src_locations2)):
        loc    = src_locations2[i]
        dstloc = dst_locations2[i]
        if isinstance(loc, FrameLoc):
            key = loc._getregkey()
            if (key in dst_keys or (loc.get_width() > WORD and
                                    (key + WORD) in dst_keys)):
                num_moves += 1
                assembler.regalloc_push(loc)
                extrapushes.append(dstloc)
                continue
        src_locations2red.append(loc)
        dst_locations2red.append(dstloc)
    src_locations2 = src_locations2red
    dst_locations2 = dst_locations2red
    #
    # remap the integer and pointer registers and stack locations
    num_moves += remap_frame_layout(assembler, src_locations1, dst_locations1, tmpreg1)
    #
    # remap the xmm registers and stack locations
    num_moves += remap_frame_layout(assembler, src_locations2, dst_locations2, tmpreg2)
    #
    # finally, pop the extra xmm stack locations
    while len(extrapushes) > 0:
        loc = extrapushes.pop()
        assembler.regalloc_pop(loc)
        num_moves += 1
    return num_moves
