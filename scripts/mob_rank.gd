extends Object
## Neocron-style mob ranking. Every creature carries a level; its hit
## points, damage and experience reward all derive from it, and the
## level is displayed next to its name as a rank ("14/14", "38/38**").
##
## Stars mark danger tiers relative to the player's own ceiling:
##   no star   below 25
##   *         25 to 39
##   **        40 to 54
##   ***       55 and above

const HP_PER_LEVEL := 0.06      # +6% base HP per level above 1
const DMG_PER_LEVEL := 0.06     # +6% base damage per level above 1
const XP_PER_LEVEL := 0.11      # +11% base XP per level above 1


static func hp_mult(level: int) -> float:
	return 1.0 + float(level - 1) * HP_PER_LEVEL


static func damage_mult(level: int) -> float:
	return 1.0 + float(level - 1) * DMG_PER_LEVEL


static func xp_mult(level: int) -> float:
	return 1.0 + float(level - 1) * XP_PER_LEVEL


static func stars(level: int) -> String:
	if level >= 55:
		return "***"
	if level >= 40:
		return "**"
	if level >= 25:
		return "*"
	return ""


## Mob rank plate. In Neocron, NPCs and mobs merge their two ranks
## into a single number: a 60/60 creature simply reads "60".
static func mob_rank_text(level: int) -> String:
	return "%d%s" % [level, stars(level)]


## Runner rank plate: combat rank / base rank, the two-number form
## reserved for players.
static func runner_rank_text(combat_rank: int, base_rank: int) -> String:
	return "%d/%d%s" % [combat_rank, base_rank, stars(combat_rank)]


## Experience factor from the rank gap, following Neocron's rule: the
## reward peaks against a mob ranked 10 above the runner's combat rank
## and falls off as the gap widens either way, so farming vermin far
## below your rank stops paying.
static func xp_factor(mob_rank: int, runner_combat_rank: int) -> float:
	var gap := float(mob_rank - runner_combat_rank)
	return clampf(1.0 - absf(gap - 10.0) * 0.045, 0.02, 1.0)


## Applies the whole calibration to a mob node in one call: metadata
## for the HUD (name, rank, level) and the scaled hp/xp values.
static func apply(node: Node, mob_name: String, level: int, base_hp: float, base_xp: int) -> void:
	var lv := maxi(1, level)
	var hp := roundf(base_hp * hp_mult(lv) * 10.0) / 10.0
	node.set_meta("mob_level", lv)
	node.set_meta("mob_name", mob_name)
	node.set_meta("mob_rank", mob_rank_text(lv))
	node.set_meta("hp", hp)
	node.set_meta("hp_max", hp)
	node.set_meta("xp", int(roundf(float(base_xp) * xp_mult(lv))))


## Picks a level inside a range, weighted toward the low end so that
## high-rank specimens stay uncommon.
static func roll_level(low: int, high: int) -> int:
	if high <= low:
		return low
	var t := randf()
	t = t * t   # bias toward the bottom of the bracket
	return low + int(roundf(t * float(high - low)))
