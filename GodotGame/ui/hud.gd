extends Control

@onready var health_bar = $Content/BarsRow/HealthSection/HealthBar
@onready var stamina_bar: ProgressBar = $Content/BarsRow/StaminaSection/StaminaBar

@onready var _cd1: ColorRect = $Content/AttacksRow/Slot1/IconWrap1/Cooldown1
@onready var _cd2: ColorRect = $Content/AttacksRow/Slot2/IconWrap2/Cooldown2
@onready var _cd3: ColorRect = $Content/AttacksRow/Slot3/IconWrap3/Cooldown3
@onready var _cd4: ColorRect = $Content/AttacksRow/Slot4/IconWrap4/Cooldown4

@onready var _wraps: Array = [
	$Content/AttacksRow/Slot1/IconWrap1,
	$Content/AttacksRow/Slot2/IconWrap2,
	$Content/AttacksRow/Slot3/IconWrap3,
	$Content/AttacksRow/Slot4/IconWrap4,
]

func set_selected_slot(slot: int) -> void:
	for i in _wraps.size():
		if i == slot:
			_wraps[i].modulate = Color(1.0, 0.85, 0.2)
			_wraps[i].scale = Vector2(1.15, 1.15)
		else:
			_wraps[i].modulate = Color(0.4, 0.4, 0.4)
			_wraps[i].scale = Vector2(1.0, 1.0)

func set_slot_cooldown(slot: int, ratio: float) -> void:
	var cd: ColorRect = [_cd1, _cd2, _cd3, _cd4][slot]
	if ratio <= 0.01:
		cd.visible = false
		return
	cd.visible = true
	cd.anchor_top = 1.0 - ratio
	cd.anchor_bottom = 1.0
