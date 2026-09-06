extends RefCounted
## 资产探针（--probe-wall）：加载墙板 FBX 场景并打印各 MeshInstance 的本地包围盒，
## 用于确定上墙时的缩放与摆放（headless 无法预览，靠尺寸数据）。

const WALL_SCENE := "res://game/art/tavern/medieval+wall+panels+3d+model/tripo_convert_8fb98191-fde4-4b97-8b29-9399f46a52d6.fbx"


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	await tree.process_frame
	var scene: PackedScene = load(WALL_SCENE)
	if scene == null:
		print("[WALL] FAIL: 无法加载墙板场景")
		tree.quit(1)
		return
	var root: Node = scene.instantiate()
	tree.current_scene.add_child(root)
	await tree.process_frame
	var stack: Array[Node] = [root]
	var count := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var aabb := mi.mesh.get_aabb() if mi.mesh != null else AABB()
			var size := aabb.size
			var origin := mi.global_position
			print("[WALL] %s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f)" % [
				mi.get_path(), origin.x, origin.y, origin.z, size.x, size.y, size.z])
			count += 1
		for child in node.get_children():
			stack.append(child)
	print("[WALL] PASS: %d 个 MeshInstance" % count)
	root.queue_free()
	await tree.process_frame
	tree.quit(0)
