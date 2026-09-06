extends RefCounted
## 场景加载探针（--check-tavern）：加载并实例化 game/scenes/tavern/tavern.tscn，
## 校验资源可加载、场景可实例化、网格/材质就位；用于自动化验证真实酒馆场景。

const TAVERN_SCENE := "res://game/scenes/tavern/tavern.tscn"


func run(driver: Node) -> void:
	var tree := driver.get_tree()
	print("[TAVERN] begin: scene-load check")
	await tree.process_frame
	var scene: PackedScene = load(TAVERN_SCENE)
	if scene == null:
		_fail(tree, "无法加载场景资源：" + TAVERN_SCENE)
		return
	var root: Node = scene.instantiate()
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
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				errors += 1
				print("[TAVERN] WARN: %s mesh 为空" % node.name)
		elif node is Light3D:
			lights += 1
		for child in node.get_children():
			stack.append(child)
	# 卸载探针场景，避免污染。
	root.queue_free()
	await tree.process_frame
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
