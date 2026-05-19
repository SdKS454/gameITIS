extends Object
class_name IsoHelper

static func grid_to_screen(grid_pos: Vector2i, iso_config: IsoConfig) -> Vector2:
	var x = grid_pos.x
	var y = grid_pos.y

	var screen_x = (x - y) * iso_config.tile_width * 0.5
	var screen_y = (x + y) * iso_config.tile_height * 0.5

	return Vector2(screen_x, screen_y)

static func screen_to_grid(screen_pos: Vector2, iso_config: IsoConfig) -> Vector2i:
	var tw = iso_config.tile_width * 0.5
	var th = iso_config.tile_height * 0.5

	var x = screen_pos.x
	var y = screen_pos.y

	var grid_x = (x / tw + y / th) * 0.5
	var grid_y = (y / th - x / tw) * 0.5

	return Vector2i(int(round(grid_x)), int(round(grid_y)))
