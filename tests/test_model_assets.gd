extends SceneTree

const ModelAssets = preload("res://scripts/model_assets.gd")

const MODEL_PATHS: Array[String] = [
	ModelAssets.TREE_MODEL,
	ModelAssets.HOUSE_MODEL,
	ModelAssets.PLAYER_MODEL,
	ModelAssets.ENEMY_MODEL,
]


func _initialize() -> void:
	_assert(ModelAssets.ENEMY_MODEL == ModelAssets.PLAYER_MODEL, "Expected enemy and player to use the same pawn model")
	for path in MODEL_PATHS:
		var model := ModelAssets.instantiate_model(path, "TestModel", Vector3(1.0, 2.0, 3.0), 2.0)
		_assert(model != null, "Expected model asset to instantiate: %s" % path)
		_assert(model.name == "TestModel", "Expected model helper to assign the requested name")
		_assert(model.position == Vector3(1.0, 2.0, 3.0), "Expected model helper to assign the requested position")
		_assert(model.scale == Vector3(2.0, 2.0, 2.0), "Expected model helper to assign the requested scale")
		model.queue_free()
	quit()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
