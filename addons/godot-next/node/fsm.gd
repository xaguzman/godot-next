# FSM
# author: willnationsdev
# brief description: A Finite State Machine node. Uses FSMNetwork. Manages the initial and current state. Signals changes.
# API details:
# - Generates state dropdowns from the FSMNetwork data.
# - Provides debug options for what to do in case of an error.
# - Automatically modifies state properties in response to changes in the `network` value.

tool
extends Node
class_name FSM

##### SIGNALS #####

signal state_changed(p_from, p_to)

##### CONSTANTS #####

enum DebugOptions {
    Nothing,
    Assert,
    Print
}

##### PROPERTIES #####

export(Resource) var fsm_network: FSMNetwork = null setget set_fsm_network
export(DebugOptions) var debug_option = DebugOptions.Assert

var initial_state := "" setget set_initial_state
var current_state := "" setget set_current_state

##### NOTIFICATIONS #####

func _init(p_fsm_network: FSMNetwork = null) -> void:
    fsm_network = p_fsm_network
    current_state = initial_state

func _set(p_name: String, p_value) -> void:
    match p_name:
        "initial_state":
            initial_state = p_value
        "current_state":
            set_current_state(p_value)

func _get(p_name):
    match p_name:
        "initial_state":
            return initial_state
        "current_state":
            return get_current_state()

func _get_property_list() -> Array:
    var props = []
    if not network:
        return props
    props += [
        network.gen_state_property_info("initial_state"),
        network.gen_state_property_info("current_state")
    ]
    return props

#### OVERRIDES #####

func get_configuration_warning():
    if not network:
        return "An FSMNetwork is not assigned."
    return ""

##### VIRTUAL METHODS #####

##### PUBLIC METHODS #####

##### PRIVATE METHODS #####

##### CONNECTIONS #####

##### SETTERS AND GETTERS #####

func set_current_state(p_state: String) -> void:
    if not p_state:
        if network:
            current_state = network.states[0]
        else:
            current_state = ""

    match can_transition(current_state, p_state):
        FSMNetwork.Error.ERR_BAD_STATE:
            match debug_option:
                DebugOptions.Assert:
                    assert(false)
                DebugOptions.Print:
                    printerr("state '%s' does not exist." % [p_state])
        FSMNetwork.Error.ERR_BAD_TRANSITION:
            match debug_option:
                DebugOptions.Assert:
                    assert(false)
                DebugOptions.Print:
                    printerr("Unable to move from state '%s' to '%s'." % [current_state, p_state])

    var tmp = current_state
    current_state = p_state
    emit_signal("state_changed", tmp, p_state)

func set_fsm_network(p_fsm_network: FSMNetwork):
    if p_fsm_network:
        initial_state = p_fsm_network.states[0] if !initial_state in p_fsm_network.states else initial_state
        current_state = p_fsm_network.states[0] if !current_state in p_fsm_network.states else current_state
    else:
        initial_state = ""