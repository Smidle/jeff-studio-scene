@tool
extends RefCounted
signal progress(done: int, total: int, label: String)
var controller
var error := ""
var serial := 0
var busy := false
var catalog := {}

func read_catalog() -> Dictionary:
 error=""
 var path: String=controller.shared_library.root_path().path_join("world-index.json")
 if not FileAccess.file_exists(path):
  error="尚未安装案例 6 地图配方，请安装 0.4.4 的第三个素材包。";catalog={};return catalog
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary or value.get("version","")!="0.4.4" or not value.get("files") is Array:
  error="地图配方索引无效或版本不匹配。";catalog={};return catalog
 for file in value.files:
  if not controller.shared_library.safe_relative(str(file.get("path",""))) or not controller.shared_library.safe_relative(str(file.get("source",""))) or str(file.get("sha256","")).length()!=64:
   error="地图配方包含无效文件记录。";catalog={};return catalog
 catalog=value
 return catalog

func cancel() -> void: serial+=1

func prepare() -> String:
 if busy: return ""
 read_catalog()
 if catalog.is_empty(): return ""
 serial+=1;var ticket := serial
 var root: String=controller.shared_library.root_path()
 var current := func(): return serial==ticket and is_instance_valid(controller) and controller.shared_library!=null and root==controller.shared_library.root_path()
 busy=true
 var total: int=catalog.files.size();var index := 0
 for file in catalog.files:
  if not current.call(): busy=false;return ""
  var source: String=root.path_join(file.source)
  var dest: String=ProjectSettings.globalize_path("res://"+str(file.path))
  if FileAccess.file_exists(dest):
   if FileAccess.get_sha256(dest)!=file.sha256:
    error="工程中已有不同内容，未覆盖："+str(file.path);break
  else:
   if not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=file.sha256:
    error="共享库文件缺失或校验失败："+str(file.source);break
   DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
   var temporary := dest.get_base_dir().path_join(".world-copy-"+str(OS.get_process_id()))
   if DirAccess.copy_absolute(source,temporary)!=OK or FileAccess.get_sha256(temporary)!=file.sha256 or DirAccess.rename_absolute(temporary,dest)!=OK:
    error="地图素材复制失败："+str(file.path);break
  if str(file.path).get_extension()=="png" and not FileAccess.file_exists(dest+".import"):
   var config := ConfigFile.new();config.set_value("remap","importer","texture");config.set_value("remap","type","CompressedTexture2D")
   config.set_value("params","compress/mode",0);config.set_value("params","mipmaps/generate",true);config.set_value("params","detect_3d/compress_to",0)
   config.set_value("params","compress/normal_map",1 if "normal" in str(file.path).to_lower() else 2)
   config.save(dest+".import")
  index+=1
  if index%12==0:
   progress.emit(index,total,str(file.path));await controller.get_tree().process_frame
 if error.is_empty() and current.call():
  var status := func(text: String): progress.emit(total,total,text)
  var resource: Resource=await controller.shared_library.wait_import("res://"+str(catalog.probe),catalog.files,current,status)
  if not current.call(): busy=false;return ""
  if resource==null: error=controller.shared_library.error
 busy=false
 if not current.call() or not error.is_empty(): return ""
 progress.emit(total,total,"地图配方已准备，可以创建独立制作副本。")
 return "res://"+str(catalog.recipe)
