@tool
extends RefCounted
## Append-only identifiers; existing v1-v5 recipes keep their original generators.
const IDS := ["jiangnan","forest","desert","machiya","nordic","harbor","palace","gothic","steamworks"]
const TITLES := ["江南古镇","欧式风格","沙漠聚落","日式町屋","北欧雪乡","热带海港","中式宫阙","哥特城镇","蒸汽工业"]
const BASES := {"machiya":"jiangnan","nordic":"forest","harbor":"forest","palace":"jiangnan","gothic":"forest","steamworks":"forest"}
const COLORS := ["b5b0a0","81715c","b89968","6c6865","9aa4ac","ad9a80","bbae8d","85818b","98715e"]

static func version(style: String) -> int:
	return 6 if BASES.has(style) else 5

static func defaults(style: String, type_id: String, p: Dictionary) -> Dictionary:
	var result := p.duplicate(true)
	match style:
		"machiya": result.merge({"width":5.5,"depth":6.0,"pitch":28,"eave":0.65,"balcony":false},true)
		"nordic": result.merge({"width":5.5,"depth":5.0,"pitch":50,"eave":0.65,"balcony":false},true)
		"harbor": result.merge({"width":6.5,"depth":5.5,"pitch":30,"eave":0.85,"balcony":true},true)
		"palace": result.merge({"width":7.5,"depth":6.0,"pitch":30,"eave":0.9,"balcony":true},true)
		"gothic": result.merge({"width":5.5,"depth":6.0,"pitch":50,"eave":0.35,"balcony":false},true)
		"steamworks": result.merge({"width":7.0,"depth":5.5,"pitch":25,"eave":0.25,"balcony":false},true)
	if type_id=="general_store": result.width+=0.5
	if type_id=="inn": result.width+=1.0;result.depth+=0.5;result.floors=2
	return result

static func towns() -> Array:
	var result := []
	for i in IDS.size(): result.append({"id":"native-"+IDS[i],"title":"内置 · "+TITLES[i],"native":IDS[i],"color":COLORS[i]})
	return result
