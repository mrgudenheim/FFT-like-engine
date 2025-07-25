class_name PassiveEffect
extends Resource

@export var hit_chance_modifier_user: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var hit_chance_modifier_targeted: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var power_modifier_user: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var power_modifier_targeted: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var evade_modifier_user: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var evade_modifier_targeted: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)
@export var ct_gain_modifier: Modifier = Modifier.new(1.0, Modifier.ModifierType.MULT)

@export var ai_strategy: UnitAi.Strategy = UnitAi.Strategy.PLAYER
@export var added_actions: Array[Action] = []
@export var added_equipment_types: Array[int] = [] # equip x support abilities
@export var stat_modifiers: Dictionary[UnitData.StatType, Modifier] = {}

@export var element_absorb: Array[Action.ElementTypes] = []
@export var element_cancel: Array[Action.ElementTypes] = []
@export var element_half: Array[Action.ElementTypes] = []
@export var element_weakness: Array[Action.ElementTypes] = []
@export var element_strengthen: Array[Action.ElementTypes] = []

@export var status_always: PackedInt32Array = []
@export var status_immune: PackedInt32Array = []
@export var status_start: PackedInt32Array = []

@export var can_react: bool = true
@export var target_can_react: bool = true
@export var nullify_targeted: bool = false # ignore_attacks flag

# TODO affects targeting - float - can attack 1 higher, jump 1 higher, ignore depth and terrain cost, counts as 1 higher when being targeted, chicken/frog counts as further? maybe targeting just checks sprite height var
# TODO reflect
# TODO undead healing -> damage
# TODO invite, charm
# TODO modify action - short charge, no charge, half mp, poach (secondary action?), tame (secondary action?) 

# https://ffhacktics.com/wiki/Target_XA_affecting_Statuses_(Physical)
# https://ffhacktics.com/wiki/Target%27s_Status_Affecting_XA_(Magical)
# https://ffhacktics.com/wiki/Evasion_Changes_due_to_Statuses
# evade also affected by transparent, concentrate, dark or confuse, on user


#STATUS
#Execute action - charging, performing, jumping, death sentence, Regen, poison, reraise, undead, 
#Affect CT gain - slow, haste, stop, freeze CT flag
#Affect skillet/actions available - blood suck, frog, chicken
#Affect control - charm, invite, berserk, confuse, blood suck
#Affect evade - darkness, confuse, transparent, defending, don't act, sleep, stop, charging, performing
#Affect hit chance - protect, shell, frog, chicken, sleep, etc.
#Affect calculation - protect, shell, faith/innocent, charging, undead, (golem)
#Affect elemental affinity - float, (oil - in addition to element)
#Affect usable actions - silence, don't act/move
#Counts as defeated - dead, crystal, petrify, poached, etc
#Affects ai - critical, transparent, do_not_target flag? (Confusion/Transparent/Charm/Sleep)
#affects targeting - float, reflect
#Affect reactions - transparent, dont act, sleep, can_react flag
# ignore_attacks flag - attacks do not animate or do anything
#
#Reaction/Support/Move:
#Affect CT gain - 
#Affect skillet/actions - defend, equip change, two swords, beast master
#Affect control - 
#Affect evade - concentrate, abandon, blade grasp, monster talk
#Affect calculation - Atk Up, Ma Up, Def Up, MDef up, two hands, martial arts
#Affect elemental affinity - 
#Affect usable actions - 
#Counts as defeated - 
#Affects ai - 
#affects targeting - throw item, ignore height, jump (lancer abilities)
#Affect reactions - 
#Affects equipment - Equip x
#
#jp up, exp up, 
#maintenance, 
#affects stat - move+/jump+, max_hp up, item attributes
#affects action data - short charge, no charge, half mp, poach (secondary action?), tame (secondary action?) 
