# BaseJumpCalculator
# author: toiletsnakes
# brief_description: An ABSTRACT base utility for determining how jump parameters. DO NOT instantiate.
# usage:
"""
# You want your character to jump 4 blocks high (where each block is 16 pixels),
# and you want it to take 0.25 seconds
var j = Jump.configure(4*16, 0.25)

# when first setting jump velocity
player.velocity = Vector2.DOWN * j.jump_speed

# when applying gravity (once per frame)
player.velocity += Vector2.DOWN * j.gravity

# don't forget to multiply by delta where appropriate
# in Godot, you don't need to multiply by delta when using move_and_slide,
# but you do with move_and_collide
"""
extends Reference

##### CLASSES #####

##### SIGNALS #####

##### CONSTANTS #####

##### PROPERTIES #####

# Gravity to reduce movement per frame
var gravity: float = 0.0

# Initial jump speed
var initial_speed: float = 0.0

# Time to max height
var time: float = 0.0 setget set_time, get_time

##### NOTIFICATIONS #####

func _init(p_gravity: float, p_speed: float):
    gravity = p_gravity
    initial_speed = p_speed

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

static func _from_height_and_time(p_script: Script, p_height, p_time: float) -> Reference:
    assert p_script
    var j = p_script.new(0.0, 0.0)
    j.call("calculate", p_height, p_time)
    return j

##### PRIVATE METHODS #####

##### CONNECTIONS #####

##### SETTERS AND GETTERS #####

func set_time(p_value):
    time = p_value
    call("calculate", get("height"), time)

func get_time() -> float:
    return time