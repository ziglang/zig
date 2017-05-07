#include "range_set.hpp"

AstNode *rangeset_add_range(RangeSet *rs, BigNum *first, BigNum *last, AstNode *source_node) {
    for (size_t i = 0; i < rs->src_range_list.length; i += 1) {
        RangeWithSrc *range_with_src = &rs->src_range_list.at(i);
        Range *range = &range_with_src->range;
        if ((bignum_cmp_gte(first, &range->first) && bignum_cmp_lte(first, &range->last)) ||
            (bignum_cmp_gte(last, &range->first) && bignum_cmp_lte(last, &range->last)))
        {
            return range_with_src->source_node;
        }
    }
    rs->src_range_list.append({{*first, *last}, source_node});

    return nullptr;

}

static bool add_range(ZigList<Range> *list, Range *new_range, BigNum *one) {
    for (size_t i = 0; i < list->length; i += 1) {
        Range *range = &list->at(i);

        BigNum first_minus_one;
        if (bignum_sub(&first_minus_one, &range->first, one))
            zig_unreachable();

        if (bignum_cmp_eq(&new_range->last, &first_minus_one)) {
            range->first = new_range->first;
            return true;
        }

        BigNum last_plus_one;
        if (bignum_add(&last_plus_one, &range->last, one))
            zig_unreachable();

        if (bignum_cmp_eq(&new_range->first, &last_plus_one)) {
            range->last = new_range->last;
            return true;
        }
    }
    list->append({new_range->first, new_range->last});
    return false;
}

bool rangeset_spans(RangeSet *rs, BigNum *first, BigNum *last) {
    ZigList<Range> cur_list_value = {0};
    ZigList<Range> other_list_value = {0};
    ZigList<Range> *cur_list = &cur_list_value;
    ZigList<Range> *other_list = &other_list_value;

    for (size_t i = 0; i < rs->src_range_list.length; i += 1) {
        RangeWithSrc *range_with_src = &rs->src_range_list.at(i);
        Range *range = &range_with_src->range;
        cur_list->append({range->first, range->last});
    }

    BigNum one;
    bignum_init_unsigned(&one, 1);

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
    if (bignum_cmp_neq(&range->first, first))
        return false;
    if (bignum_cmp_neq(&range->last, last))
        return false;
    return true;
}
