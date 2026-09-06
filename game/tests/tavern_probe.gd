extends RefCounted
## 场景加载探针（--check-tavern）：校验真实酒馆 tavern.tscn 可加载/实例化。
## 主场景已是酒馆时直接校验当前场景；否则加载一份实例。统计网格/灯光并检查空网格。

const TAVERN_SCENE := "res://game/scenes/tavern/tavern.tscn"


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[TAVERN] begin: scene-load check")
	await tree.process_frame
	var root: Node = tree.current_scene
	if root == null or root.get("name") != "Tavern":
		var scene: PackedScene = load(TAVERN_SCENE)
		if scene == null:
			_fail(tree, "无法加载场景资源：" + TAVERN_SCENE)
			return
		root = scene.instantiate()
		if root == null:
			_fail(tree, "场景实例化失败：" + TAVERN_SCENE)
			return
		tree.current_scene.add_child(root)
		await tree.process_frame
	await tree.process_frame
	var mesh_instances := 0
	var lights := 0
	var errors := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			mesh_instances += 1
			if (node as MeshInstance3D).mesh == null:
				errors += 1
				print("[TAVERN] WARN: %s mesh 为空" % node.name)
		elif node is Light3D:
			lights += 1
		for child in node.get_children():
			stack.append(child)
	if errors > 0:
		_fail(tree, "存在 %d 个无网格 MeshInstance3D" % errors)
		return
	print("[TAVERN] PASS: 加载/实例化 OK | MeshInstance=%d | Light=%d" % [mesh_instances, lights])
	await tree.process_frame
	tree.quit(0)


func _fail(tree: SceneTree, why: String) -> void:
	print("[TAVERN] FAIL: %s" % why)
	push_error("[TAVERN] FAIL: %s" % why)
	await tree.process_frame
	tree.quit(1)
