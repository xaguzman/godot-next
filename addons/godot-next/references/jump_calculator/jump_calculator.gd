# JumpCalculator
# author: toiletsnakes
# brief_description: A utility for determining kinematic jump parameters in 3D.
extends "base_jump_calculator.gd"
class_name JumpCalculator

var height: float setget set_height, get_height

##### OVERRIDES #####

##### VIRTUALS #####

##### PUBLIC METHODS #####

func calculate(p_height: float, p_time: float):
    var delta: float = 1.0 / ProjectSettings.get_setting("physics/common/physics_fps")
    gravity = delta * ((2 * p_height) / pow(p_time, 2.0))
    initial_speed = -sqrt(2 * gravity * p_height)

static func from_height_and_time(p_height, p_time: float) -> Reference:
    return _from_height_and_time(load("res://addons/godot-next/references/jump_calculator/jump_calculator.gd"), p_height, p_time) as Reference

##### PRIVATE METHODS #####

##### CONNECTIONS #####

##### SETTERS AND GETTERS #####

func set_height(p_value: float):
    height = p_value
    calculate(height, time)

func get_height() -> float:
    return height
