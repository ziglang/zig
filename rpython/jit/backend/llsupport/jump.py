def remap_frame_layout(assembler, src_locations, dst_locations, tmpreg):
    pending_dests = len(dst_locations)
    srccount = {}    # maps dst_locations to how many times the same
                     # location appears in src_locations
    for dst in dst_locations:
        key = dst.as_key()
        assert key not in srccount, "duplicate value in dst_locations!"
        srccount[key] = 0
    for i in range(len(dst_locations)):
        src = src_locations[i]
        if src.is_imm():
            continue
        key = src.as_key()
        if key in srccount:
            if key == dst_locations[i].as_key():
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
            key = dst.as_key()
            if srccount[key] == 0:
                srccount[key] = -1       # means "it's done"
                pending_dests -= 1
                src = src_locations[i]
                if not src.is_imm():
                    key = src.as_key()
                    if key in srccount:
                        srccount[key] -= 1
                _move(assembler, src, dst, tmpreg)
                progress = True
        if not progress:
            # we are left with only pure disjoint cycles
            sources = {}     # maps dst_locations to src_locations
            for i in range(len(dst_locations)):
                src = src_locations[i]
                dst = dst_locations[i]
                sources[dst.as_key()] = src
            #
            for i in range(len(dst_locations)):
                dst = dst_locations[i]
                originalkey = dst.as_key()
                if srccount[originalkey] >= 0:
                    assembler.regalloc_push(dst, 0)
                    while True:
                        key = dst.as_key()
                        assert srccount[key] == 1
                        # ^^^ because we are in a simple cycle
                        srccount[key] = -1
                        pending_dests -= 1
                        src = sources[key]
                        if src.as_key() == originalkey:
                            break
                        _move(assembler, src, dst, tmpreg)
                        dst = src
                    assembler.regalloc_pop(dst, 0)
            assert pending_dests == 0

def _move(assembler, src, dst, tmpreg):
    # some assembler cannot handle memory to memory moves without
    # a tmp register, thus prepare src according to the ISA capabilities
    src = assembler.regalloc_prepare_move(src, dst, tmpreg)
    assembler.regalloc_mov(src, dst)

def remap_frame_layout_mixed(assembler,
                             src_locations1, dst_locations1, tmpreg1,
                             src_locations2, dst_locations2, tmpreg2, WORD):
    # find and push the fp stack locations from src_locations2 that
    # are going to be overwritten by dst_locations1
    extrapushes = []
    dst_keys = {}
    for loc in dst_locations1:
        dst_keys[loc.as_key()] = None
    src_locations2red = []
    dst_locations2red = []
    for i in range(len(src_locations2)):
        loc    = src_locations2[i]
        dstloc = dst_locations2[i]
        if loc.is_stack():
            key = loc.as_key()
            if (key in dst_keys or (loc.width > WORD and
                                    (key + 1) in dst_keys)):
                assembler.regalloc_push(loc, len(extrapushes))
                extrapushes.append(dstloc)
                continue
        src_locations2red.append(loc)
        dst_locations2red.append(dstloc)
    src_locations2 = src_locations2red
    dst_locations2 = dst_locations2red
    #
    # remap the integer and pointer registers and stack locations
    remap_frame_layout(assembler, src_locations1, dst_locations1, tmpreg1)
    #
    # remap the fp registers and stack locations
    remap_frame_layout(assembler, src_locations2, dst_locations2, tmpreg2)
    #
    # finally, pop the extra fp stack locations
    while len(extrapushes) > 0:
        loc = extrapushes.pop()
        assembler.regalloc_pop(loc, len(extrapushes))
