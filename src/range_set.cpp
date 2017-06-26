#include "range_set.hpp"

AstNode *rangeset_add_range(RangeSet *rs, BigInt *first, BigInt *last, AstNode *source_node) {
    for (size_t i = 0; i < rs->src_range_list.length; i += 1) {
        RangeWithSrc *range_with_src = &rs->src_range_list.at(i);
        Range *range = &range_with_src->range;
        if ((bigint_cmp(first, &range->first) != CmpLT && bigint_cmp(first, &range->last) != CmpGT) ||
            (bigint_cmp(last, &range->first) != CmpLT && bigint_cmp(last, &range->last) != CmpGT))
        {
            return range_with_src->source_node;
        }
    }
    rs->src_range_list.append({{*first, *last}, source_node});

    return nullptr;

}

static bool add_range(ZigList<Range> *list, Range *new_range, BigInt *one) {
    for (size_t i = 0; i < list->length; i += 1) {
        Range *range = &list->at(i);

        BigInt first_minus_one;
        bigint_sub(&first_minus_one, &range->first, one);

        if (bigint_cmp(&new_range->last, &first_minus_one) == CmpEQ) {
            range->first = new_range->first;
            return true;
        }

        BigInt last_plus_one;
        bigint_add(&last_plus_one, &range->last, one);

        if (bigint_cmp(&new_range->first, &last_plus_one) == CmpEQ) {
            range->last = new_range->last;
            return true;
        }
    }
    list->append({new_range->first, new_range->last});
    return false;
}

bool rangeset_spans(RangeSet *rs, BigInt *first, BigInt *last) {
    ZigList<Range> cur_list_value = {0};
    ZigList<Range> other_list_value = {0};
    ZigList<Range> *cur_list = &cur_list_value;
    ZigList<Range> *other_list = &other_list_value;

    for (size_t i = 0; i < rs->src_range_list.length; i += 1) {
        RangeWithSrc *range_with_src = &rs->src_range_list.at(i);
        Range *range = &range_with_src->range;
        cur_list->append({range->first, range->last});
    }

    BigInt one;
    bigint_init_unsigned(&one, 1);

    bool changes_made = true;
    while (changes_made) {
        changes_made = false;
        for (size_t cur_i = 0; cur_i < cur_list->length; cur_i += 1) {
            Range *range = &cur_list->at(cur_i);
            changes_made = add_range(other_list, range, &one) || changes_made;
        }
        ZigList<Range> *tmp = cur_list;
        cur_list = other_list;
        other_list = tmp;
        other_list->resize(0);
    }

    if (cur_list->length != 1)
        return false;
    Range *range = &cur_list->at(0);
    if (bigint_cmp(&range->first, first) != CmpEQ)
        return false;
    if (bigint_cmp(&range->last, last) != CmpEQ)
        return false;
    return true;
}
