# Trail2D
# author: willnationsdev
# brief description: Creates a variable-length trail that tracks the "target" node.
# API details:
# - Use CanvasItem.show_behind_parent or Node2D.z_index (Inspector) to control its layer visibility
# - 'target' and 'target_path' (the 'target vars') will update each other as they are modified
# - If you assign an empty 'target var', the value will automatically update to grab the parent.
#     - To completely turn off the Trail2D, set its `trail_length` to 0
# - The node will automatically update its target vars when it is moved around in the tree
# - You can set the "persistance" mode to have it...
#     - vanish the trail over time (Off)
#     - persist the trail forever, unless modified directly (Always)
#     - persist conditionally:
#         - persist automatically during movement and then shrink over time when you stop
#         - persist according to your own custom logic:
#             - use `bool _should_grow()` to return under what conditions
#               a point should be added underneath the target.
#             - use `bool _should_shrink()` to return under what conditions
#               the degen_rate should be removed from the trail's list of points.

extends Line2D
class_name Trail2D, "../icons/icon_trail_2d.svg"

##### SIGNALS #####

# If true, notifies that points have all been removed. Else, points are now present.
signal trail_zero_changed(p_no_points)
# If true, all points are equal, i.e. the trail has vanished. Else, the trail has appeared again.
signal trail_empty_changed(p_is_empty)

##### CONSTANTS #####

enum Persistance {
	OFF,        # Do not persist. Remove all points after the trail_length.
	ALWAYS,     # Always persist. Do not remove any points.
	CONDITIONAL # Sometimes persist. Choose an algorithm for when to add and remove points.
}

enum PersistWhen {
	ON_MOVEMENT, # Add points during movement and remove points when not moving.
	CUSTOM       # Override _should_grow() and _should_shrink() to define when to add/remove points.
}

##### PROPERTIES #####

# The target node to track
var target: Node2D setget set_target
# Cache instances when there are no points
var _zero_points: bool = true
# Cache instances when points are all equal
var _empty: bool = true

# The NodePath to the target
export var target_path: NodePath = @".." setget set_target_path
# If not persisting, the number of points that should be allowed in the trail
export var trail_length: int = 10
# To what degree the trail should remain in existence before automatically removing points.
export(int, "Off", "Always", "Conditional") var persistance: int = Persistance.OFF
# During conditional persistance, which persistance algorithm to use
export(int, "On Movement", "Custom") var persistance_condition: int = PersistWhen.ON_MOVEMENT
# During conditional persistance, how many points to remove per frame
export var degen_rate: int = 1
# If true, automatically set z_index to be one less than the 'target'
export var auto_z_index: bool = true
# If true, will automatically setup a gradient for a gradually transparent trail.
export var auto_alpha_gradient: bool = true
# If true, spend time determining when emptiness occurs to trigger signals. Else, do not waste processing time.
export var track_emptiness: bool = true

##### NOTIFICATIONS #####

func _init() -> void:
	set_as_toplevel(true)
	global_position = Vector2()
	global_rotation = 0
	if auto_alpha_gradient and not gradient:
		gradient = Gradient.new()
		var first = default_color
		first.a = 0
		gradient.set_color(0, first)
		gradient.set_color(1, default_color)

func _notification(p_what: int) -> void:
	match p_what:
		NOTIFICATION_PARENTED:
			self.target_path = target_path
			if auto_z_index:
				z_index = target.z_index - 1 if target else 0
		NOTIFICATION_UNPARENTED:
			self.target_path = @""
			self.trail_length = 0

#warning-ignore:unused_argument
func _process(delta: float) -> void:
	if target:
		match persistance:
			Persistance.OFF:
				add_point(target.global_position)
				while get_point_count() > trail_length:
					remove_point(0)
			Persistance.ALWAYS:
				add_point(target.global_position)
				pass
			Persistance.CONDITIONAL:
				match persistance_condition:
					PersistWhen.ON_MOVEMENT:
						var moved: bool = get_point_position(get_point_count()-1) != target.global_position if get_point_count() else false
						if not get_point_count() or moved:
							add_point(target.global_position)
						else:
							for _i in range(degen_rate):
								remove_point(0)
					PersistWhen.CUSTOM:
						if _should_grow():
							add_point(target.global_position)
						if _should_shrink():
							for _i in range(degen_rate):
								remove_point(0)
		_update_emptiness()

func _update_emptiness() -> void:
	if not track_emptiness:
		return
	
	# handle case where points really are empty / become empty
	if _zero_points:
		if get_point_count():
			_zero_points = false
			emit_signal("trail_zero_changed", _zero_points)
	else:
		if not get_point_count():
			_zero_points = true
			emit_signal("trail_zero_changed", _zero_points)
	
	# handle case where points exist, but are all equal, i.e. no trail
	if get_point_count():
		var first = get_point_position(0)
		var trail_exists = false
		for i in get_point_count():
			if first != get_point_position(i):
				trail_exists = true
				break
		if _empty != trail_exists:
			_empty = not trail_exists
			emit_signal("trail_empty_changed", _empty)

##### OVERRIDES #####

##### VIRTUAL METHODS #####

func _should_grow() -> bool:
	return true

func _should_shrink() -> bool:
	return true

##### PUBLIC METHODS #####

func erase_trail() -> void:
	for _i in range(get_point_count()):
		remove_point(0)

##### PRIVATE METHODS #####

##### SETTERS AND GETTERS #####

func set_target(p_value: Node2D) -> void:
	if p_value:
		if get_path_to(p_value) != target_path:
			target_path = get_path_to(p_value)
	else:
		target_path = @""

func set_target_path(p_value: NodePath) -> void:
	target_path = p_value
	target = get_node(p_value) as Node2D if has_node(p_value) else null