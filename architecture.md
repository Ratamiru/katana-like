# Architecture — Katana-like

2D-платформер с ближним боем в духе Katana Zero. Godot 4.7, Forward Plus, физика Jolt (3D; в 2D — стандартная).

> Этот файл обновляется при каждом изменении архитектуры или механик — см. раздел «Журнал изменений» внизу.
>
> Визуальный обзор с диаграммами (иерархия классов, слои, автоматы состояний, поток удара) — `docs/architecture.typ`. Сборка: `typst compile docs/architecture.typ` → `docs/architecture.pdf` (PDF в `.gitignore`).

## Структура проекта

| Путь | Назначение |
|---|---|
| `ui/main_menu.tscn` | Главное меню — стартовая сцена игры (`run/main_scene`) |
| `scripts/ui/main_menu.gd` | Меню: «Продолжить» / «Новая игра», «Загрузить» (список уровней), «Выход» |
| `scripts/ui/level_catalog.gd` | `LevelCatalog` — список всех уровней по порядку (путь + название) |
| `scripts/progress.gd` | Autoload `Progress` — открытые уровни и «Продолжить» (`user://progress.cfg`), Esc → меню |
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
| `scripts/interactor.gd` | `Interactor` — компонент «взаимодействовать с объектом рядом» (у тени): ищет ноды с `interact(actor)` |
| `scripts/turret.gd` | `Turret` — стационарный враг, очереди пуль через `BulletWorld`, заклинивает от захвата тенью |
| `scripts/enemy_armored.gd` | Бронированный враг (`extends Enemy`): блок спереди, уязвим сзади |
| `scripts/enemy.gd` | `Enemy` (`extends Fighter`): примитивный AI (IDLE → CHASE → ATTACK, STUNNED после клинча), по умолчанию ближний бой |
| `enemy_shooter.tscn` | Стрелок (оранжевый плейсхолдер), без `MeleeAttack` |
| `scripts/enemy_shooter.gd` | Стрелок (`extends Enemy`): держит дистанцию, стреляет через `BulletWorld` |
| `scripts/bullet_world.gd` | `BulletWorld` — все пули уровня в packed-массивах, аффекторы (отражение и т.п.) |
| `scripts/juice.gd` | Autoload `Juice` — сервис «сочности» (замедление времени, тряска камеры) |
| `scripts/fx/screen_fx.gd` | Autoload `ScreenFX` — полноэкранные эффекты-телеграфы (состояния и импульсы) |
| `scripts/fx/screen_fx_preset.gd` | `ScreenFXPreset` (Resource) — параметры одного экранного эффекта + огибающая |
| `shaders/screen_fx.gdshader` | Шейдер оверлея: тонировка, виньетка, обесцвечивание, хроматическая аберрация |
| `melee_attack.gd` | `MeleeAttack` — компонент удара (Area2D-хитбокс, кулдаун), к мыши или в заданном направлении |
| `scripts/hits/hit_info.gd` | `HitInfo` — данные одного попадания (кто, куда, откуда, урон, вид, убил ли) |
| `scripts/hits/hit_reaction.gd` | `HitReaction` — базовая реакция на удар + `dispatch()` рассылки |
| `scripts/hits/hit_effect.gd` | `HitEffect` — реакция «заспавнить эффект» (кровь, искры…) |
| `effects/` | Сцены эффектов: `blood.tscn`, `blood_kill.tscn`, `sparks.tscn` (`CPUParticles2D`, one-shot) |
| `scripts/level/switch.gd` | `Switch` — база переключателей (`Area2D`, слой 5): `targets` → `set_active(on)`, режимы TOGGLE/ONCE/TIMED |
| `scripts/level/lever.gd` | `Lever` (`extends Switch`) — рычаг, переключается ударом катаны |
| `scripts/level/door.gd` | `Door` (`AnimatableBody2D`) — пример цели: открывается сдвигом |
| `scripts/level/light_source.gd` | `LightSource` (`PointLight2D`) — лампа: свет + правило «здесь светло» для зрения врагов |
| `scripts/layers.gd` | `Layers` — константы физических слоёв и готовые маски (`SOLID`, `BODY_MASK`, `SHADOW_MASK`) |
| `scripts/vision.gd` | `Vision` — правила обнаружения врагами (свет → круг, темнота → конус) + отладочная отрисовка |
| `level/light_source.tscn` | Сцена лампы |
| `scripts/level/level_lighting.gd` | `LevelLighting` (`CanvasModulate`) — освещение уровня: темнота или `fully_lit` (всё освещено) |
| `scripts/level/level_goals.gd` | `LevelGoals` — цели уровня и его завершение (`LevelGoals.current`) |
| `scripts/level/level_exit.gd` | `LevelExit` (`Area2D`) — выход, открывается после обязательных целей |
| `scripts/level/objectives/` | `Objective` (база), `ObjectiveKill`, `ObjectiveSignal` |
| `level/` | Сцены объектов уровня: `lever.tscn`, `door.tscn`, `level_exit.tscn` |
| `docs/architecture.typ` | Документ Typst с диаграммами архитектуры |
| `addons/dialogue/` | Аддон диалогов (переносимый): парсер `.dlg`, раннер, autoload `Dialogue`, окно, `DialogueTrigger`. Справка по синтаксису — `addons/dialogue/README.md` |
| `dialogues/` | Тексты диалогов `.dlg` (`old_man.dlg` — демо) |
| `level/npc.tscn` | NPC-плейсхолдер: `scripts/level/npc.gd` (`extends DialogueTrigger`, подойти, E) с подсказкой «E» |
| `scripts/create_tiles.gd` | EditorScript: генерирует `art/placeholder_tiles.png` (4 цветных тайла 32×32) |
| `art/` | Графика (пока плейсхолдеры) |

## Физические слои

Константы — `scripts/layers.gd` (`Layers.WORLD`, `Layers.SOLID`, …); имена слоёв подписаны в Project Settings → Layer Names → 2D Physics, в инспекторе видны по-русски.

**Как читать:** `collision_layer` — «на каких слоях я лежу» (ярлык), `collision_mask` — «в какие слои я упираюсь / что вижу» (фильтр). A сталкивается с B, если в **маске** A есть **слой** B. Поэтому одно препятствие может держать игрока и пропускать тень — у них разные маски.

| Слой | Бит | Константа | Что на нём |
|---|---|---|---|
| 1 «Мир» | `1` | `WORLD` | Сплошные тайлы (пол, стены) — держат всех, **включая тень** |
| 2 «Платформы» | `2` | `PLATFORMS` | One-way платформы, сквозь которые можно спрыгнуть (`down` + `jump`) |
| 3 «Враги» | `4` | `ENEMIES` | Враги (в т.ч. турели) |
| 4 «Игрок» | `8` | `PLAYER` | Игрок (основное тело) |
| 5 «Пропы» | `16` | `PROPS` | Пропы и переключатели, которые можно ударить (`Switch`/`Lever` — `Area2D`) |
| 6 «Проходимо для тени» | `32` | `SHADOW_PASSABLE` | Двери (`Door`), в будущем окна, решётки — держат всех, **кроме тени** |

Готовые маски: `Layers.SOLID = 33` (мир + двери: останавливает пули, свет, взгляд), `Layers.BODY_MASK = 35` (игрок и враги), `Layers.SHADOW_MASK = 3` (тень).

- Игрок: `collision_layer = 8`, `collision_mask = 35` (мир, платформы, двери), `MeleeAttack.hit_mask = 20` (бьёт врагов и пропы).
- Враги: `collision_layer = 4`, `collision_mask = 35`, `MeleeAttack.hit_mask = 8` (бьют игрока).
- **Тень**: `collision_layer = 0` (её никто не видит и не бьёт), `collision_mask = 3` — пол и стены держат (не падает под пол), **двери и прочий слой 6 проходит насквозь**.
- Пули (`BulletWorld.world_mask = SOLID`), взгляд врагов и турелей (`sight_mask = SOLID`), свет ламп (`LightSource.wall_mask = SOLID`) останавливаются о стены и двери; сквозь one-way платформы проходят. Пули ранят слои из своего `hit_mask` (стрелок — `8`, отбитые — `20`).
- Игрок и враги **не сталкиваются** телами (в масках нет слоёв 3/4) — проходят друг сквозь друга, как в Katana Zero.
- Новый объект «тень проходит, остальные нет» (окно, решётка): любое тело на слое 6, маска 0.

## Инпут

| Action | Клавиша |
|---|---|
| `forward` / `backward` | D / A |
| `jump` | Space |
| `down` | S |
| `attack` | ЛКМ (действие текущего тела: катана / захват) |
| `shadow` | ПКМ (выпустить тень / отменить) |
| `use` | E — заговорить с NPC (`DialogueTrigger`), в диалоге — дальше (вместе с `ui_accept` и ЛКМ) |
| `restart` | R (мгновенный рестарт уровня) |
| `menu` | Esc — выйти в главное меню (во время диалога не срабатывает — дерево на паузе) |

## Бойцы: `Fighter` (`scripts/fighter.gd`)

Игрок и враги наследуются от одного класса `Fighter`, поэтому двигаются по одним правилам. Наследник **не трогает физику**, он только заполняет «намерения» в `_update_intent(delta)`:

- `move_dir` — направление по X (-1..1);
- `jump_requested` — хочет прыгнуть в этом кадре (сбрасывается после обработки);
- `drop_requested` — вместе с прыжком означает спрыгивание сквозь платформу.

`facing` (±1) — куда смотрит боец: обновляется по знаку `move_dir`, враги ещё и разворачиваются к игроку (см. «Враг»). Нужен броне.

`unscaled_time` — боец живёт в реальном времени: `delta` делится на `Engine.time_scale`, скорость перед `move_and_slide()` умножается на `1/time_scale` и после делится обратно. Используется тенью, чтобы она не замедлялась вместе с миром.

`take_damage(amount, from) -> bool` — `true`, если урон прошёл; `false` — заблокирован (броня) или цель мертва.

**Выпад** (`lunge(dir) -> bool`, группа `Lunge` в инспекторе): импульс `velocity = (d.x, d.y · lunge_vertical_mult) · lunge_speed` по нормализованному `dir` + `_control_lock = lunge_time`. На земле — каждый раз, в воздухе — один раз до приземления (`_air_lunge_used` сбрасывается, когда `is_on_floor()`). `lunge_speed = 0` (по умолчанию) — выпада нет; включён у игрока (320, `lunge_vertical_mult` 0.8, `lunge_time` 0.12 с). Враги/тень могут включить тем же параметром.
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
- `_primary_action()` → если `melee_attack.can_attack()`: `attack(к мыши)` + `lunge(к мыши)` — выпад как в Katana Zero, добавляет мобильности (в воздухе — один раз до приземления).
- **Смерть с одного удара**: `max_health = 1` в `character.tscn` (любой урон ≥ 1 убивает).
- Сок: `melee_attack.hit_landed(hit)` → по врагу (цель в группе `enemy` — `Enemy` и `Turret` добавляют себя в `_ready`): `hit.blocked` → отдача игроку (`knockback × 0.6`) + `Juice.shake(0.2)`; `hit.killed` → `Juice.kill()`; иначе `Juice.hit()`. Сигнал `clinched` → `Juice.clinch()`, сигнал `damaged` → `Juice.hurt()`.
- `_die()` → `restart_level(restart_delay)`: через `restart_delay` (0.15 реальных сек — увидеть, что убило) `Juice.reset()`, `ScreenFX.clear()` и `reload_current_scene`. `restart` (R) — `restart_level(0)` в любой момент. Защита от двойного рестарта — `_restarting`.

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

**`Interactor`** (`scripts/interactor.gd`) — на `try_interact(direction)` shape query кругом `radius` (24) со смещением `reach` (16) к мыши по `mask` (`Layers.PROPS`, areas и bodies), кандидаты с методом `interact(actor) -> bool` по расстоянию; первый, вернувший `true`, — сработал (сигнал `interacted`). `cooldown` 0.2 с (реальное время).

**ЛКМ тенью**: `grab_attack.attack(к мыши)`; если схватить некого — `interactor.try_interact(к мыши)`. Управление после взаимодействия остаётся у тени (в отличие от захвата) — можно пройти сквозь дверь, дёрнуть рычаг за ней и вернуться ПКМ.

## Враг (`scripts/enemy.gd`, `enemy.tscn`)

Машина состояний в `_update_intent`:

- **IDLE** — стоит, смотрит в `start_facing` (-1 влево / 1 вправо). Переход в CHASE, когда `Vision.detects(...)`: игрок на свету — ближе `sight_range` (250) в любую сторону; в темноте — ближе `dark_sight_range` (140) и в конусе `dark_cone_angle` (70°) по `facing`. В обоих случаях луч до игрока не должен упираться в стену (`sight_mask = 1`; платформы слоя 2 обзор не закрывают). См. «Зрение и свет». Получив урон, тоже сразу переходит в CHASE.
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

- **IDLE** → **WARMUP**, когда `Vision.detects(...)` от ствола: игрок на свету — ближе `sight_range` (300); в темноте — ближе `dark_sight_range` (180) и в конусе `dark_cone_angle` (40°) вдоль ствола. Дальше (WARMUP/FIRING) турель ведёт цель просто по дальности и прямой видимости. Жёлтая вспышка `warmup` (0.5 с) — предупреждение.
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

Сервисный синглтон, зарегистрирован в `project.godot` → `[autoload]`. Геймплей сообщает о **событии** (`Juice.hit()`, `Juice.kill()`, `Juice.clinch()`, `Juice.hurt()`), а что при этом происходит — решает Juice (в т.ч. зовёт `ScreenFX.pulse` для полноэкранных вспышек). `spawn_effect(scene, pos, dir)` — одноразовый эффект в корень текущей сцены, ось +X по `dir`; частицы (`CPU/GPUParticles2D`) запускаются `restart()` и удаляются по `finished`. Эффекты живут в игровом времени (в slow-mo тоже замедлены). Сюда же в будущем: звук.

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
| `hurt()` (игрока ранили; без замедления) | `SHAKE_HURT` 0.4 |

## Экранные эффекты: `ScreenFX` (`scripts/fx/`, autoload)

Полноэкранный оверлей, телеграфирующий состояние игры. Autoload (`project.godot` → `[autoload]`, после `Juice`), `CanvasLayer` со слоем `LAYER = 100`, внутри один `ColorRect` на весь экран с шейдером `shaders/screen_fx.gdshader`, который читает уже нарисованный экран (`hint_screen_texture`). **HUD класть на CanvasLayer выше 100**, иначе эффекты лягут и на него.

Два вида эффектов:

- **состояние** — `enter(id, preset_name = id)` / `exit(id)` / `is_active(id)`: держится, пока не сняли; появляется за `fade_in`, уходит за `fade_out`;
- **импульс** — `pulse(preset_name)` / `pulse_preset(preset)`: `fade_in` → `hold` → `fade_out` и исчезает.

Пресет — `ScreenFXPreset` (Resource, можно делать `.tres` в редакторе): `tint_color` + `tint`, `vignette_color` + `vignette`, `desaturate`, `aberration` (амплитуды 0..1) и огибающая. `register(name, preset)` — добавить/заменить. Каждый кадр все активные эффекты смешиваются в один набор параметров: амплитуды × вес складываются и обрезаются до 1, цвета — среднее, взвешенное по силе. Ничего не активно → `ColorRect` скрыт, шейдер не считается. Время **реальное** (не тормозит в slow-mo). `intensity` (0..1) — общий множитель, 0 выключает всё (доступность/настройки). `clear()` — сбросить мгновенно.

| Пресет | Вид | Что | Кто вызывает |
|---|---|---|---|
| `shadow` | состояние | фиолетовая виньетка, мир серее | `ShadowAbility`: enter в CONTROLLING, exit при захвате/отмене/таймауте/`_exit_tree` |
| `clinch` | импульс | белая вспышка + аберрация | `Juice.clinch()` |
| `kill` | импульс | аберрация + обесцвечивание | `Juice.kill()` |
| `hurt` | импульс | красная виньетка | `Juice.hurt()` ← `damaged` игрока |

Правило: события геймплея идут через `Juice` (он решает, какая вспышка), длительные состояния включает владелец состояния напрямую через `enter/exit`.

## Реакции на удар: `HitInfo` / `HitReaction` (`scripts/hits/`)

Задача — чтобы любой ударяемый объект (враг, игрок, проп) реагировал на удар по-своему, и эта реакция **собиралась из нод в редакторе**, а не прописывалась в коде атаки.

**Поток попадания:**

1. `MeleeAttack._try_hit` или `BulletWorld` (при попадании пули) создают `HitInfo`:
   `attacker` (у пуль `null`), `target`, `position` (для удара — центр цели, для пули — точка попадания), `direction` (направление удара/полёта пули), `damage`, `kind` (`&"melee"` / `&"bullet"`).
2. Если у цели есть `take_damage` — наносится урон; `hit.blocked = not take_damage(...)`, затем `hit.killed = target.is_dead`.
3. `HitReaction.dispatch(target, hit)` вызывает `target.on_hit(hit)`, если у цели есть такой метод (цель реагирует сама — так работает `Switch`), и `react(hit)` у **всех дочерних `HitReaction`** цели. У цели может не быть `take_damage` — реакции всё равно сработают (проп).

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

## Объекты уровня: переключатели и цели (`scripts/level/`, `level/`)

Задача — связывать объекты уровня в редакторе без кода: рычаг открывает дверь, в будущем кнопка включает платформу и т.п.

**`Switch`** (`extends Area2D`) — база любого переключателя:

- в `_ready` сам ставит себе слой 5 (`collision_layer = 16`), `monitorable = true`, `monitoring = false` — хитбокс удара его «видит», ходьбе и пулям (лучи без areas) он не мешает;
- `targets: Array[NodePath]` — ноды, которыми управляет. Цель — **любая нода с `set_active(on: bool)`**. При переключении у всех целей вызывается `set_active(is_on)`, эмитится `switched(on)` (можно подключать в редакторе); начальное состояние (`start_on`) отправляется целям отложенно в `_ready`;
- `mode`: `TOGGLE` (каждое срабатывание переключает), `ONCE` (только включить, один раз), `TIMED` (включить на `timed_duration` сек игрового времени);
- **взаимодействие** — `interact(actor) -> bool` (тень через `Interactor`): при `interactable = true` → `activate()`; `interactable = false` — рычаг только для катаны;
- удар приходит через `HitReaction.dispatch` → `on_hit(hit)`; `hit_kinds` фильтрует виды ударов (по умолчанию только `&"melee"`);
- `activate()` — «сработать» (для будущих кнопок/триггеров), `set_on(on)` — выставить состояние напрямую, `_update_visual(animated)` — переопределяется для визуала.

**`Lever`** (`level/lever.tscn`, `extends Switch`) — рычаг: ручка `Handle` наклоняется `angle_off` (-35°) / `angle_on` (35°) с твином, `Juice.shake(0.15)` при переключении, искры через дочерний `HitEffect`.

**`Door`** (`level/door.tscn`, `extends AnimatableBody2D`) — пример цели: слой 6 «Проходимо для тени» (держит игрока и врагов, закрывает обзор, останавливает пули и свет; тень проходит насквозь). `set_active(on)` → открыта, если `on != inverted`: сдвиг на `open_offset` (по умолчанию `(0, -64)`) за `move_time` (0.3 с), твин в physics-процессе, `sync_to_physics`.

В `world.tscn`: дверь `Door` на (-150, -29) между стартом и бронированным врагом, рычаг `Lever` на (-330, -8) слева от старта, `targets = [../Door]`.

Как добавить: новый переключатель (кнопка, нажимная плита) = `extends Switch`, вызывает `activate()` по своему событию. Новая цель (платформа, свет, спавнер, турель) = любая нода с `set_active(on)`.

## Цели и завершение уровня (`LevelGoals`, `Objective`, `LevelExit`)

Гибкая система «что сделать на уровне и как он кончается»; всё собирается в редакторе.

**`LevelGoals`** (`extends Node`, одна на уровень, `LevelGoals.current` — static, ставится в `_enter_tree`). Дочерние ноды типа `Objective` — цели уровня; их количество и состав = задачи уровня.

- `order`: `PARALLEL` — все обязательные цели активны сразу; `SEQUENTIAL` — по одной сверху вниз (необязательные активны сразу).
- Выполнены все обязательные (`optional = false`) → `all_completed`, затем `finish_mode`:
  - `EXIT` — открываются `LevelExit`, уровень кончается, когда игрок коснётся выхода;
  - `AUTO` — через `auto_finish_delay` (1 с) уровень кончается сам.
- Уровень без обязательных целей выполнен сразу (выход открыт).
- `finish()`: `level_finished`, `PlayerPawn.possess(null)` (инпут никому), `Juice.reset()`, `ScreenFX.transition_to(next_level)` — затемнение → смена сцены (`next_level`, `@export_file`; пусто — перезапуск текущей) → проявление.
- Сигналы для HUD/скриптов: `objective_completed(obj)`, `all_completed`, `level_finished`; `get_active()` — активные цели. Пока пишет в лог через `print`.

**`Objective`** (база, `extends Node`): `description` (текст для HUD), `optional`, `is_active`, `is_completed`, `progress / required`, `get_text()` → «Убей охранника (1/2)». Цикл: `activate()` → `_on_activated()` (наследник подписывается на мир) → `set_progress()` / `complete()` → сигнал `completed`. Новая цель = `extends Objective` + `_on_activated()`.

Готовые цели:

| Цель | Параметры | Как считает |
|---|---|---|
| `ObjectiveKill` | `targets: Array[NodePath]`, `group` (например, `&"enemy"` — «зачистка») | по сигналу `died` целей (есть у `Fighter` и `Turret`); уже мёртвые к активации засчитываются сразу |
| `ObjectiveSignal` | `source`, `signal_name`, `count`, `first_arg` (`ANY` / `TRUE_ONLY` / `FALSE_ONLY`) | нода выпустила сигнал `count` раз; фильтр по первому аргументу (для `Switch.switched(on)`). Покрывает «дёрнуть рычаг», «сломать», «подобрать», «зайти в зону». События до активации не считаются |

Правило для новых убиваемых/ломаемых объектов: эмитить `died` (или свой сигнал для `ObjectiveSignal`).

**`LevelExit`** (`level/level_exit.tscn`, `Area2D`, маска — слой 4, тень не активирует): игрок касается и цели выполнены → `LevelGoals.finish()`. Закрыт — `locked_color` (серый), открыт — `open_color` (зелёный). Если игрок уже стоит в выходе, когда выполнилась последняя цель, — уровень кончается сразу. Без `LevelGoals` выход всегда открыт и перезапускает уровень.

**`ScreenFX.transition_to(path)`** — переход через чёрный экран (пресет `black`), живёт в autoload, поэтому переживает смену сцены. `ScreenFX.clear()` (в т.ч. при рестарте по R/смерти) отменяет незавершённый переход.

Пример в `world.tscn`: `LevelGoals` (PARALLEL, EXIT) с `KillArmored` (убить `EnemyArmored`) и `PullLever` (`Lever.switched` с `TRUE_ONLY`); `LevelExit` на (-385, -29) слева от старта.

## Зрение и свет (`Vision`, `LightSource`)

Стелс-слой: в темноте враги видят хуже, и над их головами / за спиной можно проскочить (при круговой проверке дистанции так не выйдет).

**Когда игрок «на свету»:** только если он внутри `radius` какой-нибудь **включённой** лампы и луч от лампы до него не упирается в стену/дверь. Лампа в соседней комнате ничего не даёт. Исключение — уровень с `LevelLighting.fully_lit`: там светло везде.

**`LightSource`** (`scripts/level/light_source.gd`, `level/light_source.tscn`, `extends PointLight2D`) — лампа: и визуальный свет, и игровое правило. `radius` (игровой радиус; под него подгоняется `texture_scale`, текстура по умолчанию — мягкое радиальное пятно), `blocked_by_walls` + `wall_mask` (стены/двери не пропускают свет — луч от лампы до точки). `LightSource.is_lit(point)` — static, перебирает все лампы (static-список `_all`, без групп). `set_active(on)` — включить/выключить, лампа может быть целью `Switch` (рычаг гасит свет).

**`Vision`** (`scripts/vision.gd`, static-хелпер) — `detects(observer, eye, look_dir, target, sight_range, dark_range, dark_cone_deg, sight_mask)`:

- освещённость проверяется **в точке цели** (игрок прячется в тени, как в стелс-играх);
- на свету — круг `sight_range`; в темноте — `dark_range` и конус `dark_cone_deg` вокруг `look_dir`;
- в любом случае нужна прямая видимость (`has_los`, луч по `sight_mask`, без самого наблюдателя).

Конус влияет **только на обнаружение** (IDLE). Встревоженный враг/турель ведёт цель как раньше — темнота не сбрасывает погоню.

| Кто | `look_dir` | На свету | В темноте |
|---|---|---|---|
| `Enemy` | `Vector2(facing, 0)`; до тревоги — `start_facing` | 250 | 140, конус 70° |
| `Turret` | направление ствола | 300 | 180, конус 40° |

Отладка: при Debug → Visible Collision Shapes невстревоженный враг/турель (IDLE) рисует зону обнаружения — жёлтый круг (игрок на свету) или синий конус (в темноте).

**`LevelLighting`** (`scripts/level/level_lighting.gd`, `extends CanvasModulate`) — освещение уровня, одна нода на уровень:

- `fully_lit = false` (по умолчанию) — стелс: мир затемнён `dark_color`, светло только у ламп, в темноте конусы;
- `fully_lit = true` — боевой/PvP-уровень: визуальной темноты нет, `LightSource.level_fully_lit = true` → `is_lit()` всегда `true` (враги видят кругом), `ViewLight` игрока и тени скрыт (`PlayerPawn._ready`).
- Флаг ставится в `_enter_tree` — раньше любых `_ready`. Без `LevelLighting` на уровне действуют правила темноты при светлой картинке — **ставить в каждый уровень**.

В `world.tscn` (стелс, `LevelLighting` вместо прежней `Darkness`):

| Лампа | Где | Радиус | Зачем |
|---|---|---|---|
| `LightStart` | (-230, -70) | 150 | старт освещён |
| `LightArmored` | (-60, -80) | 110 | над бронированным; гасится рычагом `LeverLights` (-190, -8, `start_on = true`) — пример «погаси свет → подкрадись» |
| `LightPlatform` | (253, -80) | 130 | над мечником на платформе |
| `LightUpper` | (560, -100) | 150 | верхний этаж у турели и мечников |

Остальное — темнота.

**Визуальная темнота и тени (косметика, геймплей не меняет):**

- `world.tscn` → `LevelLighting` (`CanvasModulate`, `dark_color = Color(0.16, 0.16, 0.22)`) — затемняет весь мир (канвас-слой 0). `ScreenFX`, окно диалогов и будущий HUD на своих `CanvasLayer` — не затемняются.
- Окклюдеры: у сплошного тайла (`0:0`) в TileSet — окклюзионный слой `occlusion_layer_0` с квадратом 32×32; one-way платформы свет пропускают (как и взгляд врагов). `Door` — `LightOccluder2D`. Совпадает с правилом `LightSource.blocked_by_walls` (луч по слою 1).
- Лампы (`light_source.tscn`) — `shadow_enabled`, мягкие тени (PCF5); спрайт лампочки `unshaded` — светится сам.
- **Свет игрока** — `character.tscn` → `ViewLight` (обычный `PointLight2D` с тенями, радиус ~200 px): игрок видит вокруг себя, стены отбрасывают тени. **Это НЕ `LightSource`** — иначе игрок всегда был бы «на свету» и конусы врагов перестали бы работать. У тени — свой фиолетовый `ViewLight` (камера переходит на неё).
- Читаемость: пули (`BulletWorld`, материал в `_ready`) и искры (`sparks.tscn`) — `CanvasItemMaterial.light_mode = UNSHADED`, видны в темноте. Кровь — освещается (в темноте темнее — ок).
- Новое правило: всё, что игрок **обязан** видеть в темноте (снаряды, телеграфы атак), — `unshaded` или на своём свете.

## Меню и прогресс (`ui/`, `scripts/ui/`, `Progress`)

**Стартовая сцена** — `ui/main_menu.tscn` (`run/main_scene`). Две панели, видна одна; фокус на первой кнопке (клавиатура/геймпад):

- **«Продолжить»** (без сохранения подписана «Новая игра») → `Progress.get_continue_level()`;
- **«Загрузить»** → список из `LevelCatalog.LEVELS`: открытые уровни кликабельны, закрытые серые с пометкой «(закрыт)»; «Назад» / Esc (`ui_cancel`) — обратно;
- **«Выход»** → `get_tree().quit()`.

Запуск уровня: `Progress.mark_played(путь)` → `ScreenFX.transition_to(путь)` (затемнение). В `_ready` меню снимает паузу дерева.

**`LevelCatalog`** (`scripts/ui/level_catalog.gd`, static) — единственное место со списком уровней: `LEVELS = [{path, title}, …]`, порядок = порядок открытия, первый открыт всегда. **Новый уровень = новая строка здесь** (+ `next_level` у `LevelGoals` предыдущего уровня). Хелперы: `first_path()`, `index_of(path)`, `has(path)`, `title_of(path)`.

**`Progress`** (autoload, `scripts/progress.gd`) — `user://progress.cfg` (ConfigFile, секция `[progress]`: `unlocked` — открытые пути, `last` — цель «Продолжить»). Пишется на диск при каждом изменении; нет файла / битый — чистый прогресс.

| Метод | Что делает |
|---|---|
| `is_unlocked(path)` | открыт ли (первый уровень каталога — всегда) |
| `mark_played(path)` | открыть и сделать целью «Продолжить» (меню при запуске) |
| `complete_level(path, next)` | уровень пройден: открыть `next` и сделать его целью (пустой `next` — текущий). Зовёт `LevelGoals.finish()` |
| `unlock(path)` | открыть без смены цели |
| `get_continue_level()` | последний достигнутый, если он в каталоге и открыт, иначе первый |
| `has_progress()`, `reset_progress()` | есть ли сохранение / стереть |
| `go_to_menu()` | `possess(null)`, `Juice.reset()`, `ScreenFX.transition_to(меню)` |

Esc (`menu`) на уровне → `go_to_menu()`. `process_mode` обычный: во время диалога (пауза дерева) Esc игнорируется — нельзя уйти в меню с поставленной на паузу игрой.

Ограничение: уровень, открытый напрямую (F6) или через `next_level`, считается «достигнутым» только когда его пройдут (`complete_level`) — «Продолжить» ведёт туда же после прохождения.

## Диалоги (`addons/dialogue/`)

Самостоятельный аддон — не зависит от кода игры, переносится в другой проект копированием папки + включением плагина **Dialogue** (добавляет autoload `Dialogue`; в этом проекте autoload и плагин уже прописаны в `project.godot`). Полная справка по синтаксису и API — `addons/dialogue/README.md`.

**Формат** — текстовые файлы `.dlg`, а не JSON: одна строка — одна реплика (`Имя: текст`), ветки — отступами. Узлы `~ имя`, переходы `=> имя` / `=> END`, выборы `- текст [if условие] [once]`, `if/elif/else`, переменные `set x += 1`, вызовы игры `do Juice.shake(0.3)` / `do node("Door").set_active(true)` / `do emit("event")`, подстановки `{выражение}`, теги `#mood=angry`.

**Конвейер:**

```
.dlg ──DialogueFormatLoader──► DialogueParser ──► DialogueResource {code, nodes, errors}
														│
Dialogue.start(res, node, locals) ──► DialogueRunner ◄──┘   (исполняет «байткод» по _ip)
		  │                              │ next() → DialogueLine / choose(i)
		  └──► DialogueBalloon (UI) ─────┘
```

- `DialogueFormatLoader` (`@tool`, `class_name` → регистрируется движком сам) — `.dlg` грузится как обычный ресурс: `load`, `preload`, `@export var d: DialogueResource`, ext_resource в сценах. Файл компилируется при загрузке; ошибки (неизвестный узел, битое выражение, лишний отступ) — в Output с номером строки.
- `DialogueFormatSaver` (`@tool`, `class_name`) — обратное: сохраняет `DialogueResource` в `.dlg` (пишет `source`). Нужен редактору: Duplicate в FileSystem делает load → save, без сохранителя — «File unrecognized». `DialogueResource.source` (`@export_multiline`) хранит исходник, правка в инспекторе перекомпилирует диалог.
- Создание `.dlg` в редакторе: Editor Settings → Docks → FileSystem → TextFile Extensions += `dlg`, затем FileSystem → New → Text File (и правка во встроенном редакторе). Через New Resource → `DialogueResource` получается `.tres` с текстом в `source` — работает, но основной формат — `.dlg`.
- `DialogueParser` компилирует текст в **плоский список инструкций** (`line`, `choice`, `if`, `jump`, `goto`, `set`, `do`, `end`) с переходами по индексам; состояние диалога — один указатель `_ip`. Синтаксис выражений проверяется при загрузке (`Expression.parse`).
- `DialogueRunner` — исполнение без UI: `next()` выполняет инструкции до реплики/выбора, `choose(i)`. Выбор, стоящий сразу за репликой (в т.ч. через `jump`/`=>`), прикрепляется к ней. Защита от циклов без реплик (10 000 шагов).
- Autoload `Dialogue` (`dialogue_manager.gd`, `PROCESS_MODE_ALWAYS`): `start()` ставит дерево на паузу (`pause_game`), создаёт окно, по окончании ждёт кадр (нажатие, закрывшее диалог, не становится прыжком) и снимает паузу. `vars` — все переменные диалогов плюс служебные `__once` / `__visits` — сохранять в сейв целиком. Выражения — Godot `Expression`, имена ищутся: `locals` → `vars` → autoload'ы (ноды под `/root`) → синглтоны движка → глобальные классы → `0`. Функции без точки — методы менеджера: `emit`, `node`, `visited`, `get_var`. Сигналы `started`, `ended`, `line_shown`, `event(name, args)`.
- `DialogueBalloon` (`CanvasLayer`, собирается кодом) — панель внизу, имя, текст с печатной машинкой (реальное время, BBCode), варианты кнопками. Дальше / допечатать — `ui_accept`, `use`, ЛКМ. Замена: `Dialogue.balloon_scene` (сцена с методом `run(runner)`).
- `DialogueTrigger` (`Area2D`) — `ON_USE` (игрок из `body_group` в зоне + `use_action`), `ON_ENTER`, `MANUAL`; `once`; подсказка `prompt`; `set_active(true)` — может быть целью `Switch`. В диалог передаётся локальное имя `trigger`.

**В этом проекте:** `level/npc.tscn` — NPC, корень — `scripts/level/npc.gd` (`extends DialogueTrigger`, `collision_mask = 8` — игрок), подсказка «E». `npc.gd` добавляет правило игры, которого аддон не знает: `can_start()` только когда `PlayerPawn.possessed` — основное тело (управляя тенью, заговорить нельзя). В `world.tscn` — `OldMan` на (-290, -8) между рычагом и стартом, диалог `dialogues/old_man.dlg`: вопросы с `[once]`, после «Кто ты?» открывается вариант, в котором старик открывает дверь через рычаг (`do node("Lever").set_on(true)`), при повторном разговоре — узел `again` по `visited("start")`.

**Правила для диалогов проекта:**

- `Dialogue.vars` — autoload, **переживают рестарт уровня** (смерть, R). Туда — только знание/сюжет (`knows_guard`, счётчики разговоров, `__once`, `__visits`). Состояние уровня (открыта ли дверь, жив ли враг) читать из мира: `node("Lever").is_on`, иначе после рестарта диалог будет врать.
- Менять мир через те же объекты, что и игрок (`Lever.set_on(true)`, а не `Door.set_active`) — чтобы переключатели не расходились с целями и срабатывали `ObjectiveSignal` на их сигналах.
- Правила игры (тень, бой) — в наследниках классов аддона в `scripts/`, сам `addons/dialogue/` остаётся переносимым.
- Во время диалога дерево на паузе — враги, пули, таймеры тени стоят; `Juice`/`ScreenFX`/окно работают (`PROCESS_MODE_ALWAYS`).

## Атака (`melee_attack.gd`)

Дочерняя нода бойца (путь `$MeleeAttack` обязателен для `Fighter`). Хитбокс `Area2D` создаётся один раз в `_ready`. `attack(direction := Vector2.ZERO)` поворачивает его по `direction` (локальные координаты; `ZERO` → к мыши), включает на `active_time`, затем кулдаун. `can_attack()` — готов ли удар, `is_active()` — идёт ли удар сейчас, `cancel()` — погасить удар (клинч). Попадание: если у цели есть `is_attacking()` и он `true`, а у владельца есть `clinch()` → клинч (сигнал `clinched`), иначе цель получает `take_damage(damage, global_position)` и эмитится `hit_landed(hit: HitInfo)` (в т.ч. при блоке — см. `hit.blocked`). Компонент не зависит от `Fighter` напрямую — только duck-typing. Одна цель бьётся максимум раз за взмах; своего владельца (`get_parent()`) хитбокс игнорирует.

**Отладка таймингов** (группа `Debug` в инспекторе; видно при Debug → Visible Collision Shapes): форма хитбокса перекрашивается через `CollisionShape2D.debug_color` — `debug_color_active` (красный) пока удар активен, `debug_color_idle` (почти прозрачный серый) когда выключен и просто висит, `debug_color_cancelled` (синий) если погашен клинчем. Пока удар активен и `deflect_bullets = true`, в `_draw()` рисуется контур зоны отбивания пуль (`hitbox_size + deflect_padding`) цветом `debug_deflect_zone`. Работает для всех `MeleeAttack` — и игрока, и врагов.

## Известные TODO

- Флип спрайта по направлению мыши (`mouse_pos()` пока ничего не делает).
- Анимации (`AnimatedSprite2D` пустой, стоит `PlaceholderTexture2D`).
- Враг запрыгивает только на one-way платформы. На сплошной уступ выше себя — нет, только перепрыгивает стену перед собой.
- В текущем `world.tscn` от пола ямы до платформ 128 px, а прыжок ≈ 82 px: туда не допрыгнуть ни врагу, ни игроку.
- Juice: звук.
- ScreenFX: состояние оглушения игрока (механики пока нет), «мало HP»; вынести `intensity` в настройки.
- Пропы на слое 5 (ящики, лампы) с собственными `HitReaction`.
- Цели: HUD списка целей (сигналы `LevelGoals` готовы), зона-триггер «дойти до точки», таймер «успеть за N сек», неуязвимость игрока во время затемнения.
- Зрение: телеграфы врагов в темноте (жёлтая вспышка замаха/прицеливания через `modulate` в тени почти не видна — сделать unshaded-индикатор); флип спрайтов по `facing`; патрули/повороты врагов в IDLE; шум (удар, выстрел) как способ поднять тревогу; разбиваемые лампы.
- Меню: настройки (громкость, `ScreenFX.intensity`), экран паузы вместо мгновенного выхода по Esc, подтверждение «Новая игра» при существующем сохранении, отметка пройденных уровней в списке.
- Диалоги: портреты/эмоции по тегам (`line.tags`), звук печати, `wait` и ожидание async-вызовов в `do`, сохранение `Dialogue.vars` в сейв, подсветка синтаксиса `.dlg` в редакторе.
- Переключатели: кнопки (`use` на E теперь занят NPC — кнопкам нужно не пересекаться с `DialogueTrigger`), нажимные плиты; другие цели (движущиеся платформы, свет, спавнеры); `set_active` у турели.
- Пули: другие аффекторы (магнит, поле замедления), `MultiMeshInstance2D` при большом количестве.
- Нет неуязвимости после урона.
- Турель: ограничение угла поворота ствола (сейчас 360°), разрушение с эффектом посильнее.
- Тень: HUD кулдауна (есть сигнал `ShadowAbility.state_changed`), ограничение дальности от тела, визуальная связь тело↔тень.
- Смерть игрока — рестарт без анимации/экрана смерти (в духе Katana Zero можно добавить «перемотку»).

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
- **2026-09-24** — Объекты уровня: `Switch` (база переключателей, `targets` → `set_active`, режимы TOGGLE/ONCE/TIMED), `Lever` (удар катаной), `Door` (пример цели); рычаг и дверь в `world.tscn`. `HitReaction.dispatch` вызывает `on_hit(hit)` у самой цели. Документ с диаграммами `docs/architecture.typ` (Typst + cetz). Расширен `.gitignore` (мусор ОС/редакторов, сборки, собранный PDF).
- **2026-09-24** — `MeleeAttack`: отладочные цвета хитбокса (активен / выключен / погашен клинчем) и контур зоны отбивания пуль при Visible Collision Shapes.
- **2026-09-24** — Autoload `ScreenFX` (`scripts/fx/`, `shaders/screen_fx.gdshader`): полноэкранные эффекты-телеграфы — состояния (`enter/exit`) и импульсы (`pulse`), пресеты `ScreenFXPreset`. Пресеты: `shadow` (управление тенью), `clinch`, `kill`, `hurt`. Новое событие `Juice.hurt()` (урон по игроку: тряска + красная виньетка).
- **2026-09-24** — Выпад при ударе: `Fighter.lunge(dir)` (группа `Lunge`, в воздухе один раз до приземления), у игрока `lunge_speed = 320`. Смерть игрока с одного удара (`max_health = 1`) и мгновенный рестарт (`restart_level`, `restart_delay` 0.15 с, клавиша R — действие `restart`). `.gitignore`: `.claude/worktrees/`, `.claude/settings.local.json`.
- **2026-09-24** — Цели и завершение уровня: `LevelGoals` (PARALLEL/SEQUENTIAL, EXIT/AUTO, `next_level`), база `Objective` + `ObjectiveKill`, `ObjectiveSignal`, выход `LevelExit`. `ScreenFX.transition_to(path)` и пресет `black` — переход через чёрный экран. Пример на уровне: убить бронированного + дёрнуть рычаг → выход слева от старта.
- **2026-09-24** — Система диалогов — переносимый аддон `addons/dialogue/`: текстовый формат `.dlg` (узлы, выборы с `[if]`/`[once]`, `if/elif/else`, `set`, `do`, `{подстановки}`, теги), загрузчик ресурса, компиляция в плоский «байткод», `DialogueRunner`, autoload `Dialogue` (переменные, выражения, пауза), стандартное окно `DialogueBalloon`, `DialogueTrigger`. Плагин включён в `project.godot`. Демо: NPC `level/npc.tscn` + `dialogues/old_man.dlg` в `world.tscn` (может открыть дверь). Действие `use` (E) теперь — разговор с NPC.
- **2026-09-24** — Ревью диалогов под проект: `scripts/level/npc.gd` (нельзя заговорить, управляя тенью), `old_man.dlg` читает состояние двери из мира (`node("Lever").is_on`) и открывает её через рычаг — после рестарта диалог не «врёт», рычаг и дверь не расходятся. Раздел «Правила для диалогов проекта».
- **2026-09-24** — Слияние ветки диалогов в master. Связка систем: если старик открывает дверь через рычаг (`Lever.set_on(true)`), засчитывается цель `PullLever` (`ObjectiveSignal` на `Lever.switched`). Ресурсы NPC в `world.tscn` перенумерованы (`15_npc`, `16_old_man`), чтобы не пересекаться с целями уровня.
- **2026-09-25** — Зрение и свет: `LightSource` (лампа = свет + правило освещённости, `set_active` для `Switch`), `Vision` (на свету — круг `sight_range`, в темноте — конус `dark_cone_angle` / `dark_sight_range`, только для обнаружения). `Enemy.start_facing`, новые параметры у `Enemy` и `Turret`, отладочная отрисовка зоны обнаружения. Две лампы в `world.tscn`.
- **2026-09-25** — Косметическая темнота и тени: `CanvasModulate` на уровне, окклюдеры на сплошных тайлах и двери, тени у ламп, `ViewLight` у игрока и тени (не `LightSource`). Пули и искры — unshaded.
- **2026-09-25** — `LevelLighting` (заменил `Darkness`): освещение уровня, опция `fully_lit` для боевых уровней (враги видят кругом, нет темноты, `ViewLight` скрыт). Примеры на уровне: `LightArmored` + рычаг `LeverLights`, который её гасит, `LightUpper` на верхнем этаже.
- **2026-09-25** — Главное меню (`ui/main_menu.tscn` — стартовая сцена): «Продолжить»/«Новая игра», «Загрузить» (список из `LevelCatalog`), «Выход». Autoload `Progress` (`user://progress.cfg`: открытые уровни, цель «Продолжить»), `LevelGoals.finish()` → `Progress.complete_level`. Esc (`menu`) — выход в меню.
- **2026-09-25** — Слой 6 «Проходимо для тени» (`32`): двери переехали на него, тень (маска `3`) проходит сквозь них, пол и стены её держат. Маски игрока и врагов → `35`, пуль/взгляда/света → `Layers.SOLID` (`33`). Константы `scripts/layers.gd`, имена слоёв в Project Settings.
- **2026-09-25** — Тень взаимодействует с объектами: компонент `Interactor` (ищет ноды с `interact(actor) -> bool` на слое пропов), `Switch.interact()` + флаг `interactable`. ЛКМ тенью: захват врага, иначе взаимодействие; управление остаётся у тени.
- **2026-09-26** — Диалоги: `DialogueFormatSaver` — `.dlg` можно дублировать/пересохранять в редакторе (раньше «File unrecognized»); `DialogueResource.source` хранит исходник и редактируется в инспекторе. Подсказка про TextFile Extensions в README.
- **2026-09-26** — `docs/architecture.typ`: глава-приложение «Плагин диалогов изнутри» — справочник языка `.dlg`, API, технический разбор (токенизация, рекурсивный спуск по отступам, набор инструкций, backpatching переходов, пример компиляции «исходник → байткод», цикл `DialogueRunner.next()`, память `[once]`/`visited`, вычисление выражений), анализ сильных сторон и ограничений.
