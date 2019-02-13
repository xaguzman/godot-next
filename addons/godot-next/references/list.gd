# list.gd
# List
# author: willnationsdev
# brief_description: A List class
#
extends Reference
class_name List

##### CLASSES #####

class ListNode:
    extends Object

    ##### PROPERTIES #####

    var data
    var next : ListNode = null
    var previous : ListNode = null

    ##### NOTIFICATIONS #####

    func _init(p_data, p_next : ListNode = null, p_previous : ListNode = null):
        data = p_data
        next = p_next
        previous = p_previous

##### SIGNALS #####

##### CONSTANTS #####

##### PROPERTIES #####

# public-facing data array. Always empty internally.
var data : Array = [] setget set_data, get_data

# for iteration
var _curr

var _head : ListNode = null
var _tail : ListNode = null
var _size := 0

##### NOTIFICATIONS #####

func _init(p_data = null) -> void:
    match typeof(p_data):
        TYPE_OBJECT:
            # copy constructor
            assert p_data is get_script()
            self.data = p_data.data
        TYPE_ARRAY:
            # conversion constructor
            self.data = p_data
        TYPE_NIL:
            # default constructor
            pass
        _:
            # invalid input
            assert false

##### OVERRIDES #####

func _iter_init(arg):
    _curr = _head
    return _is_done()

func _iter_next(arg):
    return _do_step()

func _iter_get(arg):
    return _curr.data

##### VIRTUAL METHODS #####

##### PUBLIC METHODS #####

func get(p_pos : int):
    return _at(p_pos).data

func set(p_pos : int, p_value) -> void:
    _at(p_pos).data = p_value

func push_back(p_value):
    var node = ListNode.new(p_value)

    if _size:
        _tail.next = node
        node.previous = _tail
        _tail = node

    _size += 1

func insert_before(p_pos : int, p_value) -> void:
    var new := ListNode.new()
    new.data = p_value

    if not p_pos and not _size:
        push_back(p_value)
        return

    var current := _at(p_pos)

    new.previous = current.previous
    new.next = current
    current.previous = new

    _size += 1

func insert_after(p_pos : int, p_value) -> void:
    var new := ListNode.new()
    new.data = p_value

    var current := _at(p_pos)

    new.previous = current
    new.next = current.next
    current.next = new

    _size += 1

func find(p_value) -> int:
    return _find(p_value).index

func has(p_value) -> bool:
    return _find(p_value).current != null

func erase(p_value) -> bool:
    var find_data = _find(p_value)
    if find_data.node:
        _delete(find_data.node)
        return true
    else:
        return false

func erase_at(p_pos : int) -> bool
    if p_pos < _size:
        return erase(_at(p_pos))
    else:
        return false

func size() -> int:
    return _size

func clear() -> void:
    var node = _tail
    _tail = null
    while node != _head:
        var tmp = node
        node = node.previous
        tmp.free()

    _head = null
    _size = 0

# func(value, index)
func map_in_place(p_funcref : FuncRef = null) -> void:
    assert p_funcref
    var node = _head
    for i in range(_size):
        node.data = p_funcref.call_func(node.data, i)
        node = node.next

# func(value, index)
func map(p_funcref : FuncRef = null) -> List:
    var list = get_script().new()
    list.foreach(p_funcref)
    return list

##### PRIVATE METHODS #####

func _at(p_pos : int) -> ListNode:
    assert p_pos < _size
    var current := _head
    for i in range(p_pos):
        current = current.next
    return current

func _find(p_value) -> Dictionary:
    var ret := 0

    var current = _head
    while current.next and current.data != p_value:
        current = current.next
        ret += 1
    
    return {
        "node": current,
        "index": ret
    }

func _delete(p_node : ListNode):
    assert p_node

    if p_node.previous:
        p_node.previous.next = p_node.next
    if p_node.next:
        p_node.next.previous = p_node.previous

    p_node.next = null
    p_node.previous = null
    p_node.free()

# for iteration
func _is_done():
    return _curr == _tail or _head == _tail

# for iteration
func _do_step():
    _curr = _curr.next
    return _is_done()

##### CONNECTIONS #####

##### SETTERS AND GETTERS #####

func set_data(p_value : Array) -> void:
    clear()
    for element in p_value:
        push_back(element)

func get_data() -> Array:
    var ret = []
    var current = _head
    while current != _tail:
        ret.append(current.data)
        current = current.next
    return ret