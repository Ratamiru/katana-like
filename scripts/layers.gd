class_name Layers
extends RefCounted

## Физические слои проекта — одно место с именами вместо «магических» чисел.
## Имена слоёв в редакторе (Project Settings → Layer Names → 2D Physics) — те же.
##
##   collision_layer — «на каких слоях я лежу» (ярлык объекта);
##   collision_mask  — «в какие слои я упираюсь / кого вижу» (фильтр).
## Тело A сталкивается с B, если в МАСКЕ A есть СЛОЙ B. Поэтому одно препятствие
## может держать игрока и пропускать тень — у них разные маски.
##
## Слой → значение бита (для масок значения складываются: WORLD | PLATFORMS = 3):
const WORLD := 1             # 1: тайлы (пол, стены) — держит всех, включая тень
const PLATFORMS := 2         # 2: one-way платформы (можно спрыгнуть)
const ENEMIES := 4           # 3: враги, турели
const PLAYER := 8            # 4: игрок (тело; тень — ни на каком слое)
const PROPS := 16            # 5: ударяемые пропы, рычаги (Area2D)
const SHADOW_PASSABLE := 32  # 6: двери, окна, решётки — держат всех, КРОМЕ тени

## Готовые маски:
const SOLID := WORLD | SHADOW_PASSABLE          # всё, что держит тела, останавливает пули/свет/взгляд
const BODY_MASK := WORLD | PLATFORMS | SHADOW_PASSABLE # игрок и враги
const SHADOW_MASK := WORLD | PLATFORMS          # тень: двери/окна не мешают, пол держит
