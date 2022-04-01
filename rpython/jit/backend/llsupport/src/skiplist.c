#include <stdlib.h>

#define HAS_SKIPLIST
#define SKIPLIST_HEIGHT   8

typedef struct skipnode_s {
    unsigned long key;
    char *data;
    struct skipnode_s *next[SKIPLIST_HEIGHT];   /* may be smaller */
} skipnode_t;

static skipnode_t *skiplist_malloc(unsigned long datasize)
{
    char *result;
    unsigned long basesize;
    unsigned long length = 1;
    while (length < SKIPLIST_HEIGHT && (rand() & 3) == 0)
        length++;
    basesize = sizeof(skipnode_t) -
               (SKIPLIST_HEIGHT - length) * sizeof(skipnode_t *);
    result = malloc(basesize + datasize);
    if (result != NULL) {
        ((skipnode_t *)result)->data = result + basesize;
    }
    return (skipnode_t *)result;
}

static skipnode_t *skiplist_search(skipnode_t *head, unsigned long searchkey)
{
    /* Returns the skipnode with key closest (but <=) searchkey.
       Note that if there is no item with key <= searchkey in the list,
       this will return the head node. */
    unsigned long level = SKIPLIST_HEIGHT - 1;
    while (1) {
        skipnode_t *next = head->next[level];
        if (next != NULL && next->key <= searchkey) {
            head = next;
        }
        else {
            if (level == 0)
                break;
            level -= 1;
        }
    }
    return head;
}

static void skiplist_insert(skipnode_t *head, skipnode_t *new)
{
    unsigned long size0 = sizeof(skipnode_t) -
                          SKIPLIST_HEIGHT * sizeof(skipnode_t *);
    unsigned long height_of_new = (new->data - ((char *)new + size0)) /
                                  sizeof(skipnode_t *);

    unsigned long level = SKIPLIST_HEIGHT - 1;
    unsigned long searchkey = new->key;
    while (1) {
        skipnode_t *next = head->next[level];
        if (next != NULL && next->key <= searchkey) {
            head = next;
        }
        else {
            if (level < height_of_new) {
                new->next[level] = next;
                head->next[level] = new;
                if (level == 0)
                    break;
            }
            level -= 1;
        }
    }
}

static skipnode_t *skiplist_remove(skipnode_t *head, unsigned long exact_key)
{
    unsigned long level = SKIPLIST_HEIGHT - 1;
    while (1) {
        skipnode_t *next = head->next[level];
        if (next != NULL && next->key <= exact_key) {
            if (next->key == exact_key) {
                head->next[level] = next->next[level];
                if (level == 0)
                    return next;    /* successfully removed */
                level -= 1;
            }
            else
                head = next;
        }
        else {
            if (level == 0)
                return NULL;    /* 'exact_key' not found! */
            level -= 1;
        }
    }
}

static unsigned long skiplist_firstkey(skipnode_t *head)
{
    if (head->next[0] == NULL)
        return 0;
    return head->next[0]->key;
}
