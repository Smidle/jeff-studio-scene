@tool
class_name HD2DVillage
extends Node3D
## Authored recipe only. Buildings and roads are ordinary saved child nodes.
## Opening a scene never regenerates or overwrites manually edited children.
@export var recipe: Dictionary = {}
