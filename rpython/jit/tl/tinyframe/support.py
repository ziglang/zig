
def partition(array, left, right):
    last_item = array[right]
    pivot = last_item[0]
    storeindex = left
    for i in range(left, right):
        if array[i][0] <= pivot:
            array[i], array[storeindex] = array[storeindex], array[i]
            storeindex += 1
    # Move pivot to its final place
    array[storeindex], array[right] = last_item, array[storeindex]
    return storeindex

def quicksort(array, left, right):
    # sort array[left:right+1] (i.e. bounds included)
    if right > left:
        pivotnewindex = partition(array, left, right)
        quicksort(array, left, pivotnewindex - 1)
        quicksort(array, pivotnewindex + 1, right)

def sort(array):
    quicksort(array, 0, len(array) - 1)
