#include "range_set.hpp"

AstNode *rangeset_add_range(RangeSet *rs, BigInt *first, BigInt *last, AstNode *source_node) {
    for (size_t i = 0; i < rs->src_range_list.length; i += 1) {
        RangeWithSrc *range_with_src = &rs->src_range_list.at(i);
        Range *range = &range_with_src->range;
        if ((bigint_cmp(first, &range->first) == CmpLT && bigint_cmp(last, &range->first) == CmpLT) ||
            (bigint_cmp(first, &range->last) == CmpGT && bigint_cmp(last, &range->last) == CmpGT))
        {
            // first...last is completely before/after `range`
        }
        else
        {
            return range_with_src->source_node;
        }
    }
    rs->src_range_list.append({{*first, *last}, source_node});

    return nullptr;

}

static int compare_rangeset(const void *a, const void *b) {
    const Range *r1 = &static_cast<const RangeWithSrc*>(a)->range;
    const Range *r2 = &static_cast<const RangeWithSrc*>(b)->range;
    // Assume no two ranges overlap
    switch (bigint_cmp(&r1->first, &r2->first)) {
        case CmpLT: return -1;
        case CmpGT: return  1;
        case CmpEQ: return  0;
    }
    zig_unreachable();
}

void rangeset_sort(RangeSet *rs) {
    if (rs->src_range_list.length > 1) {
        qsort(rs->src_range_list.items, rs->src_range_list.length,
              sizeof(RangeWithSrc), compare_rangeset);
    }
}

bool rangeset_spans(RangeSet *rs, BigInt *first, BigInt *last) {
    if (rs->src_range_list.length == 0)
        return false;

    rangeset_sort(rs);

    const Range *first_range = &rs->src_range_list.at(0).range;
    if (bigint_cmp(&first_range->first, first) != CmpEQ)
        return false;

    const Range *last_range = &rs->src_range_list.last().range;
    if (bigint_cmp(&last_range->last, last) != CmpEQ)
        return false;

    BigInt one;
    bigint_init_unsigned(&one, 1);

    // Make sure there are no holes in the first...last range
    for (size_t i = 1; i < rs->src_range_list.length; i++) {
        const Range *range = &rs->src_range_list.at(i).range;
        const Range *prev_range = &rs->src_range_list.at(i - 1).range;

        assert(bigint_cmp(&prev_range->last, &range->first) == CmpLT);

        BigInt last_plus_one;
        bigint_add(&last_plus_one, &prev_range->last, &one);

        if (bigint_cmp(&last_plus_one, &range->first) != CmpEQ)
            return false;
    }

    return true;
}
