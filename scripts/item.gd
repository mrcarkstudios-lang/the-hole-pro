class_name Item
extends Node3D
## A swallowable object in the city (prop, car, building, gold...).

var size: float = 0.2      # footprint (max of x/z)
var height: float = 0.2
var pts: int = 1
var mass: float = 1.0
var kind: String = ""
var special: String = ""   # "gold" for bonus items
var base_yaw: float = 0.0
var base_scale: Vector3 = Vector3.ONE
var leaning: bool = false
var falling: bool = false
var fall_t: float = 0.0
var fall_from: Vector3 = Vector3.ZERO
var fall_scale: Vector3 = Vector3.ONE
var fall_to: Node3D = null
var fall_dur: float = 0.55
# world life
var mover: int = 0          # 0 static, 1 vehicle (drives a lane), 2 pedestrian
var axis: int = 0           # vehicles: 0 drives along x, 1 along z
var dir: float = 1.0
var spd: float = 0.0
var home: Rect2 = Rect2()   # pedestrians: wander area
var heading: Vector2 = Vector2.ZERO
var turn_t: float = 0.0
var flee_t: float = 0.0
var body: Node3D = null
var phase: float = 0.0
var running: bool = false
var cur: float = 0.0        # vehicles: current speed
var lane: Dictionary = {}
var lock: int = -1          # sidewalk walkers: 0 walks along x, 1 along z
var cell: Vector2i = Vector2i(99999, 99999)
var big: bool = false       # buildings: no suction, tremble and crumble when eaten
var is_vehicle: bool = false
