class_name DungeonGenerator
extends RefCounted
## Builds a floor layout: random non-overlapping rooms joined by 2-wide corridors.
## Rooms are connected with a minimum spanning tree, plus a few extra corridors for loops.
## Result: {"w", "h", "cells" (PackedByteArray, 1 = floor), "rooms" (Array[Rect2i])}.
## rooms[0] is the start room.

const FLOOR := 1

var _w := 0
var _h := 0
var _cells := PackedByteArray()


func generate(w: int, h: int, max_rooms: int, rng: RandomNumberGenerator) -> Dictionary:
	var result := {}
	for attempt in 25:
		result = _try_generate(w, h, max_rooms, rng)
		if (result["rooms"] as Array).size() >= 3:
			break
	return result


func _try_generate(w: int, h: int, max_rooms: int, rng: RandomNumberGenerator) -> Dictionary:
	_w = w
	_h = h
	_cells = PackedByteArray()
	_cells.resize(w * h)
	_cells.fill(0)

	var rooms: Array[Rect2i] = []
	for i in 300:
		if rooms.size() >= max_rooms:
			break
		var rw := rng.randi_range(6, 14)
		var rh := rng.randi_range(5, 10)
		var r := Rect2i(rng.randi_range(2, w - rw - 3), rng.randi_range(2, h - rh - 3), rw, rh)
		var overlaps := false
		for o in rooms:
			if r.grow(2).intersects(o):
				overlaps = true
				break
		if overlaps:
			continue
		rooms.append(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_set_floor(x, y)

	# Connect all rooms (Prim's MST on room centers).
	var connected: Array[int] = [0]
	var remaining: Array[int] = []
	for i in range(1, rooms.size()):
		remaining.append(i)
	while remaining.size() > 0:
		var best_a := -1
		var best_b := -1
		var best_d := INF
		for a in connected:
			for b in remaining:
				var d := Vector2(rooms[a].get_center()).distance_squared_to(Vector2(rooms[b].get_center()))
				if d < best_d:
					best_d = d
					best_a = a
					best_b = b
		_carve_corridor(rooms[best_a].get_center(), rooms[best_b].get_center(), rng)
		connected.append(best_b)
		remaining.erase(best_b)

	# A couple of extra corridors so the map has loops (better for kiting enemies).
	var extra := int(rooms.size() / 3.0)
	for i in extra:
		var a := rng.randi() % rooms.size()
		var b := rng.randi() % rooms.size()
		if a != b:
			_carve_corridor(rooms[a].get_center(), rooms[b].get_center(), rng)

	return {"w": w, "h": h, "cells": _cells, "rooms": rooms}


func _set_floor(x: int, y: int) -> void:
	# Keep a 1-tile solid border around the map.
	if x <= 0 or y <= 0 or x >= _w - 1 or y >= _h - 1:
		return
	_cells[y * _w + x] = FLOOR


func _carve_corridor(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	if rng.randf() < 0.5:
		_carve_h(a.x, b.x, a.y)
		_carve_v(a.y, b.y, b.x)
	else:
		_carve_v(a.y, b.y, a.x)
		_carve_h(a.x, b.x, b.y)


func _carve_h(x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 2):
		_set_floor(x, y)
		_set_floor(x, y + 1)


func _carve_v(y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 2):
		_set_floor(x, y)
		_set_floor(x + 1, y)
