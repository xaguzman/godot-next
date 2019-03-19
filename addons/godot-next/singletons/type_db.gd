# TypeDB
# author: willnationsdev
# license: MIT
# description: A singleton that tracks type information for one's project.
tool
extends Reference
class_name TypeDB

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

const SELF_PATH: String = "res://addons/godot-next/singletons/type_db.gd"

##### PROPERTIES #####

var script_map: Dictionary = {} # Dictionary<Name, ScriptClassDictionary>
var path_map: Dictionary = {} # Dictionary<Path, ScriptClassDictionary>

##### NOTIFICATIONS #####

func _init() -> void:
    _build_maps()
    if Engine.editor_hint:
        var fs: EditorFileSystem = Singletons.fetch_editor(EditorFileSystem)
        if fs:
			#warning-ignore:return_value_discarded
            fs.connect("filesystem_changed", self, "_on_filesystem_changed")
			#warning-ignore:return_value_discarded
            fs.connect("resources_reload", self, "_on_resources_reload")

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

# Returns a reference to the TypeDB Singleton.
static func fetch() -> Reference:
    return Singletons.fetch(_this()) as Reference

# Returns the named type that `p_type` inherits from
static func get_parent_class(p_type: String) -> String:
	var map := fetch().script_map
    if not p_type or not map.has(p_type):
        return ""
    var data := map[p_type] as ClassData
    if not data:
        return ""
    if not data.path:
        return ClassDB.get_parent_class(data.name)
    var script := load(data.path) as Script
	var pmap := fetch().path_map
	while script:
		if pmap.has(script.resource_path):
			return pmap[script.resource_path].name
        script = script.get_base_script()
    return data.native

# Returns the Script that `p_type` inherits from
static func get_base_script(p_type: Resource) -> Script:
    if not p_type:
        return null
    if p_type is Script:
        return p_type.get_base_script()
    if p_type is PackedScene:
        return _scene_get_root_script(p_type)
    return null

# Returns the PackedScene that `p_type` inherits from
static func get_base_scene(p_type) -> PackedScene:
    if typeof(p_type) == TYPE_OBJECT and p_type is PackedScene:
        return _scene_get_root_scene(p_type)
	return null

static func is_script_class(p_type: String) -> bool:
	return fetch().script_map.has(p_type)
	
# Tests whether a class name or resource constitutes another.
#
# String names and Resource instances are interchangeable.
# Example: is_type(MyNode, "Node") == is_type("MyNode", "Node")
#
# PackedScenes are also supported.
#
# Note: scenes are capable of inheriting from divergent
# script and scene inheritance hierarchies simultaneously.
#
# Note: engine types must be referred to using strings. This is
# because GDScriptNativeClass does not implement a method to get
# the name of the type for use in ClassDB queries.
static func is_type(p_type, p_other) -> bool:
	if not p_type:
		return false
	
	match typeof(p_type):
		# is_type(<string>, <something>)
		TYPE_STRING:

			# is_type("Node", "Node")
			if ClassDB.class_exists(p_type) and ClassDB.class_exists(p_other):
				return ClassDB.is_parent_class(p_type, p_other)

			# is_type("MyType", "Node")
			# is_type("MyType", "MyType")
			# is_type("MyType", "MyTypeScn")
			# is_type("MyTypeScn", "Node")
			# is_type("MyTypeScn", "MyType")
			# is_type("MyTypeScn", "MyTypeScn")
			var res_type := _convert_name_to_res(p_type)
			if res_type:
				return is_type(res_type, p_other)
			
			return false

		TYPE_OBJECT:

			match typeof(p_other):
				# is_type(MyType, "Node")
				# is_type(MyType, "MyType")
				# is_type(MyType, "MyTypeScn")
				# is_type(MyTypeScn, "Node")
				# is_type(MyTypeScn, "MyType")
				# is_type(MyTypeScn, "MyTypeScn")
				TYPE_STRING:

					if ClassDB.class_exists(p_other):
						if p_type is PackedScene:
							return _scene_is_engine(p_type, p_other)
						elif p_type is Script:
							return _script_is_engine(p_type, p_other)

					var res_other := _convert_name_to_res(p_other)
					if res_other:
						return is_type(p_type, res_other)

				# is_type(MyType, MyType)
				# is_type(MyType, MyTypeScn)
				# is_type(MyType, node) # reversed scenario (is the node a MyType)
				# is_type(MyTypeScn, MyType)
				# is_type(MyTypeScn, MyTypeScn)
				# is_type(MyTypeScn, node) # reversed scenario (is the node a MyTypeScene)
				TYPE_OBJECT:

					if p_type is PackedScene:
						if p_other is PackedScene:
							return _scene_is_scene(p_type, p_other)
						elif p_other is Script:
							return _scene_is_script(p_type, p_other)
					elif p_type is Script:
						if p_other is PackedScene:
							return _script_is_scene(p_type, p_other)
						elif p_other is Script:
							return _script_is_script(p_type, p_other)
	return false

# Returns a PascalCase rendering of a filename.
static func namify_path(p_path: String) -> String:
	var p := p_path.get_file().get_basename()
	while p != p.get_basename():
		p = p.get_basename()
	return p.capitalize().replace(" ", "")

# Returns a list of engine class names
static func get_engine_class_list() -> PoolStringArray:
	return ClassDB.get_class_list()

# Returns a list of script class names
static func get_script_class_list() -> PoolStringArray:
	return PoolStringArray(fetch().script_map.keys())

# Returns a list of all named classes
static func get_class_list() -> PoolStringArray:
	var class_list := PoolStringArray()
	class_list.append_array(get_engine_class_list())
	class_list.append_array(get_script_class_list())
	return class_list

# Returns true if `p_type` matches a named type. Else returns false.
static func class_exists(p_type: String) -> bool:
	return ClassDB.class_exists(p_type) or fetch().script_map.has(p_type)

# Returns the list of class names that extend a given class name.
static func get_inheritors_list(p_type: String) -> PoolStringArray:
	var ret := PoolStringArray()
	if not p_type:
		return ret
	var class_list = get_class_list()
	for a_class in class_list:
		if a_class != name and is_type(a_class, name):
			ret.append(a_class)
	return ret

# Returns the name of a script or empty string if it isn't a script class.
static func get_script_name(p_type: Script) -> String:
	if not p_type:
		return ""
	var map := fetch().path_map
	if map.has(p_type.resource_path):
		return map[p_type.resource_path].name
	return ""

# Instantiate the type with name `p_type`.
static func instance(p_type: String) -> Object:
	if ClassDB.class_exists(p_type):
		return ClassDB.instance(name)
	var map := fetch().script_map
	if map.has(p_type):
		return load(map[p_type].path).new()
	return null

# Tests whether an object constitutes a class name or resource
static func is_object_instance_of(p_object, p_type: String) -> bool:
	if not p_object or typeof(p_object) != TYPE_OBJECT:
		return false
	var node := p_object as Node
	if node and node.filename:
		return is_type(load(node.filename), p_type)
	var script := p_object.get_script() as Script
	if script:
		return is_type(script, p_type)
	return is_type(p_object.get_class(), p_type)
    
##### PRIVATE METHODS #####

# Utility method that returns a script map by fetching it from ProjectSettings
func _build_maps() -> void:
    var script_classes: Array = ProjectSettings.get_setting("_global_script_classes") as Array if ProjectSettings.has_setting("_global_script_classes") else []

    # clear content
    script_map.clear()
    path_map.clear()

    # build script map
	for a_class in script_classes:
		var data := {}
		data.name = a_class.class
		data.native = a_class.base
		data.path = a_class.path
		data.language = a_class.language

        script_map[data.name] = data
		path_map[data.path] = data

# Utility to statically load get_script() via dynamic load.
static func _this() -> Script:
    return load(SELF_PATH) as Script

# Return the root script associated with a scene.
static func _scene_get_root_script(p_scene: PackedScene) -> Script:
	var state := p_scene.get_state()
	while state:
		var prop_count := state.get_node_property_count(0)
		if prop_count:
			for i in range(prop_count):
				if state.get_node_property_name(0, i) == "script":
					var script := state.get_node_property_value(0, i) as Script
					return script
		var base := state.get_node_instance(0)
		if base:
			state = base.get_state()
		else:
			state = null
	return null

# Return the root scene associated with a scene.
static func _scene_get_root_scene(p_scene: PackedScene) -> PackedScene:
	if not p_scene:
		return null
	var state := p_scene.get_state()
    return state.get_node_instance(0)

static func _convert_name_to_res(p_name: String) -> Resource:
	if not script_map.has(p_name) or ResourceLoader.exists(script_map[p_name].path):
		return null
	return load(script_map[p_name].path)

static func _convert_name_to_variant(p_name: String):
	var res = _convert_name_to_res(p_name)
	if res:
		return res
	if ClassDB.class_exists(p_name):
		return p_name
	return null

static func _get_script_class_data(p_type: String) -> Dictionary:
	var map := fetch().script_map
	if map.has(p_type):
		return map[p_type]
	return {}

# Does this script inherit the features of the given engine class?
static func _script_is_engine(p_script: Script, p_class: String) -> bool:
	return ClassDB.is_parent_class(p_script.get_instance_base_type(), p_class)

# Does one script extend the other, or are they the same?
static func _script_is_script(p_script: Script, p_other: Script) -> bool:
	var script = p_script
	while script:
		if script == p_other:
			return true
		script = script.get_base_script()
	return false

# Is this script extending the same script or class at the root of this scene?
static func _script_is_scene(p_script: Script, p_scene: PackedScene) -> bool:
	var state := p_scene.get_state()
	for prop_index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, prop_index) == "script":
			var script := state.get_node_property_value(0, prop_index) as Script
			return _script_is_script(p_script, script)
	return false

# Is a scene's root node a parent of a certain class?
static func _scene_is_engine(p_scene: PackedScene, p_class: String) -> bool:
	return ClassDB.is_parent_class(p_scene.get_state().get_node_type(0), p_class)

# Does a scene's root script derive from another script?
static func _scene_is_script(p_scene: PackedScene, p_script: Script) -> bool:
	if not p_scene or not p_script:
		return false
	var script := TypeDB._scene_get_root_script(p_scene)
	if not script:
		return false
	return _script_is_script(script, p_script)

# Does a scene derive another scene?
static func _scene_is_scene(p_scene: PackedScene, p_other: PackedScene) -> bool:
	if not p_scene or not p_other:
		return false
	if p_scene == p_other:
		return true
	var scene := p_scene
	while scene:
		var state := scene.get_state()
		var base = state.get_node_instance(0)
		if p_other == base:
			return true
		scene = base
	return false


##### CONNECTIONS #####

func _on_filesystem_changed():
	_build_maps()

func _on_resources_reload(p_resources: PoolStringArray) -> void:
	for a_res in p_resources:
		if path_map.has(a_res):
			_build_maps()
			return

##### SETTERS AND GETTERS #####

static func get_script_map() -> Dictionary:
	return fetch().script_map

static func get_path_map() -> Dictionary:
	return fetch().path_map
