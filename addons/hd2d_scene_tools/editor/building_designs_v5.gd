@tool
extends RefCounted
## Nine calibrated silhouettes, while stored parameters remain the complete recipe.
static func defaults(id: String,style: String) -> Dictionary:
	var p := {"width":6.5,"depth":5.0,"floors":1,"windows":2,"pitch":32,"eave":0.7,"porch":true,"balcony":false,"ornament":true,"roof":0}
	if style=="forest": p.merge({"width":5.75,"depth":5.25,"pitch":46,"eave":0.5},true)
	elif style=="desert": p.merge({"width":6.0,"depth":5.5,"pitch":24,"eave":0.2},true)
	if id=="general_store": p.width+=1.0;p.depth-=0.25;p.floors=1
	if id=="inn": p.width+=1.5;p.depth+=1.0;p.floors=2;p.windows=3;p.balcony=true
	return p
