# Architecture — Katana-like

2D-платформер с ближним боем в духе Katana Zero. Godot 4.7, Forward Plus, физика Jolt (3D; в 2D — стандартная).

> Этот файл обновляется при каждом изменении архитектуры или механик — см. раздел «Журнал изменений» внизу.

## Структура проекта

| Путь | Назначение |
|---|---|
| `world.tscn` | Главная сцена: `TileMapLayer` уровня, игрок, враги, `BulletWorld` |
| `character.tscn` | Игрок (`CharacterBody2D`), камера, компонент атаки, `ShadowAbility` |
| `shadow.tscn` | Тень — второе тело игрока (фиолетовая, полупрозрачная), `GrabAttack`, своя камера |
| `enemy_armored.tscn` | Бронированный враг (серый, щит спереди) |
| `turret.tscn` | Турель (`StaticBody2D`): основание, поворотный ствол `Barrel` с `Muzzle` |
| `enemy.tscn` | Враг ближнего боя (красный плейсхолдер), компонент атаки |
| `scripts/fighter.gd` | `Fighter` — общий базовый класс бойца: движение, здоровье, смерть |
| `scripts/player_pawn.gd` | `PlayerPawn` (`extends Fighter`) — тело, которым может управлять игрок; передача управления |
| `scripts/character.gd` | Основное тело игрока (`extends PlayerPawn`): катана в сторону мыши |
| `scripts/shadow.gd` | `Shadow` (`extends PlayerPawn`): тело-тень, на `attack` — захват |
| `scripts/shadow_ability.gd` | `ShadowAbility` — компонент игрока: цикл тени (спавн, замедление, передача управления, кулдаун) |
| `scripts/grab_attack.gd` | `GrabAttack` — компонент захвата (shape query, `target.grab(hold_time)`) |
| `scripts/turret.gd` | `Turret` — стационарный враг, очереди пуль через `BulletWorld`, заклинивает от захвата тенью |
| `scripts/enemy_armored.gd` | Бронированный враг (`extends Enemy`): блок спереди, уязвим сзади |
| `scripts/enemy.gd` | `Enemy` (`extends Fighter`): примитивный AI (IDLE → CHASE → ATTACK, STUNNED после клинча), по умолчанию ближний бой |
| `enemy_shooter.tscn` | Стрелок (оранжевый плейсхолдер), без `MeleeAttack` |
| `scripts/enemy_shooter.gd` | Стрелок (`extends Enemy`): держит дистанцию, стреляет через `BulletWorld` |
| `scripts/bullet_world.gd` | `BulletWorld` — все пули уровня в packed-массивах, аффекторы (отражение и т.п.) |
| `scripts/juice.gd` | Autoload `Juice` — сервис «сочности» (замедление времени, тряска камеры) |
| `melee_attack.gd` | `MeleeAttack` — компонент удара (Area2D-хитбокс, кулдаун), к мыши или в заданном направлении |
| `scripts/hits/hit_info.gd` | `HitInfo` — данные одного попадания (кто, куда, откуда, урон, вид, убил ли) |
| `scripts/hits/hit_reaction.gd` | `HitReaction` — базовая реакция на удар + `dispatch()` рассылки |
| `scripts/hits/hit_effect.gd` | `HitEffect` — реакция «заспавнить эффект» (кровь, искры…) |
| `effects/` | Сцены эффектов: `blood.tscn`, `blood_kill.tscn`, `sparks.tscn` (`CPUParticles2D`, one-shot) |
| `scripts/create_tiles.gd` | EditorScript: генерирует `art/placeholder_tiles.png` (4 цветных тайла 32×32) |
| `art/` | Графика (пока плейсхолдеры) |

## Физические слои

| Слой | Что на нём |
|---|---|
| 1 | Сплошные тайлы (пол, стены) |
| 2 | One-way платформы, сквозь которые можно спрыгнуть (`down` + `jump`) |
| 3 (значение `4`) | Враги (в т.ч. турели) |
| 4 (значение `8`) | Игрок |
| 5 (значение `16`) | Пропы, которые можно ударить (пока нет) |
| — | Тень: `collision_layer = 0` (её никто не видит и не бьёт), `collision_mask = 3` |

- Игрок: `collision_layer = 8`, `collision_mask = 3`, его `MeleeAttack.hit_mask = 20` (бьёт врагов и пропы).
- Враг: `collision_layer = 4`, `collision_mask = 3`, его `MeleeAttack.hit_mask = 8` (бьёт игрока).
- Пули (`BulletWorld`) останавливаются о слой 1 (`world_mask`), сквозь one-way платформы пролетают; ранят слои из своего `hit_mask` (пули стрелка — `8`, отбитые — `20`).
- Игрок и враги **не сталкиваются** телами (маски только на мир) — проходят друг сквозь друга, как в Katana Zero.

## Инпут

| Action | Клавиша |
|---|---|
| `forward` / `backward` | D / A |
| `jump` | Space |
| `down` | S |
| `attack` | ЛКМ (действие текущего тела: катана / захват) |
| `shadow` | ПКМ (выпустить тень / отменить) |

## Бойцы: `Fighter` (`scripts/fighter.gd`)

Игрок и враги наследуются от одного класса `Fighter`, поэтому двигаются по одним правилам. Наследник **не трогает физику**, он только заполняет «намерения» в `_update_intent(delta)`:

- `move_dir` — направление по X (-1..1);
- `jump_requested` — хочет прыгнуть в этом кадре (сбрасывается после обработки);
- `drop_requested` — вместе с прыжком означает спрыгивание сквозь платформу.

`facing` (±1) — куда смотрит боец: обновляется по знаку `move_dir`, враги ещё и разворачиваются к игроку (см. «Враг»). Нужен броне.

`unscaled_time` — боец живёт в реальном времени: `delta` делится на `Engine.time_scale`, скорость перед `move_and_slide()` умножается на `1/time_scale` и после делится обратно. Используется тенью, чтобы она не замедлялась вместе с миром.

`take_damage(amount, from) -> bool` — `true`, если урон прошёл; `false` — заблокирован (броня) или цель мертва.
`_physics_process` (в базе), порядок:

1. `_update_intent(delta)` — наследник выставляет намерения.
2. Гравитация, если не на полу.
3. **Скольжение по стене**: если `is_on_wall_only()` (в воздухе и упирается в стену), скорость падения ограничивается `wall_slide_max_speed`.
4. Если `jump_requested` (приоритет сверху вниз):
   - на полу + `drop_requested` → спрыгивание: маска слоя 2 выключается на `DROP_THROUGH_TIME` (0.25 с, через `create_timer`);
   - на полу → обычный прыжок `jump_velocity`;
   - на стене → **отпрыжка**: `velocity = (wall_normal.x * wall_jump_velocity.x, wall_jump_velocity.y)`.
5. Горизонталь: пока `_control_lock > 0` (после отпрыжки — `wall_jump_lock_time`, после удара/клинча — `knockback_time`) `move_dir` игнорируется. Иначе — мгновенная скорость `speed * move_dir` / мгновенная остановка.
6. `move_and_slide()`.

Здоровье: `take_damage(amount, from)` (его вызывает `MeleeAttack`, `from` — позиция атакующего) → красная вспышка, сигнал `damaged`, **отбрасывание** `apply_knockback(from, knockback)`; при `health <= 0` → `is_dead`, сигнал `died`, виртуальный `_die()` (по умолчанию `queue_free()`).

`apply_knockback(from, force)` — скорость `(±force.x, force.y)` в сторону от `from` + блокировка управления.

`is_on_drop_platform()` — стоит ли на one-way платформе (луч вниз длиной `FLOOR_PROBE` по маске слоя 2). Нужен AI, чтобы решить, можно ли спрыгнуть.

`melee_attack` — `$MeleeAttack` через `get_node_or_null`: у стрелка его нет, код `Fighter` это учитывает.

`has_platform_above()` — есть ли над головой one-way платформа, на которую можно запрыгнуть с места. Луч идёт сверху вниз: от `feet_y - 0.9 * get_jump_height()` до чуть выше ног, чтобы попасть в верхнюю грань платформы. `get_jump_height() = jump_velocity² / (2·g)` (≈ 82 px при стандартной гравитации 980). Половина роста берётся из формы ноды `$Collision` — она обязательна у каждого `Fighter`.

`_flash(color, time)` — окрашивает бойца и плавно возвращает цвет; один tween на бойца, новая вспышка перебивает старую.

### Клинч

Если удар попадает в бойца, который **сам сейчас бьёт** (`is_attacking()`), урона нет — вместо этого `attacker.clinch(target)`:

1. оба `MeleeAttack.cancel()` — хитбоксы гаснут, второй удар уже никого не заденет;
2. у обоих вызывается виртуальный `_on_clinch(other)`: по умолчанию белая вспышка + расталкивание `clinch_knockback`, сигнал `clinched`.

`is_attacking()` по умолчанию = `melee_attack.is_active()` (`false`, если `MeleeAttack` нет). Враг расширяет его концом замаха (см. ниже), иначе поймать одновременный удар почти невозможно.

Замечание: `is_on_wall()` срабатывает только когда боец реально двигается в стену, т.е. для скольжения/отпрыжки нужно держать направление к стене. One-way платформы боковых коллизий не дают.

### Параметры (`@export`, настраиваются в инспекторе для каждой сцены)

| Параметр | По умолчанию | Смысл |
|---|---|---|
| `max_health` | 30 (враг: 20 = два удара игрока) | Здоровье |
| `speed` | 300 (враг: 180) | Скорость бега |
| `jump_velocity` | -400 | Скорость прыжка |
| `wall_jump_velocity` | (350, -400) | Отталкивание от стены по X и вверх по Y |
| `wall_slide_max_speed` | 100 | Макс. скорость сползания по стене |
| `wall_jump_lock_time` | 0.15 с | Блокировка `move_dir` после отпрыжки |
| `knockback` | (250, -150) | Отбрасывание при получении удара |
| `knockback_time` | 0.2 с | Блокировка `move_dir` после удара/клинча |
| `clinch_knockback` | (300, -120) | Расталкивание при клинче |

## Управление телами: `PlayerPawn` (`scripts/player_pawn.gd`)

Игрок может управлять несколькими телами (основное тело, тень). Управляемое тело **ровно одно**, его хранит статическая ссылка `PlayerPawn.possessed` — это «булеан без рассинхрона»: не бывает двух управляемых тел или ни одного.

- `PlayerPawn.possess(pawn)` — передать управление: меняет `possessed`, включает и делает текущей `Camera2D` этого тела (`reset_smoothing`, чтобы не было проезда).
- `is_possessed()` — `possessed == self`.
- `_update_intent`: управляемое тело читает инпут (`backward/forward`, `jump`, `down`), остальные получают нулевые намерения — стоят, физика работает.
- `_unhandled_input`: `attack` → `_primary_action()` только у управляемого тела. У каждого тела своё действие.
- `_exit_tree`: если удаляется управляемое тело — `possessed = null`.

## Игрок (`scripts/character.gd`)

- `extends PlayerPawn`; в `_ready` добавляется в группу `player` (по ней его находят враги) и забирает управление себе (`possess(self)` — важно при перезагрузке уровня, т.к. static переживает её).
- `_primary_action()` → `melee_attack.attack()` (к мыши).
- Сок: `melee_attack.hit_landed(hit)` → по врагу (цель в группе `enemy` — `Enemy` и `Turret` добавляют себя в `_ready`): `hit.blocked` → отдача игроку (`knockback × 0.6`) + `Juice.shake(0.2)`; `hit.killed` → `Juice.kill()`; иначе `Juice.hit()`. Сигнал `clinched` → `Juice.clinch()`.
- `_die()` → перезапуск текущей сцены (временно).

## Тень: `ShadowAbility` + `Shadow` + `GrabAttack`

**`ShadowAbility`** (`scripts/shadow_ability.gd`) — дочерний компонент основного тела. Состояния:

```
READY ──[shadow]──► CONTROLLING ──[attack: захват]──► HOLDING ──[hold_time]──► COOLDOWN ──[cooldown]──► READY
						│                                                           ▲
						└──[shadow ещё раз / max_control_time]──────────────────────┘
```

- **CONTROLLING** — тень спавнится у тела; `Juice.hold_time_scale(&"shadow", world_time_scale 0.4)`; `PlayerPawn.possess(shadow)`. Основное тело стоит и **уязвимо** — враги продолжают его атаковать. Длится до `max_control_time` (3 реальных сек).
- **HOLDING** — тень схватила врага: `release_time_scale`, управление сразу возвращается телу; тень держит врага `GrabAttack.hold_time` (2 с игрового времени), потом `vanish()`.
- **COOLDOWN** — тени нет, `cooldown` (3 с), затем READY.
- Отмена (`shadow` ещё раз) или таймаут — тень исчезает без захвата, управление и время возвращаются, кулдаун.
- `_exit_tree` снимает удержание времени — мир не останется замедленным после смерти/перезагрузки.
- Сигнал `state_changed(state)` — для будущего HUD.

**`Shadow`** (`scripts/shadow.gd`, `shadow.tscn`) — `extends PlayerPawn`: та же физика движения (бег, прыжки, стены), `speed` 340, `unscaled_time = true`, слой 0, неуязвима. Вместо `MeleeAttack` — `GrabAttack`; `_primary_action()` → `grab_attack.attack()`. При захвате прилипает к цели и шлёт `grabbed(target)`. Своя `Camera2D` (в сцене `enabled = false`, включается при `possess`).

**`GrabAttack`** (`scripts/grab_attack.gd`) — на `attack(direction)` делает shape query кругом `radius` (22) со смещением `reach` (16) к мыши по маске `grab_mask` (враги), берёт ближайшую цель с методом `grab` и вызывает `grab(hold_time)`. Сигналы `grabbed(target)` / `missed`. `cooldown` (0.25 с) между попытками — по реальному времени.

## Враг (`scripts/enemy.gd`, `enemy.tscn`)

Машина состояний в `_update_intent`:

- **IDLE** — стоит. Переход в CHASE, если игрок ближе `sight_range` (250) и луч до него не упирается в стену (`sight_mask = 1`; платформы слоя 2 обзор не закрывают). Получив урон, тоже сразу переходит в CHASE.
- **CHASE** — бежит к игроку по X. Если игрок ниже на `drop_height` (24) и враг стоит на one-way платформе — **спрыгивает** за ним (`jump_requested + drop_requested`). Если игрок выше на `drop_height` и над врагом досягаемая one-way платформа (`has_platform_above()`) — **запрыгивает** на неё. Иначе, если на полу упёрся в стену — прыгает. Дальше `lose_range` (400) → IDLE. Ближе `attack_range` (40) и `MeleeAttack` готов → ATTACK.
- **ATTACK** — стоит, жёлтая вспышка на время замаха `attack_windup` (0.3 с, окно для реакции игрока), затем `melee_attack.attack(направление_на_игрока)` → снова CHASE. Частоту ударов ограничивает `cooldown` его `MeleeAttack` (0.8 с). Последние `clinch_window` (0.15 с) замаха `is_attacking()` уже `true` — удар игрока в этот момент даёт клинч. Удар раньше — обычный урон, замах прерывается (→ CHASE).
- **STUNNED** — после клинча: `stun_time` (1 с) стоит, не атакует, светится синим. Урон по нему проходит обычно. Потом → CHASE.
- **GRABBED** — схвачен тенью (`grab(duration)`): стоит, текущий удар гасится, не атакует, не отбрасывается (`apply_knockback` игнорируется), светится фиолетовым. Потом → CHASE.

`facing`: в CHASE и ATTACK враг всегда разворачивается к игроку. В STUNNED/GRABBED — нет: это окно, чтобы зайти за спину.

Блокированный удар (`take_damage` вернул `false`) замах не прерывает.

Если игрок умер/пропал, враг ищет его заново через группу `player` и возвращается в IDLE.

Точки расширения для других типов врагов (переопределяются в наследниках):

| Метод | По умолчанию (ближний бой) |
|---|---|
| `_can_start_attack()` | `melee_attack.can_attack()` |
| `_perform_attack(to_target)` | `melee_attack.attack(to_target)` |
| `_should_approach(to_target)` | `abs(to_target.x) > attack_range / 2` |

## Турель (`scripts/turret.gd`, `turret.tscn`)

**Не `Fighter`** — `StaticBody2D` (слой 3, маска 0): не двигается, не падает, можно ставить на пол/стену/потолок (поворачиваешь ноду — ствол целится в глобальных координатах). Своё HP (`max_health` 10 — один удар), `take_damage` (всегда проходит), `is_dead`, `died`, группа `enemy`.

Состояния:

- **IDLE** → **WARMUP**, когда игрок ближе `sight_range` (300) и виден (луч по `sight_mask` от ствола). Жёлтая вспышка `warmup` (0.5 с) — предупреждение.
- **FIRING** — зависит от `fire_mode`:
  - `BURST` (по умолчанию) — очереди по `burst_count` (3) пули с интервалом `burst_interval` (0.08 с), между очередями `burst_cooldown` (0.7 с);
  - `CONTINUOUS` — без перерыва, по пуле каждые `fire_interval` (0.1 с), пока видит игрока и ствол наведён. Пули `bullet_speed` 500, урон 10, разброс ±2°, `hit_mask = 8`, вылетают из `Barrel/Muzzle`.
- Игрок пропал из вида → IDLE (следующий раз снова warmup).
- **JAMMED** — схвачена тенью (`grab(duration)`): не стреляет, фиолетовая. Потом IDLE.

Ствол поворачивается к игроку не мгновенно, а со скоростью `turn_speed` (180°/с), и стреляет, только когда наведён точнее `aim_tolerance` (6°) — от очереди можно уйти, резко сменив сторону. Работает в игровом времени — в замедлении тенью турель тоже медленная.

Как убить: подойти и ударить, отбить её же пули катаной (отбитые бьют слой 3), или заклинить тенью и подойти. Удар/убийство даёт Juice (группа `enemy`). Реакция `HitSparks` — искры вместо крови.

## Бронированный враг (`scripts/enemy_armored.gd`, `enemy_armored.tscn`)

`extends Enemy`, ближний бой, 20 HP, `speed` 150. `take_damage`: если `from` со стороны `facing` (`is_front`) — **блок**: урона нет, белая вспышка, `return false` → у атакующего `hit.blocked`, реакция `HitSparksBlocked` (`trigger = BLOCKED`) даёт искры, игрока отбрасывает. Пули спереди тоже блокируются. Нода `Shield` (визуал) двигается на сторону `facing`.

Как пробить: тенью схватить (GRABBED — не разворачивается) и зайти за спину. Работает и клинч (STUNNED тоже не разворачивается).
## Стрелок (`scripts/enemy_shooter.gd`, `enemy_shooter.tscn`)

`extends Enemy`, тот же автомат состояний. Отличия:

- `attack_range` 220, `attack_windup` 0.4 с — это прицеливание (жёлтая вспышка);
- атакует, только если видит игрока и прошёл `fire_cooldown` (1.2 с); подходит, пока игрок дальше `attack_range` или за стеной;
- выстрел: `BulletWorld.current.spawn(...)` со скоростью `bullet_speed` (400), уроном `bullet_damage` (10), разбросом `spread_deg` (±3°), `bullet_hit_mask = 8` (игрок);
- `max_health` 10 — умирает с одного удара; `is_attacking()` всегда `false` → клинча нет.

## Пули: `BulletWorld` (`scripts/bullet_world.gd`)

Одна нода в сцене уровня (`world.tscn` → `BulletWorld`), доступ отовсюду через `BulletWorld.current` (static var, ставится в `_enter_tree`). При перезагрузке сцены пули исчезают вместе с нодой.

**Хранение — структура массивов**: i-я пуля = i-е элементы `_pos`, `_vel` (`PackedVector2Array`), `_life` (`PackedFloat32Array`), `_damage`, `_hit_mask` (`PackedInt32Array`), `_color` (`PackedColorArray`). Никаких нод на пулю, спавн = `append`. Удаление — swap-remove (последняя пуля копируется на место удалённой) → **индекс пули нельзя хранить между кадрами**. Лимит `max_bullets` (2048).

**Кадр** (`_physics_process`):

1. все аффекторы получают `affect_bullets(self, delta)`;
2. каждая пуля: `lifetime` (3 с) истёк → удалить; луч `pos → pos + vel·delta` по маске `world_mask | hit_mask` (один переиспользуемый `PhysicsRayQueryParameters2D`) — не проскакивает сквозь стены на скорости. Попала в объект с `take_damage` → урон (отбрасывание от точки позади пули); в любом случае — удалить;
3. `queue_redraw()` → все пули рисуются одним `_draw()` (кружок + хвост `vel·trail`).

Если пуль станет тысячи и `_draw` упрётся в CPU — заменить отрисовку на `MultiMeshInstance2D`, данные останутся те же.

**Аффекторы** — любой объект с `affect_bullets(bullets: BulletWorld, delta)`, регистрируется `add_affector()` / `remove_affector()`. API для них: `count()`, `query_circle(center, r)`, `query_rect(xform, size)` (повёрнутый прямоугольник) → индексы; `get/set_bullet_velocity`, `get/set_bullet_hit_mask`, `get_bullet_position`, `set_bullet_color`. Сюда встраиваются отражение, магниты, замедляющие поля и т.п. (пример магнита — в комментарии в начале файла).

Первый аффектор — **отражение катаной**: `MeleeAttack` с `deflect_bullets = true` (включено у игрока) регистрируется на время `active_time` удара. Пули в зоне `hitbox_size + deflect_padding` (24×24 запаса — чтобы отбивать было не пиксель-в-пиксель), чей `hit_mask` включает слой владельца, разворачиваются по направлению удара (скорость × `deflect_speed_mult` 1.5), получают `hit_mask` удара (бьют врагов) и цвет `deflect_color`. Сигнал `deflected` → у игрока `Juice.hit()`.

## Сок: `Juice` (`scripts/juice.gd`, autoload)

Сервисный синглтон, зарегистрирован в `project.godot` → `[autoload]`. Геймплей сообщает о **событии** (`Juice.hit()`, `Juice.kill()`, `Juice.clinch()`), а что при этом происходит — решает Juice. `spawn_effect(scene, pos, dir)` — одноразовый эффект в корень текущей сцены, ось +X по `dir`; частицы (`CPU/GPUParticles2D`) запускаются `restart()` и удаляются по `finished`. Эффекты живут в игровом времени (в slow-mo тоже замедлены). Сюда же в будущем: звук.

**Удерживаемое замедление** (`hold_time_scale(id, scale)` / `release_time_scale(id)`): держится, пока не отпустят по тому же `id` (тень — `&"shadow"`). Несколько удержаний — действует сильнейшее. Итог каждый кадр: `Engine.time_scale = min(импульс slow_motion, удержания)` — hit-stop работает поверх замедления тенью. **Juice — единственный владелец `Engine.time_scale`**: напрямую его не менять.

**Замедление времени** (`slow_motion(scale, hold, recover)`):

- меняет `Engine.time_scale` — замедляет всё: физику, таймеры, твины, анимации;
- поэтому длительность считается по **реальному** времени (`Time.get_ticks_usec()`), а не по delta/таймерам;
- фазы: `hold` сек держит `scale`, потом `recover` сек плавно (ease-out) возвращается к 1.0;
- если новое замедление приходит во время старого — сливаются (сильнейший `scale`, позднейший конец);
- `process_mode = ALWAYS`, `reset()` — мгновенно вернуть 1.0 (сбрасывает и удержания).

Пресеты — константы `(scale, hold, recover)` в начале файла:

| Пресет | scale | hold | recover |
|---|---|---|---|
| `HIT` | 0.25 | 0.06 с | 0.10 с |
| `KILL` | 0.10 | 0.12 с | 0.25 с |
| `CLINCH` | 0.15 | 0.10 с | 0.20 с |

**Тряска камеры** (`shake(amount)`), модель «травмы»:

- `trauma ∈ [0, 1]`; `shake(amount)` прибавляет, каждую **реальную** секунду убывает на `SHAKE_DECAY` (1.6); подряд идущие удары складываются;
- смещение = `SHAKE_MAX_OFFSET (8, 6) px · trauma² · шум` — квадрат делает слабые удары мягкими, сильные — заметными;
- шум `FastNoiseLite` (разные срезы для X и Y, скорость `SHAKE_FREQUENCY` 25) — камера дрожит плавно, без телепортов;
- трясётся `Camera2D.offset` текущей камеры вьюпорта (`position` отвечает за следование и сглаживание — его не трогаем); исходный offset запоминается и возвращается, при смене камеры (перезагрузка сцены) старая возвращается на место;
- по реальному времени — во время замедления тряска не застывает.

| Событие | trauma |
|---|---|
| `hit()` (и отбитая пуля) | `SHAKE_HIT` 0.35 |
| `kill()` | `SHAKE_KILL` 0.6 |
| `clinch()` | `SHAKE_CLINCH` 0.5 |

## Реакции на удар: `HitInfo` / `HitReaction` (`scripts/hits/`)

Задача — чтобы любой ударяемый объект (враг, игрок, проп) реагировал на удар по-своему, и эта реакция **собиралась из нод в редакторе**, а не прописывалась в коде атаки.

**Поток попадания:**

1. `MeleeAttack._try_hit` или `BulletWorld` (при попадании пули) создают `HitInfo`:
   `attacker` (у пуль `null`), `target`, `position` (для удара — центр цели, для пули — точка попадания), `direction` (направление удара/полёта пули), `damage`, `kind` (`&"melee"` / `&"bullet"`).
2. Если у цели есть `take_damage` — наносится урон; `hit.blocked = not take_damage(...)`, затем `hit.killed = target.is_dead`.
3. `HitReaction.dispatch(target, hit)` вызывает `react(hit)` у **всех дочерних `HitReaction`** цели. У цели может не быть `take_damage` — реакции всё равно сработают (проп).

**`HitReaction`** (база, `extends Node`) — фильтры в инспекторе: `enabled`, `trigger` (`ANY` / `NON_LETHAL` / `LETHAL` — только прошедшие удары; `BLOCKED` — только заблокированные), `kinds` (пусто = все виды). Новая реакция = скрипт `extends HitReaction` с `_react(hit)`.

**`HitEffect`** — спавнит `effect` (любая сцена) через `Juice.spawn_effect` в точке попадания, повёрнутым по `hit.direction`. Эффект кладётся в корень уровня, а не в цель — брызги переживают смерть цели.

Сейчас навешано:

| Кто | Реакции |
|---|---|
| Враг, стрелок, игрок | `HitBlood` (`blood.tscn`, любой удар) + `HitBloodKill` (`blood_kill.tscn`, `LETHAL`) |
| Бронированный | то же + `HitSparksBlocked` (`sparks.tscn`, `BLOCKED`) |

Прочие эффекты (не через реакции, т.к. цели — не ноды или событие не «попадание»):

- отбитая пуля → `MeleeAttack.deflect_effect` (искры) в точке пули;
- пуля в стену/объект без реакций → `BulletWorld.wall_effect` (искры) по нормали поверхности;
- клинч → `Fighter.clinch_effect` (искры) между бойцами, берётся у любого из двух (задан у игрока).

**Как сделать проп** (на будущее): `StaticBody2D`/`RigidBody2D` на слое 5 + дочерние реакции, например `HitEffect(щепки)` + своя `extends HitReaction` (толкнуть: `apply_impulse(hit.direction * …)`, разрушиться, погаснуть). Урон/HP не обязательны. Juice-замедление при ударе по пропу не срабатывает (игрок зовёт Juice только для `Fighter`) — если нужно, сделать реакцию, которая зовёт `Juice.shake()`.

## Атака (`melee_attack.gd`)

Дочерняя нода бойца (путь `$MeleeAttack` обязателен для `Fighter`). Хитбокс `Area2D` создаётся один раз в `_ready`. `attack(direction := Vector2.ZERO)` поворачивает его по `direction` (локальные координаты; `ZERO` → к мыши), включает на `active_time`, затем кулдаун. `can_attack()` — готов ли удар, `is_active()` — идёт ли удар сейчас, `cancel()` — погасить удар (клинч). Попадание: если у цели есть `is_attacking()` и он `true`, а у владельца есть `clinch()` → клинч (сигнал `clinched`), иначе цель получает `take_damage(damage, global_position)` и эмитится `hit_landed(hit: HitInfo)` (в т.ч. при блоке — см. `hit.blocked`). Компонент не зависит от `Fighter` напрямую — только duck-typing. Одна цель бьётся максимум раз за взмах; своего владельца (`get_parent()`) хитбокс игнорирует.

## Известные TODO

- Флип спрайта по направлению мыши (`mouse_pos()` пока ничего не делает).
- Анимации (`AnimatedSprite2D` пустой, стоит `PlaceholderTexture2D`).
- Враг запрыгивает только на one-way платформы. На сплошной уступ выше себя — нет, только перепрыгивает стену перед собой.
- В текущем `world.tscn` от пола ямы до платформ 128 px, а прыжок ≈ 82 px: туда не допрыгнуть ни врагу, ни игроку.
- Juice: частицы, звук; тряска при получении урона игроком.
- Пропы на слое 5 (ящики, лампы) с собственными `HitReaction`.
- Пули: другие аффекторы (магнит, поле замедления), `MultiMeshInstance2D` при большом количестве.
- Нет неуязвимости после урона.
- Турель: ограничение угла поворота ствола (сейчас 360°), разрушение с эффектом посильнее.
- Тень: HUD кулдауна (есть сигнал `ShadowAbility.state_changed`), ограничение дальности от тела, визуальная связь тело↔тень.
- Смерть игрока — просто перезагрузка сцены, без экрана/анимации.

## Журнал изменений

- **2026-09-24** — Добавлены скольжение по стене и отпрыжка от стены (`scripts/character.gd`). Создан этот файл.
- **2026-09-24** — Добавлен враг ближнего боя (`enemy.tscn`, `scripts/enemy.gd`) с AI IDLE/CHASE/ATTACK. Движение и здоровье вынесены в базовый класс `Fighter` (`scripts/fighter.gd`), игрок теперь наследуется от него. `MeleeAttack.attack()` принимает направление, добавлен `can_attack()`. Игрок перенесён на физ. слой 4, враги — слой 3. Таймер `_drop_through` удалён из `character.tscn` (заменён на `create_timer`).
- **2026-09-24** — Отбрасывание при получении урона (`Fighter.apply_knockback`, `take_damage` теперь принимает позицию атакующего). Клинч: одновременные удары гасят друг друга и расталкивают бойцов, враг оглушается (`STUNNED`). Враг спрыгивает с one-way платформ за игроком (`Fighter.is_on_drop_platform`). Удар по врагу во время замаха прерывает замах. `_wall_jump_lock` → `_control_lock`. У врага 20 HP = два удара.
- **2026-09-24** — Добавлен autoload `Juice` (`scripts/juice.gd`): замедление времени при попадании, добивании и клинче, с пресетами. Враг запрыгивает на one-way платформу над собой, если игрок выше (`Fighter.has_platform_above`, `get_jump_height`).
- **2026-09-24** — Добавлены стрелки (`enemy_shooter.tscn`, `scripts/enemy_shooter.gd`) и система пуль `BulletWorld` (packed-массивы вместо нод, аффекторы). Катана игрока отбивает пули (`MeleeAttack.deflect_bullets`). `Enemy` получил `class_name` и точки расширения `_can_start_attack` / `_perform_attack` / `_should_approach`. `MeleeAttack` у `Fighter` стал необязательным. Из `world.tscn` убраны `null`-переопределения параметров игрока.
- **2026-09-24** — `Juice`: тряска камеры (trauma² × шум, по реальному времени) при попадании, добивании, клинче и отбитой пуле.
- **2026-09-24** — Система реакций на удар (`HitInfo`, `HitReaction`, `HitEffect` в `scripts/hits/`) + эффекты частиц (`effects/`): кровь при попадании и сильнее при убийстве, искры при отражении пули, клинче и попадании пули в стену. `Juice.spawn_effect`. Зона отражения пуль расширена (`deflect_padding`). Удар игрока бьёт и слой 5 (пропы). Juice-замедление только по `Fighter`. Убран некорректный `#`-комментарий из `enemy.tscn`.
- **2026-09-24** — Механика тени: `PlayerPawn` (передача управления через `PlayerPawn.possessed`), `Shadow` + `GrabAttack` (захват врага), `ShadowAbility` (цикл READY → CONTROLLING → HOLDING → COOLDOWN), инпут `shadow` (ПКМ). `Juice.hold_time_scale/release_time_scale` — удерживаемое замедление поверх импульсов. `Fighter`: `facing`, `unscaled_time`, `take_damage` возвращает `bool`. `Enemy`: состояние GRABBED, разворот к игроку. Бронированный враг (`enemy_armored`) с блоком спереди; `HitInfo.blocked`, триггер реакций `BLOCKED`; `hit_landed` передаёт `HitInfo`.
- **2026-09-24** — Турели (`turret.tscn`, `scripts/turret.gd`): стационарные, очереди пуль, поворотный ствол с ограниченной скоростью, заклинивают от захвата тенью. Группа `enemy` у всех врагов; Juice при ударе теперь по группе `enemy`, а не по классу `Fighter`.
- **2026-09-24** — Турель: режим стрельбы `fire_mode` (`BURST` / `CONTINUOUS` — без перерыва, `fire_interval`).
