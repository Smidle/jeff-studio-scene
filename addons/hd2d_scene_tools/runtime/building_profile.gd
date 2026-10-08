@tool
class_name HD2DBuildingProfile
extends Resource
## Versioned source recipe. Generated meshes are saved independently for runtime.
@export var generator_version := 1
@export var preset_version := 1
@export var style := "jiangnan"
@export var kind := 0
@export var category_id := ""
@export var type_id := ""
@export var detail_seed := 0
@export var parameters: Dictionary = {}
@export var shape_seed := 60421
@export var appearance_seed := 101

func identity() -> String:
	var keys := parameters.keys(); keys.sort()
	var stable := []
	for key in keys: stable.append([key,parameters[key]])
	var recipe := [generator_version,preset_version,style,kind,stable,shape_seed,appearance_seed]
	if generator_version>=4: recipe.append_array([category_id,type_id,detail_seed])
	return var_to_str(recipe).sha256_text()
