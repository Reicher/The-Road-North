class_name RiverVisual
extends Node3D

@export var tile_size := 96.0
@export var flow_tiles_per_second := 0.16

var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	var half_tile := tile_size * 0.5
	for child in get_children():
		if not child.has_meta("flow_start_x"):
			continue
		var start_x := float(child.get_meta("flow_start_x"))
		var position_3d := (child as Node3D).position
		position_3d.x = wrapf(start_x + _elapsed * tile_size * flow_tiles_per_second + half_tile, 0.0, tile_size) - half_tile
		(child as Node3D).position = position_3d

