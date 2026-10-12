@tool
extends RefCounted
## Export a detached visual snapshot: no edits to scene, cached meshes or recipe.
static func write_glb(asset: HD2DAsset, skin: StringName, path: String) -> Error:
	if asset==null or not asset.source is PackedScene: return ERR_INVALID_DATA
	if path.get_extension().to_lower()!="glb": return ERR_INVALID_PARAMETER
	var root := (asset.source as PackedScene).instantiate() as Node3D
	if root==null: return ERR_INVALID_DATA
	asset.apply_skin(root,skin)
	# Blender receives editable mesh parts. Editor physics helpers are not artwork.
	for child in root.find_children("*","CollisionObject3D",true,false):
		child.get_parent().remove_child(child);child.free()
	root.name="Jeff_"+asset.building_profile.style+"_"+asset.building_profile.type_id if asset.building_profile else "Jeff_Building"
	root.transform=Transform3D.IDENTITY
	var document := GLTFDocument.new();var state := GLTFState.new()
	document.image_format="PNG";document.root_node_mode=GLTFDocument.ROOT_NODE_MODE_KEEP_ROOT
	var result := document.append_from_scene(root,state)
	if result==OK: result=document.write_to_filesystem(state,path)
	root.free()
	return result
