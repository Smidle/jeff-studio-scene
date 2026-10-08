@tool
extends RefCounted
## Plugin-local text only. Never changes TranslationServer, scene data or editable text.
signal changed
const CATALOG = preload("translations.json")
const SECTION := "hd2d_scene_tools"
var language := "en"
var bindings: Dictionary = {}
var patterns: Array = []
var token := RegEx.new()

func _init() -> void:
	token.compile("%(?:\\.[0-9]+)?[sdf]")
	for source in CATALOG.data:
		var matches := token.search_all(source)
		if matches.is_empty(): continue
		var expression := "(?s)^"
		var offset := 0
		for part in matches:
			expression+=escape_regex(source.substr(offset,part.get_start()-offset))+"(.*?)"
			offset=part.get_end()
		expression+=escape_regex(source.substr(offset))+"$"
		var regex := RegEx.new()
		regex.compile(expression)
		patterns.append([regex,CATALOG.data[source],source.contains("\n")])

func escape_regex(value: String) -> String:
	var result := ""
	for character in value:
		if character in "\\.^$|?*+()[]{}": result+="\\"
		result+=character
	return result

func load_preference() -> void:
	var saved: String=str(EditorInterface.get_editor_settings().get_project_metadata(SECTION,"language","en"))
	language=saved if saved in ["en","zh"] else "en"

func set_language(value: String, persist: bool = true) -> void:
	if value not in ["en","zh"]: return
	if persist: EditorInterface.get_editor_settings().set_project_metadata(SECTION,"language",value)
	if language==value: return
	language=value
	for key in bindings.keys():
		var entry: Dictionary=bindings[key]
		var object: Object=entry.object.get_ref()
		if not is_instance_valid(object): bindings.erase(key); continue
		apply_entry(object,entry)
	changed.emit()

func t(source: String) -> String:
	if language=="zh" or source.is_empty(): return source
	if CATALOG.data.has(source): return CATALOG.data[source]
	for entry in patterns:
		if source.contains("\n") and not entry[2]: continue
		var match_value: RegExMatch=entry[0].search(source)
		if match_value==null: continue
		var template: String=entry[1]
		var output := ""
		var offset := 0
		var index := 1
		for part in token.search_all(template):
			output+=template.substr(offset,part.get_start()-offset)+match_value.get_string(index)
			offset=part.get_end(); index+=1
		return output+template.substr(offset)
	if source.contains("\n"):
		var lines := PackedStringArray()
		for line in source.split("\n"): lines.append(t(line))
		return "\n".join(lines)
	return source

func bind(object: Object, property: String, source: String, index: int = -1) -> void:
	var key := "%d:%s:%d"%[object.get_instance_id(),property,index]
	var entry := {"object":weakref(object),"property":property,"source":source,"index":index}
	bindings[key]=entry
	apply_entry(object,entry)

func apply_entry(object: Object, entry: Dictionary) -> void:
	var value := t(entry.source)
	match entry.property:
		"item":
			if entry.index<object.item_count: object.set_item_text(entry.index,value)
		"tab": object.set_tab_title(entry.index,value)
		"filter":
			var filters: PackedStringArray=object.filters
			if entry.index<filters.size(): filters[entry.index]=value; object.filters=filters
		_: object.set(entry.property,value)

func text(object: Object, source: String) -> void:
	bind(object,"text",source)

func watch_property(object: Object, property: String, source: String, index: int=-1) -> void:
	if not bindings.has("%d:%s:%d"%[object.get_instance_id(),property,index]): bind(object,property,source,index)

func watch_dialog_action(dialog: AcceptDialog, property: String, button: Button) -> void:
	# Dialog setters rewrite their native button. Both bindings must share the
	# canonical label, including labels previously bound directly to the button.
	var parent_key := "%d:%s:-1"%[dialog.get_instance_id(),property]
	var child_key := "%d:text:-1"%button.get_instance_id()
	var source: String=str(dialog.get(property))
	if bindings.has(parent_key): source=bindings[parent_key].source
	elif bindings.has(child_key): source=bindings[child_key].source
	# An empty dialog property means Godot supplies its default label. Never
	# copy that sentinel into the child button as an explicitly empty caption.
	if source.is_empty(): source="取消" if property=="cancel_button_text" else "确认"
	bind(dialog,property,source); bind(button,"text",source)

func watch(node: Node) -> void:
	# Call once after constructing a plugin-owned subtree; never scan Godot's native UI.
	if node is SubViewport: return
	if node is EditorFileDialog:
		watch_property(node,"title",node.title)
		for index in range(node.filters.size()): watch_property(node,"filter",node.filters[index],index)
		return
	node.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	if node.has_meta("hd2d_managed_text"): return
	if node is OptionButton:
		for index in range(node.item_count): watch_property(node,"item",node.get_item_text(index),index)
	elif node is Label or node is Button:
		var source: String=node.text
		if node is Button:
			node.clip_text=true
			node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			if node.tooltip_text.is_empty(): node.tooltip_text=source
		watch_property(node,"text",source)
	if node is LineEdit: watch_property(node,"placeholder_text",node.placeholder_text)
	if node is Control and not node.tooltip_text.is_empty(): watch_property(node,"tooltip_text",node.tooltip_text)
	if node is Window: watch_property(node,"title",node.title)
	if node is AcceptDialog: watch_dialog_action(node,"ok_button_text",node.get_ok_button())
	if node is ConfirmationDialog: watch_dialog_action(node,"cancel_button_text",node.get_cancel_button())
	if node is TabContainer:
		for index in range(node.get_tab_count()): watch_property(node,"tab",node.get_tab_title(index),index)
	for child in node.get_children(): watch(child)
