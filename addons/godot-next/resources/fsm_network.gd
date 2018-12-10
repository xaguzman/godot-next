# FSMNetwork
# author: willnationsdev
# brief_description: A definition of data to be associated with a FSM.
# API details:
# - Generates state dropdowns from the FSMNetwork data.
# - Provides debug options for what to do in case of an error.
# - Automatically modifies state properties in response to changes in the `network` value.
# Note:
# - The states/transitions exports will need to be updated for 3.2 when type hints make a return.

tool
extends Resource
class_name FSMNetwork

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

enum Error {
    ERR_BAD_STATE = 1,
    ERR_BAD_TRANSITION = 2
}

##### PROPERTIES #####

# Array<String>, the list of available states
export var states := [] setget _set_states, _get_states
# Dict<String, Array<String> >, a whitelist of allowed state-to-state transitions
export var transitions := {} setget _set_transitions, _get_transitions

##### NOTIFICATIONS #####

func _init(p_states: Array = [], p_transitions: Dictionary = {}):
    self.states = p_states
    self.transitions = p_transitions

##### OVERRIDES #####

##### VIRTUAL METHODS #####

##### PUBLIC METHODS #####

func gen_state_property_info(p_name):
    return {
        "name": p_name,
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": PoolStringArray(states).join(",")
    }

func add_transition(p_from: String, p_to: String) -> void:
    assert(p_from in states)
    if not transitions.has(p_from):
        transitions[p_from] = []
    transitions[p_from].append(p_to)

func remove_transition(p_from: String, p_to: String) -> void:
    assert(p_from in transitions)
    assert(p_to in transitions[p_from])
    transitions[p_from].erase(p_to)
    if transitions[p_from].empty():
        transitions.erase(p_from)

func can_transition(p_from: String, p_to: String) -> int:
    if !p_from in states:
        return Error.ERR_BAD_STATE
    if p_from in transitions or p_to in transitions[p_from]:
        return Error.ERR_BAD_TRANSITION
    return OK

##### PRIVATE METHODS #####

##### CONNECTIONS #####

##### SETTERS AND GETTERS #####

func _set_states(p_states: Array):
    states = p_states

func _get_states() -> Array:
    return states

func _set_transitions(p_transitions: Dictionary):
    transitions = p_transitions

func _get_transitions() -> Dictionary:
    return transitions