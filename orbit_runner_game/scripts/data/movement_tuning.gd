class_name MovementTuning
extends Resource
## Tunable movement values (prototype hypotheses, adjusted by playtesting).
## Distances in metres, speeds in m/s, times in seconds.

@export_group("Ground")
@export var run_speed: float = 8.0
@export var ground_acceleration: float = 38.0
@export var ground_deceleration: float = 48.0
@export var turn_acceleration: float = 70.0

@export_group("Air")
@export var air_acceleration: float = 20.0
@export var air_deceleration: float = 6.0
@export var gravity_up: float = 28.0
@export var gravity_down: float = 45.0
@export var max_fall_speed: float = 32.0
@export var jump_velocity: float = 11.5
## Fraction of upward speed kept when the jump button is released early.
@export var jump_cut: float = 0.45
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.13

@export_group("Slide / long jump")
@export var slide_speed: float = 11.0
@export var slide_duration: float = 0.6
@export var slide_friction: float = 9.0
@export var slide_cooldown: float = 0.25
@export var long_jump_speed: float = 12.5
@export var long_jump_velocity: float = 9.5

@export_group("Air dash")
@export var dash_speed: float = 15.0
@export var dash_duration: float = 0.18
@export var dash_lift: float = 1.5
@export var dash_exit_speed: float = 10.0

@export_group("Kinetic yo-yo")
@export var yoyo_bounce_velocity: float = 16.0
@export var yoyo_disc_lifetime: float = 1.5
@export var yoyo_ground_distance: float = 4.0
@export var yoyo_air_drop: float = 1.4
@export var yoyo_air_lead: float = 0.32
@export var yoyo_flight_time: float = 0.14
@export var yoyo_return_time: float = 0.3

@export_group("Feel")
@export var rotation_speed: float = 14.0
@export var boost_decay: float = 4.0
