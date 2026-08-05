class_name ShiftClock
extends RefCounted

## 근무는 22:00에 시작해 06:00에 끝난다. 자정을 넘긴다.
##
## 벽시계 시각(03:00)을 그대로 비교하면 "02:00 이후"가 22:00~23:59 구간을 잘못
## 판정한다. 그래서 모든 시각을 **근무 시작으로부터 경과한 분**으로 환산해 다룬다.
## 22:00 = 0, 00:00 = 120, 03:00 = 300, 06:00 = 480.

const SHIFT_START_HOUR := 22
const SHIFT_LENGTH_MINUTES := 480
const MINUTES_PER_HOUR := 60
const HOURS_PER_DAY := 24


## "HH:MM" 문자열을 근무 경과 분으로 환산한다.
static func parse(hhmm: String) -> int:
	var parts := hhmm.split(":")
	if parts.size() != 2:
		push_error("잘못된 시각 형식: %s" % hhmm)
		return 0
	return from_hour_minute(int(parts[0]), int(parts[1]))


static func from_hour_minute(hour: int, minute: int) -> int:
	var offset := hour - SHIFT_START_HOUR
	if offset < 0:
		offset += HOURS_PER_DAY
	return offset * MINUTES_PER_HOUR + minute


## 근무 경과 분을 "HH:MM" 표시 문자열로 되돌린다.
static func to_display(shift_minutes: int) -> String:
	var total := SHIFT_START_HOUR * MINUTES_PER_HOUR + shift_minutes
	var hour := (total / MINUTES_PER_HOUR) % HOURS_PER_DAY
	var minute := total % MINUTES_PER_HOUR
	return "%02d:%02d" % [hour, minute]


static func is_within_shift(shift_minutes: int) -> bool:
	return shift_minutes >= 0 and shift_minutes <= SHIFT_LENGTH_MINUTES
