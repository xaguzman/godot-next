# ClassType
# author: willnationsdev
# license: MIT
# description: A class abstraction, both for engine and user-defined types.
#              Provides inheritance queries, reflection data, and instantiation.
# todo: Refactor all "maps" and file searches to a formal FileSearch class that
#       uses a user-provided FuncRef to determine whether to include a file in
#       the search.
# usage:
# - Creation:
#     var ct_name = ClassType.from_name("MyNode") (engine + script classes)
#     var ct_path = ClassType.from_path("res://my_node.gd") (scripts or scenes)
#     var ct_object = ClassType.from_object(MyNode) (scripts or scenes)
#     var ct_any = ClassType.new(<whatever>)
#     var ct_empty = ClassType.new()
#     var ct_empty_with_deep_type_map = ClassType.new(null, true)
#     var ct_shallow_copy = ClassType.new(ct) (copies references to internal type map Dictionaries)
#     var ct_deep_copy = ClassType.new(ct, false, true) (duplicates internal type map Dictionaries)
# - Printing:
#     print(ct.name) # prints engine or script class name
#     print(ct.to_string()) # prints name or, if an anonymous resource, a PascalCase version of the filename
# - Type Checks:
#     if ClassType.static_is_object_instance_of(MyNode, node): # static is_object_instance_of() method for comparisons.
#     if ClassType.static_is_type(MyNode, "Node"): # static is_type() method for comparisons.
#     if ct.is_type("Node"): # non-static `is_type`. Assumes first parameter from the ct instance.
#     if ct.is_object_instance_of(node): # non-static `is_object_instance_of`. Assumes first parameter from the ct instance.
#     Note:
#     - Must use Strings for engine classes
#     - Must use PackedScene instances for scenes
#     - Must use Script instances for anonymous scripts
#     - Both Strings and Script instances available for script classes
#     - If the deep type map has been initialized (refresh_deep_type_map()), then namified paths can be used for anonymous scripts and scenes too.
# - Validity Checks:
#     if ct.class_exists() # is named type (engine or script class)
#     if ct.path_exsts() # is a resource (script or scene)
#     if ct.is_non_class_res() # is an anonymous resource
#     if ct.is_valid() # is engine class or resource
# - Class Info:
#     var type = ct.get_engine_class() # get base type name: "Node" for Node
#     var type = ct.get_script_class() # get script type name: "MyNode" for MyNode
# - Inheritance Checks:
#     var parent = ct.get_engine_parent() # get CustomType of inherited engine class
#     var parent = ct.get_script_parent() # get CustomType of inherited script resource
#     var parent = ct.get_scene_parent() # get CustomType of inherited scene resource
#     var parent = ct.get_type_parent() # get CustomType of inherited engine/script/scene type
#     ct.become_parent() # CustomType changes to inherited engine/script/scene type
# - Type Maps:
#     var script_map = ct.get_script_map() # 'script_map' is...
#         Dictionary<name, {
#             'base': <engine class>
#             'name': <script class>
#             'language': <language name>
#             'path': <file path>
#         }>
#     var type_map = ct.get_deep_type_map() # 'type_map' is...
#         Dictionary<name, {
#             'name': <class name or generated file name>
#             'type': <"Script"|"PackedScene">
#             'path': <file path>
#         }>
# - Inheritance Lists:
#     var list: PoolStringArray = ct.get_inheritors_list() # get all named types that inherit "MyNode" (engine + script classes)
#     var ct = CustomType.new(list[0]) # works because named types only
#     
#     var list: PoolStringArray = ct.get_deep_inheritors_list() # get all types that inherit "MyNode" (engine + script and scene resources, namified paths for anonymous ones)
#     var ct = ClassType.from_type_dict(type_map[list[0]]) # factory method handles init logic
tool
extends Reference
class_name ClassType

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

enum Source {
	NONE,
	ENGINE,
	SCRIPT,
    ANONYMOUS
}

const SELF_PATH := "res://addons/godot-next/references/class_type.gd"

##### PROPERTIES #####

export var name: String = "" setget set_name, get_name
export(String, FILE) var path: String = "" setget set_path, get_path
export(Resource) var res: Resource = null setget set_res, get_res

var _source: int = Source.NONE

var _script_map: Dictionary = {}
var _path_map: Dictionary = {}
var _deep_type_map: Dictionary = {}
var _deep_path_map: Dictionary = {}

var _script_map_dirty: bool = true
var _is_filesystem_connected: bool = false

##### NOTIFICATIONS #####

func _init(p_input = null, p_generate_deep_map: bool = true) -> void:
	match typeof(p_input):
		TYPE_OBJECT:
			if p_input is (get_script() as Script):
				self.name = p_input.name
				return
			_init_from_object(p_input)
		TYPE_STRING:
			if ResourceLoader.exists(p_input):
				_init_from_path(p_input)
			else:
				_init_from_name(p_input)

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

# Returns the name of the class or resource.
# Anonymous resources' paths are namified.
# Scenes auto-add "Scn" to the name
func to_string():
	if name:
		return name
	if res:
		var named_path = TypeDB.namify_path(res.resource_path)
		if res is PackedScene:
			named_path += "Scn"
		return named_path
	return ""

# Is this ClassType the same as or does it inherit another class name/resource?
func is_type(p_other) -> bool:
	match _source:
		Source.NONE:
			return false
		Source.ENGINE:
			if typeof(p_other) == TYPE_OBJECT and p_other.get_script() == get_script():
				return TypeDB.is_type(name, p_other.name)
			return TypeDB.is_type(name, p_other)
	if typeof(p_other) == TYPE_OBJECT:
		match p_other.get_class():
			"Script", "PackedScene":
				pass
			_:
				if p_other.get_script() == get_script():
					if res:
						return TypeDB.is_type(res, p_other.res)
					return TypeDB.is_type(name, p_other.name)

				var other = from_object(p_other)
				if other.res:
					return TypeDB.is_type(res, other.res)
	return TypeDB.is_type(res, p_other)

# Instantiate whatever type the ClassType refers to
func instance() -> Object:
	if _source == Source.ENGINE:
		return ClassDB.instance(name)
	if res:
		if res is Script:
			return res.new()
		if res is PackedScene:
			return res.instance()
	return null

# Get the engine class name
func get_engine_class() -> String:
	if Source.ENGINE == _source:
		return name
	if res:
		if res is Script:
			return (res as Script).get_instance_base_type()
		if res is PackedScene:
			var state := (res as PackedScene).get_state()
			return state.get_node_type(0)
	return ""

# Get the script class name
func get_script_class() -> String:
	match _source:
		Source.ENGINE:
			return ""
	var script: Script = null
	if res:
		var scene := res as PackedScene
		if scene:
			script = TypeDB._scene_get_root_script(scene)
		elif res is Script:
			script = res as Script
	return TypeDB.get_script_name(script)

# Get the name of the type
func get_type_class() -> String:
	var ret := get_script_class()
	if not ret:
		ret = get_engine_class()
	return ret

# Is this a "named" type, i.e. engine or script class?
func class_exists() -> bool:
	return _source == Source.ENGINE or _source == Source.SCRIPT

# Does our stored resource path exist?
# False for engine classes.
# if path doesn't exist, then it makes scripts and scenes "invalid".
func path_exists() -> bool:
	return ResourceLoader.exists(path)

# Is this a named type or an anonymous resource?
func is_valid() -> bool:
	return class_exists() or path_exists()

# Is this an anonymous resource?
func is_non_class_res() -> bool:
	return path_exists() and not class_exists()

# Cast to Script
func as_script() -> Script:
	return res as Script

# Cast to PackedScene
func as_scene() -> PackedScene:
	return res as PackedScene

# get inherited engine class as ClassType
func get_engine_parent() -> Reference:
	var ret := _new()
	if _source == Source.SCRIPT:
		ret.name = get_engine_class()
	elif _source == Source.ENGINE:
		ret.name = ClassDB.get_parent_class(name)
	return ret

# get inherited script resource as ClassType
func get_script_parent() -> Reference:
	var ret := _new()
	if _source == Source.ENGINE:
		ret.name = ""
	elif res:
		var scene := res as PackedScene
		if scene:
			var script := TypeDB._scene_get_root_script(scene)
			ret._init_from_object(script)
		else:
			var script := res as Script
			if script:
				ret._init_from_object(script.get_base_script())
			else:
				ret.path("")
	return ret

# get inherited scene resource as ClassType
func get_scene_parent() -> Reference:
	var ret := _new()
	match _source:
		Source.ENGINE, Source.SCRIPT:
			return ret
		Source.NONE:
			return null
	var scene := res as PackedScene
	scene = TypeDB._scene_get_root_scene(scene)
	ret.res = scene
	return ret

# get inherited resource or engine class as ClassType
func get_type_parent() -> Reference:
	var ret = get_scene_parent()
	if ret.is_valid():
		return ret
	ret = get_script_parent()
	if ret.is_valid():
		return ret
	return get_engine_parent()

# Convert the current ClassType into its base ClassType. Returns true if valid.
# Can use an inheritance loop like so:
"""
# Where my_node.tscn is a scene with a MyNode script attached to a Node root
# and MyNode is a script class extending Node

var ct = ClassType.new('res://my_node.tscn')
print(ct.to_string())
while ct.become_parent():
	print(ct.to_string())

# prints:

MyNodeScn
MyNode
Node
Object
"""
func become_parent() -> bool:
	if not res:
		if not name:
			return true
		self.name = ClassDB.get_parent_class(name)
		return ClassDB.class_exists(name)
	var scene := res as PackedScene
	if scene:
		var base := TypeDB._scene_get_root_scene(scene)
		if base:
			self.res = base
			return true
		var script := TypeDB._scene_get_root_script(scene)
		if script:
			self.res = script
			return true
	return false

# Returns the inherited Script object. For scene's this fetches the script
# of the root node.
func get_type_script() -> Script:
	var scene := res as PackedScene
	var script: Script = null
	if scene:
		script = TypeDB._scene_get_root_script(scene)
	if not script:
		script = res as Script
	return script

# Wrapper for the base engine class's `can_instance()` method.
# This is specific for the engine and does not relate to abstract-ness.
func can_instance() -> bool:
	if _source == Source.ENGINE:
		return ClassDB.can_instance(name)
	var script = get_type_script()
	if script:
		return script.can_instance()
	return false

# Generate a list of named classes that extend the represented class or
# resource. SLOW
func get_inheritors_list() -> PoolStringArray:
	return TypeDB.get_inheritors_list(name)

func is_object_instance_of(p_object) -> bool:
	var ct := from_object(p_object) as Reference
	return ct.is_type(self)

# ClassType.new(p_name), but for clarity.
static func from_name(p_name: String) -> Reference:
	var ret := _new()
	ret._init_from_name(p_name)
	return ret

# ClassType.new(p_path), but for clarity.
static func from_path(p_path: String) -> Reference:
	var ret := _new()
	ret._init_from_path(p_path)
	return ret

# ClassType.new(p_object), but for clarity.
static func from_object(p_object: Object) -> Reference:
	var ret := _new()
	ret._init_from_object(p_object)
	return ret

# Utility function to create from `get_deep_type_map()` values
static func from_type_dict(p_data: Dictionary) -> Reference:
	var ret := _new()
	match p_data.type:
		"Engine":
			ret._init_from_name(p_data.name)
		"Script", "PackedScene":
			ret._init_from_path(p_data.path)
	return ret

##### CONNECTIONS #####

##### PRIVATE METHODS #####

# reset properties based on a given name
func _init_from_name(p_name: String) -> void:
	name = p_name
	if ClassDB.class_exists(p_name):
		path = ""
		res = null
		_source = Source.ENGINE
		return
	var data := TypeDB._get_script_class_data(p_name)
	if not data.empty():
		path = _script_map[p_name].path
		res = load(path)
		_source = Source.SCRIPT
		return
	path = ""
	res = null
	_source = Source.NONE

# reset properties based on a given path
func _init_from_path(p_path: String) -> void:
	path = p_path
	res = load(path) if ResourceLoader.exists(path) else null
	var map := TypeDB.get_script_map()
	if map.has(p_path):
		name = map[p_path].name
		_source = Source.SCRIPT
		return
	name = ""
	_source = Source.NONE

# reset properties based on a given object instance
# if null: don't initialize.
# if a scene's root node, become the scene.
# if an object with a script, become that script.
# otherwise, if a Script or PackedScene, become that.
# otherwise, become whatever the given class is
# Note:
# 1. Due to this logic, one cannot set a ClassType to be "Script" or
#    "PackedScene" with this method.
# 2. Due to this logic, one cannot become a specialized type of PackedScene
#    resource that has its own script.
func _init_from_object(p_object: Object) -> void:
	var initialized: bool = false
	if not p_object:
		name = ""
		path = ""
		res = null
		_source = Source.NONE
		initialized = true
	var n := p_object as Node
	if not initialized and n and n.filename:
		_init_from_path(n.filename)
		initialized = true
	var s := (p_object.get_script() as Script) if p_object else null
	if not initialized and s:
		if not s.resource_path:
			res = s
			path = ""
			name = ""
			_source = Source.ANONYMOUS
		else:
			_init_from_path(s.resource_path)
		initialized = true
	if not initialized and (p_object is PackedScene or p_object is Script):
		_init_from_path((p_object as Resource).resource_path)
		initialized = true
	if not initialized and not path and not name:
		_init_from_name(p_object.get_class())
		initialized = true

# Same as _get_script_map, but it includes all resources
static func _get_deep_type_map() -> Dictionary:
	var _script_map = _get_script_map()
	var _path_map = _get_path_map(_script_map)
	var dirs = ["res://"]
	var first = true
	var data = {} # Dictionary<name, {"path": <path>}>

	# Build a data-driven way of generating a Dictionary<file_extension, type>
	# because Godot doesn't expose `ResourceLoader.get_resource_type(path)`. Ugh
	var exts = {}
	var res_types = ["Script", "PackedScene"]
	for a_type in res_types:
		for a_ext in ResourceLoader.get_recognized_extensions_for_type(a_type):
			exts[a_ext] = a_type
	exts.erase("res")
	exts.erase("tres")

	# generate 'data' map
	while not dirs.empty():
		var dir = Directory.new()
		var dir_name = dirs.back()
		dirs.pop_back()

		if dir.open(dir_name) == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name:
				if not dir_name == "res://":
					first = false
				# Ignore hidden content
				if not file_name.begins_with("."):
					# If a directory, then add to list of directories to visit
					if dir.current_is_dir():
						dirs.push_back(dir.get_current_dir().plus_file(file_name))
					# If a file, check if we already have a record for the same name.
					# Only use files with extensions
					elif not data.has(file_name) and exts.has(file_name.get_extension()):
						var a_path = dir.get_current_dir() + ("/" if not first else "") + file_name

						var existing_name = _path_map[a_path] if _path_map.has(a_path) else ""
						var a_name = TypeDB.namify_path(file_name)
						a_name = a_name.replace("2d", "2D").replace("3d", "3D")

						if data.has(existing_name) and existing_name == a_name:
							file_name = dir.get_next()
							continue
						elif existing_name: # use existing name if it's there
							a_name = existing_name

						data[a_name] = {
							"name": a_name,
							"path": a_path,
							"type": exts[file_name.get_extension()] # "Script" or "PackedScene"
						}
				# Move on to the next file in this directory
				file_name = dir.get_next()
			# We've exhausted all files in this directory. Close the iterator
			dir.list_dir_end()

	return data

# Utility for fetching a reference to this script in a static context
static func _this() -> Script:
	return load(SELF_PATH) as Script

# Utility for creating an instance of this class in a static context
static func _new() -> Reference:
	return _this().new() as Reference

##### SETTERS AND GETTERS #####

# Re-initialize based on assigned name.
func set_name(p_value: String) -> void:
	_init_from_name(p_value)

func get_name() -> String:
	return name

# Re-initialize based on assigned path.
func set_path(p_value: String) -> void:
	_init_from_path(p_value)

func get_path() -> String:
	return path

# Re-initialize based on assigned resource.
func set_res(p_value: Resource) -> void:
	if not p_value:
		self.name = ""
	_init_from_object(p_value)

func get_res() -> Resource:
	return res