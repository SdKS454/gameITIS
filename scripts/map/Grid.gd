extends Node2D
class_name Grid

@export var width: int = 10
@export var height: int = 10
@export var tile_scene: PackedScene
@export var iso_config: IsoConfig
@export var unit_manager: UnitManager

var tiles: Dictionary = {}
var astar := AStarGrid2D.new()

func _ready() -> void:
	generate_grid()
	setup_astar()

func generate_grid() -> void:
	for x in range(width):
		for y in range(height):
			create_tile(Vector2i(x, y))

func create_tile(coord: Vector2i) -> void:
	var tile = tile_scene.instantiate()
	tile.coord = coord
	tile.position = IsoHelper.grid_to_screen(Vector2i(coord.x, coord.y), iso_config)
	tile.z_index = coord.x + coord.y
	tiles[coord] = tile
	add_child(tile)

func get_tile(coord: Vector2i) -> Tile:
	return tiles.get(coord, null)

func is_in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < width and coord.y >= 0 and coord.y < height

func get_neighbor_coords(coord: Vector2i) -> Array[Vector2i]:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var result: Array[Vector2i] = []
	for d in dirs:
		var n = coord + d
		if is_in_bounds(n):
			result.append(n)
	return result

func get_bounds() -> Rect2:
	if tiles.is_empty():
		return Rect2()
	var min_pos: Vector2 = Vector2(INF, INF)
	var max_pos: Vector2 = Vector2(-INF, -INF)
	for tile in tiles.values():
		var pos: Vector2 = tile.position
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	return Rect2(min_pos, max_pos - min_pos)

func show_hover(cell: Vector2i):
	var tile := get_tile(cell)
	if tile == null:
		return
	$HoverHighlight.visible = true
	$HoverHighlight.position = tile.position

func hide_hover():
	$HoverHighlight.visible = false

func show_selected(cell: Vector2i):
	var tile := get_tile(cell)
	if tile == null:
		return
	$SelectedHighlight.visible = true
	$SelectedHighlight.position = tile.position

func hide_selected():
	$SelectedHighlight.visible = false

func show_reachable(cells: Array[Vector2i]):
	for cell in cells:
		var tile := get_tile(cell)
		if tile == null:
			continue
		if tile.state == Tile.State.NORMAL:
			tile.set_state(Tile.State.REACHABLE)

func show_action_targets(cells: Array[Vector2i]):
	for cell in cells:
		var tile := get_tile(cell)
		if tile == null:
			continue
		tile.set_state(Tile.State.ACTION_TARGET)

func show_intents(cells: Array[Vector2i]):
	for cell in cells:
		var tile := get_tile(cell)
		if tile == null:
			continue
		if tile.state == Tile.State.NORMAL:
			tile.set_state(Tile.State.INTENT)

func clear_reachable():
	for tile in tiles.values():
		if tile.state == Tile.State.REACHABLE:
			tile.set_state(Tile.State.NORMAL)

func clear_action_targets():
	for tile in tiles.values():
		if tile.state == Tile.State.ACTION_TARGET:
			tile.set_state(Tile.State.NORMAL)

func clear_intents():
	for tile in tiles.values():
		if tile.state == Tile.State.INTENT:
			tile.set_state(Tile.State.NORMAL)

func clear_all_highlights():
	for tile in tiles.values():
		tile.set_state(Tile.State.NORMAL)
	refresh_ownership_visuals()

func refresh_ownership_visuals():
	for tile in tiles.values():
		tile.clear_owner_team()

	if unit_manager == null:
		return

	for unit in unit_manager.units:
		if unit == null or unit.is_dead():
			continue
		var tile := get_tile(unit.cell)
		if tile == null:
			continue
		tile.set_owner_team(unit.team)

func setup_astar():
	astar.region = Rect2i(Vector2i(0, 0), Vector2i(width, height))
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	_clear_astar_solids()
	_apply_occupied_to_astar(from, to)
	var path := astar.get_id_path(from, to)
	var result: Array[Vector2i] = []
	for p in path:
		result.append(Vector2i(p))
	return result

func _clear_astar_solids():
	for x in range(width):
		for y in range(height):
			astar.set_point_solid(Vector2i(x, y), false)

func _apply_occupied_to_astar(from: Vector2i, to: Vector2i):
	for cell in unit_manager.occupied.keys():
		if cell == from or cell == to:
			continue
		astar.set_point_solid(cell, true)
