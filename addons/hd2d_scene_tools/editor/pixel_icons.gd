@tool
extends RefCounted
## Original 16x16 artwork created in Aseprite; preserve its full pixel palette.
const ART := "res://addons/hd2d_scene_tools/editor/art/"
static var atlas: Texture2D
static var entries: Dictionary={}
static var cache: Dictionary={}
func texture(key: String, _color: Color=Color.WHITE) -> Texture2D:
 if atlas==null:
  atlas=ImageTexture.create_from_image(Image.load_from_file(ART+"icons.png"))
  entries=JSON.parse_string(FileAccess.get_file_as_string(ART+"icons.json")).icons
 var name: String=key if entries.has(key) else "edit"
 if not cache.has(name):
  var frame: Dictionary=entries[name]
  var result := AtlasTexture.new();result.atlas=atlas
  result.region=Rect2(frame.x,frame.y,frame.w,frame.h);cache[name]=result
 return cache[name]
func key_for(value: String) -> String:
 var text := value.to_lower()
 if text in ["内置建筑","built-in buildings"]:return "generate"
 if text in ["一键生成","one-click","one-click generation"]:return "generate"
 for pair in [["collapse",["收起","collapse"]],["expand",["展开","expand"]],["import",["导入","import"]],["place",["摆放","放置","place"]],["check",["检查","check"]],["restore",["还原","恢复","restore","revert"]],["skin",["皮肤","skin"]],["search",["搜索","search"]]]:
  for word in pair[1]:
   if text.contains(word):return pair[0]
 for pair in [["terrain",["地形","terrain"]],["assets",["素材","assets","library","catalog"]],["scatter",["铺设","scatter","植物","道路"]],["character",["角色","character"]],["camera",["镜头","camera"]],["environment",["环境","environment"]],["music",["音乐","music"]]]:
  if text==pair[1][0] or text==pair[1][1]:return pair[0]
 for pair in [["new",["新建","创建","增加","new","create","add "]],["refresh",["重新","刷新","重试","refresh","retry","restart","recheck"]],["apply",["应用","检查","确认","使用此","apply","check","confirm","use this"]],["back",["返回","还原","恢复","上一步","上一页","back","return","restore","revert","previous"]],["next",["下一","前往","next","go to"]],["save",["保存","save","导出","export"]],["play",["预览","试听","播放","preview","play","audition"]],["close",["取消","关闭","删除","移除","cancel","close","remove","delete","stop"]],["folder",["位置","选择","打开","导入","收起","展开","location","choose","select","open","import","collapse","expand"]],["paint",["绘制","雕刻","升高","降低","平滑","平台","坡道","paint","sculpt","raise","lower","smooth","flatten","ramp"]],["assets",["素材","摆放","皮肤","assets","place","skin","workbench"]]]:
  for word in pair[1]:
   if text.contains(word):return pair[0]
 return "edit"
