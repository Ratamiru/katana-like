// Архитектура Katana-like — визуальный обзор.
// Сборка: typst compile docs/architecture.typ  (→ docs/architecture.pdf)
// Текстовый журнал изменений — architecture.md в корне проекта.

#import "@preview/cetz:0.4.2": canvas, draw

#set document(title: "Katana-like — архитектура")
#set page(paper: "a4", margin: (x: 1.8cm, y: 1.8cm), numbering: "1")
#set text(font: "Open Sans", size: 10pt, lang: "ru")
#set heading(numbering: "1.")
#show raw: set text(font: "DejaVu Sans Mono", size: 0.95em)
#set table(stroke: 0.5pt + luma(180), inset: 5pt)
#show table.cell.where(y: 0): set text(weight: "bold")

// ── Палитра и примитивы диаграмм ──

#let c-engine = rgb("#e5e7eb")   // классы движка
#let c-base = rgb("#dbeafe")     // наши базовые классы
#let c-leaf = rgb("#dcfce7")     // конкретные сцены
#let c-comp = rgb("#fef3c7")     // компоненты
#let c-service = rgb("#fce7f3")  // сервисы / синглтоны
#let c-state = rgb("#ede9fe")    // состояния автоматов
#let ink = rgb("#334155")

// Прямоугольник с подписью. pos — центр; name — для стрелок ("name.north" и т.д.).
#let box(pos, name, body, w: 2.6, h: 0.8, bg: c-base) = {
  let (x, y) = pos
  draw.rect((x - w / 2, y - h / 2), (x + w / 2, y + h / 2), name: name, fill: bg, stroke: 0.6pt + ink, radius: 0.1)
  draw.content(name, text(size: 8.5pt, body))
}

// Стрелка по точкам (2+), label — подпись у середины первого отрезка.
#let arrow(..pts, label: none, dashed: false, lpos: 50%, loff: (0, 0.22)) = {
  let p = pts.pos()
  draw.line(..p, mark: (end: ">", fill: ink, scale: 0.7), stroke: (paint: ink, thickness: 0.6pt, dash: if dashed { "dashed" } else { none }))
  if label != none {
    draw.content((rel: loff, to: (p.at(0), lpos, p.at(1))), text(size: 7.5pt, fill: ink, label))
  }
}

#let legend(..items) = {
  set text(size: 8pt)
  grid(columns: items.pos().len() * 2, column-gutter: 4pt, row-gutter: 4pt, align: horizon,
    ..items.pos().map(((c, t)) => (rect(width: 10pt, height: 8pt, fill: c, stroke: 0.5pt + ink), t)).flatten())
}

// ── Титул ──

#align(center)[
  #text(size: 22pt, weight: "bold")[Katana-like]
  #v(-0.6em)
  #text(size: 13pt)[Архитектура проекта]
  #v(-0.4em)
  #text(size: 9pt, fill: luma(100))[Godot 4.7 · GDScript · 2D-платформер с ближним боем в духе Katana Zero]
]

#v(1em)
#outline(depth: 2, indent: 1.2em)
#pagebreak()

= Обзор

Игра строится из трёх слоёв:

- *Тела* — всё, что двигается по правилам платформера, наследуется от `Fighter`: игрок, тень, враги. Наследник не трогает физику, он только задаёт «намерения» (`move_dir`, `jump_requested`, `drop_requested`). Так игрок, AI и тень двигаются одинаково.
- *Компоненты* — дочерние ноды со своей ответственностью: `MeleeAttack`, `GrabAttack`, `ShadowAbility`, реакции на удар `HitReaction`.
- *Сервисы* — общие системы уровня и игры: `Juice` (autoload: замедление, тряска, эффекты), `ScreenFX` (autoload: полноэкранные эффекты), `BulletWorld` (все пули уровня в одной ноде).

Связи между частями по возможности идут через *duck-typing*: удар ищет у цели `take_damage`, `is_attacking`, `on_hit`; переключатель — `set_active`; захват — `grab`. Поэтому новый тип объекта не требует правок в коде атаки.

#legend((c-engine, [класс движка]), (c-base, [наш базовый класс]), (c-leaf, [сцена / конкретный класс]), (c-comp, [компонент]), (c-service, [сервис]))

= Иерархия классов

#figure(canvas(length: 0.85cm, {
  import draw: *
  // движок
  box((4.2, 0), "cb", [`CharacterBody2D`], bg: c-engine, w: 3.2)
  box((12.4, 0), "sb", [`StaticBody2D`], bg: c-engine, w: 2.5)
  box((14.8, 0), "ar", [`Area2D`], bg: c-engine, w: 1.9)
  box((17.3, 0), "ab", [`AnimatableBody2D`], bg: c-engine, w: 2.7)
  // бойцы
  box((4.2, -1.6), "fi", [`Fighter`])
  box((1.2, -3.2), "pp", [`PlayerPawn`])
  box((7.2, -3.2), "en", [`Enemy`])
  box((0, -4.9), "ch", [игрок\ `character.gd`], bg: c-leaf, w: 2.2, h: 1)
  box((2.4, -4.9), "sh", [`Shadow`], bg: c-leaf, w: 2.2, h: 1)
  box((4.8, -4.9), "me", [мечник\ `enemy.tscn`], bg: c-leaf, w: 2.2, h: 1)
  box((7.2, -4.9), "es", [стрелок\ `enemy_shooter`], bg: c-leaf, w: 2.2, h: 1)
  box((9.6, -4.9), "ea", [броня\ `enemy_armored`], bg: c-leaf, w: 2.2, h: 1)
  // остальное
  box((12.4, -1.6), "tu", [`Turret`], bg: c-leaf, w: 2.2)
  box((14.8, -1.6), "sw", [`Switch`], w: 1.9)
  box((14.8, -3.2), "lv", [`Lever`], bg: c-leaf, w: 1.9)
  box((17.3, -1.6), "dr", [`Door`], bg: c-leaf, w: 1.9)

  arrow("fi.north", "cb.south")
  arrow("pp.north", (1.2, -2.4), (4.2, -2.4), "fi.south")
  line("en.north", (7.2, -2.4), (4.2, -2.4), stroke: 0.6pt + ink)
  arrow("ch.north", (0, -4.1), (1.2, -4.1), "pp.south")
  line("sh.north", (2.4, -4.1), (1.2, -4.1), stroke: 0.6pt + ink)
  arrow("es.north", "en.south")
  line("me.north", (4.8, -4.1), (9.6, -4.1), "ea.north", stroke: 0.6pt + ink)
  arrow("tu.north", "sb.south")
  arrow("sw.north", "ar.south")
  arrow("lv.north", "sw.south")
  arrow("dr.north", "ab.south")
}), caption: [Наследование. Стрелка — «наследуется от». Мечник — это сам `Enemy` без переопределений.])

== Из чего собраны сцены

#table(columns: (auto, 1fr, 1fr),
  [Сцена], [Скрипт корня], [Дочерние компоненты],
  [`character.tscn`], [`character.gd` → `PlayerPawn`], [`MeleeAttack` (отражает пули), `ShadowAbility`, `Camera2D`, `HitBlood`, `HitBloodKill`],
  [`shadow.tscn`], [`Shadow` → `PlayerPawn`], [`GrabAttack`, `Camera2D` (выключена до possess)],
  [`enemy.tscn`], [`Enemy`], [`MeleeAttack`, `HitBlood`, `HitBloodKill`],
  [`enemy_shooter.tscn`], [`enemy_shooter.gd` → `Enemy`], [`HitBlood`, `HitBloodKill` (без `MeleeAttack`)],
  [`enemy_armored.tscn`], [`enemy_armored.gd` → `Enemy`], [`MeleeAttack`, `Shield`, `HitBlood`, `HitBloodKill`, `HitSparksBlocked`],
  [`turret.tscn`], [`Turret`], [`Barrel/Muzzle`, `HitSparks`],
  [`level/lever.tscn`], [`Lever` → `Switch`], [`Handle`, `HitSparks`],
  [`level/door.tscn`], [`Door`], [—],
  [`world.tscn`], [—], [`TileMapLayer`, все сущности, `BulletWorld`],
)

У каждого `Fighter` обязательна нода `Collision` (из неё берётся половина роста); `MeleeAttack` — необязателен.

= Физические слои

#table(columns: (auto, auto, 1fr),
  [Слой], [Бит], [Кто на нём],
  [1], [`1`], [Сплошной мир: тайлы, двери],
  [2], [`2`], [One-way платформы (спрыгнуть: `down` + `jump`)],
  [3], [`4`], [Враги (включая турели)],
  [4], [`8`], [Игрок],
  [5], [`16`], [Пропы и переключатели (рычаги)],
)

#let y = sym.checkmark
#figure(table(columns: (1fr, auto, auto, auto, auto, auto),
  align: (left, center, center, center, center, center),
  [Кто → по каким слоям], [1 мир], [2 платф.], [3 враги], [4 игрок], [5 пропы],
  [Тело игрока / врагов / тени (маска)], y, y, [], [], [],
  [Удар игрока (`MeleeAttack.hit_mask = 20`)], [], [], y, [], y,
  [Удар врага (`hit_mask = 8`)], [], [], [], y, [],
  [Пуля стрелка / турели], [стоп], [], [], y, [],
  [Отбитая пуля], [стоп], [], y, [], y,
  [Захват тени (`grab_mask`)], [], [], y, [], [],
  [Взгляд врагов (`sight_mask`)], [стоп], [], [], [], [],
), caption: [Матрица взаимодействий. «стоп» — слой останавливает пулю/луч, но урона нет.])

- Игрок и враги телами *не сталкиваются* — проходят друг сквозь друга.
- Тень на слое 0: её никто не видит и не бьёт.
- Пули — лучи без `collide_with_areas`, поэтому рычаги (`Area2D`) их не останавливают.

= Движение: `Fighter`

#figure(canvas(length: 0.95cm, {
  import draw: *
  let s = 1.25
  box((0, 0), "a", [`_update_intent(delta)` — наследник заполняет намерения], w: 9, bg: c-leaf)
  box((0, -s), "b", [гравитация, если не на полу], w: 9)
  box((0, -2 * s), "c", [скольжение по стене: `vy ≤ wall_slide_max_speed`], w: 9)
  box((0, -3 * s), "d", [`jump_requested`: спрыгнуть → прыжок → отпрыжка от стены], w: 9)
  box((0, -4 * s), "e", [горизонталь: `_control_lock > 0` ? инерция : `move_dir · speed`], w: 9)
  box((0, -5 * s), "f", [`move_and_slide()` (скорость × k при `unscaled_time`)], w: 9)
  for (p, q) in (("a", "b"), ("b", "c"), ("c", "d"), ("d", "e"), ("e", "f")) {
    arrow(p + ".south", q + ".north")
  }
  content((5.2, -1.9), text(size: 7.5pt, fill: ink)[`_control_lock`:\ отпрыжка, отбрасывание,\ клинч — управление\ по X отключено], anchor: "west")
}), caption: [`Fighter._physics_process` — один и тот же для игрока, тени и врагов.])

`unscaled_time` (тень): `delta` делится на `Engine.time_scale`, скорость перед `move_and_slide` умножается на `k = 1/time_scale` — тело живёт в реальном времени, пока мир замедлен.

= Управление телами и тень

== `PlayerPawn.possessed`

Управляемое тело ровно одно — статическая ссылка `PlayerPawn.possessed`. `possess(pawn)` меняет её и переключает камеру. Каждое тело читает инпут, только если `is_possessed()`; остальные получают нулевые намерения.

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 0), "ctl", [`PlayerPawn.possessed`\ (static)], w: 3.6, h: 1, bg: c-service)
  box((-5, -2.6), "bd", [основное тело\ `is_possessed()`], w: 3.2, h: 1, bg: c-leaf)
  box((5, -2.6), "sh", [тень\ `is_possessed()`], w: 3.2, h: 1, bg: c-leaf)
  box((0, -2.6), "in", [Input\ (клавиатура, мышь)], w: 2.8, h: 1, bg: c-engine)
  arrow("ctl.south", (0, -1.2), (-5, -1.2), "bd.north")
  arrow((0, -1.2), (5, -1.2), "sh.north")
  content((0.2, -0.85), anchor: "west", text(size: 7.5pt, fill: ink)[`possessed == self`?])
  arrow("in.west", "bd.east")
  content((-2.4, -2.35), text(size: 7.5pt, fill: ink)[намерения])
  arrow("in.east", "sh.west", dashed: true)
  content((2.4, -2.35), text(size: 7.5pt, fill: ink)[нули])
}), caption: [Инпут получает только тело, на которое указывает `possessed`.])

== Цикл тени: `ShadowAbility`

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 0), "r", [*READY*], bg: c-state, w: 2.2)
  box((4.6, 0), "c", [*CONTROLLING*\ мир × 0.4, управляет тень], bg: c-state, w: 3.6, h: 1.1)
  box((10, 0), "h", [*HOLDING*\ тень держит врага], bg: c-state, w: 3.2, h: 1.1)
  box((14.6, 0), "cd", [*COOLDOWN*], bg: c-state, w: 2.4)
  arrow("r.east", "c.west", label: [ПКМ])
  arrow("c.east", "h.west", label: [ЛКМ: захват])
  arrow("h.east", "cd.west", label: [`hold_time`])
  arrow("c.north", (4.6, 1.3), (14.6, 1.3), "cd.north")
  content((9.6, 1.55), text(size: 7.5pt, fill: ink)[ПКМ ещё раз / `max_control_time` — без захвата])
  arrow("cd.south", (14.6, -1.3), (0, -1.3), "r.south")
  content((7.3, -1.55), text(size: 7.5pt, fill: ink)[`cooldown`])
}), caption: [Состояния способности. При захвате управление и нормальное время сразу возвращаются телу.])

- *CONTROLLING* — `Juice.hold_time_scale(&"shadow", 0.4)`, `possess(shadow)`; основное тело стоит и уязвимо.
- *HOLDING* — `release_time_scale`, `possess(body)`; враг в состоянии `GRABBED` (турель — `JAMMED`).
- Тень: `speed` 340, `unscaled_time`, `GrabAttack` вместо катаны; слой 0.

= AI врагов

== `Enemy` (мечник, стрелок, броня)

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 0), "i", [*IDLE*], bg: c-state, w: 2.2)
  box((5.5, 0), "ch", [*CHASE*\ бег, прыжки, спрыгивание], bg: c-state, w: 3.8, h: 1.1)
  box((11.5, 0), "at", [*ATTACK*\ замах `attack_windup`], bg: c-state, w: 3.6, h: 1.1)
  box((3.2, -3.2), "gr", [*GRABBED*\ схвачен тенью], bg: c-state, w: 3.2, h: 1.1)
  box((11.5, -3.2), "st", [*STUNNED*\ после клинча], bg: c-state, w: 3.2, h: 1.1)
  arrow((1.1, 0.2), (3.6, 0.2))
  content((2.35, 0.5), text(size: 7.5pt, fill: ink)[видит])
  arrow((3.6, -0.2), (1.1, -0.2))
  content((2.35, -0.5), text(size: 7.5pt, fill: ink)[`> lose_range`])
  arrow((7.4, 0.2), (9.7, 0.2))
  content((8.55, 0.5), text(size: 7.5pt, fill: ink)[`≤ attack_range`])
  arrow((9.7, -0.2), (7.4, -0.2))
  content((8.55, -0.5), text(size: 7.5pt, fill: ink)[удар / прерван])
  arrow((4.4, -0.55), (3.4, -2.65))
  content((3.7, -1.5), anchor: "east", text(size: 7.5pt, fill: ink)[захват\ (из любого)])
  arrow((4.2, -2.65), (5.2, -0.55))
  content((4.9, -1.7), anchor: "west", text(size: 7.5pt, fill: ink)[`hold_time`])
  arrow("at.south", "st.north")
  content((11.65, -1.6), anchor: "west", text(size: 7.5pt, fill: ink)[клинч])
  arrow("st.west", (6.6, -3.2), (6.6, -0.55))
  content((8.3, -2.95), text(size: 7.5pt, fill: ink)[`stun_time`])
}), caption: [Автомат `Enemy._update_intent`. В STUNNED/GRABBED враг не разворачивается — окно, чтобы зайти за спину.])

#table(columns: (auto, 1fr, 1fr),
  [Точка расширения], [Мечник (`Enemy`)], [Стрелок],
  [`_can_start_attack()`], [`melee_attack.can_attack()`], [кулдаун прошёл и видит игрока],
  [`_perform_attack(v)`], [`melee_attack.attack(v)`], [`BulletWorld.spawn(...)`],
  [`_should_approach(v)`], [`|v.x| > attack_range/2`], [далеко или не видит],
)

*Броня* (`enemy_armored`): `take_damage` возвращает `false`, если удар со стороны `facing` — блок, искры, отдача игроку. Пробивается в спину, пока враг в STUNNED или GRABBED.

== `Turret`

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 0), "i", [*IDLE*], bg: c-state, w: 2.2)
  box((4.6, 0), "w", [*WARMUP*\ жёлтая вспышка], bg: c-state, w: 3, h: 1.1)
  box((10, 0), "f", [*FIRING*\ `BURST` / `CONTINUOUS`], bg: c-state, w: 3.6, h: 1.1)
  box((4.6, -2.8), "j", [*JAMMED*\ схвачена тенью], bg: c-state, w: 3, h: 1.1)
  arrow("i.east", "w.west", label: [видит])
  arrow("w.east", "f.west", label: [`warmup`])
  arrow("f.north", (10, 1.3), (0, 1.3), "i.north")
  content((5, 1.55), text(size: 7.5pt, fill: ink)[потерял из вида])
  arrow("j.west", (0, -2.8), "i.south")
  content((1.6, -2.55), text(size: 7.5pt, fill: ink)[`hold_time`])
  arrow("f.south", (10, -2.8), "j.east")
  content((10.15, -1.6), anchor: "west", text(size: 7.5pt, fill: ink)[захват\ (из любого)])
}), caption: [Турель — `StaticBody2D`, не `Fighter`. Ствол доворачивается с `turn_speed`, стреляет только наведённым.])

= Поток удара

#figure(canvas(length: 0.95cm, {
  import draw: *
  let cols = (
    ("MeleeAttack\n/ BulletWorld", 0),
    ("цель\ntake_damage", 3.6),
    ("HitReaction\n.dispatch", 7.2),
    ("реакции цели\n/ on_hit", 10.6),
    ("игрок\nhit_landed", 14),
  )
  for (k, (t, x)) in cols.enumerate() {
    box((x, 0), "col" + str(k), text(size: 7.5pt, t), w: 2.9, h: 1, bg: c-comp)
    line((x, -0.5), (x, -7), stroke: (paint: luma(160), dash: "dashed", thickness: 0.5pt))
  }
  let msg(y, x1, x2, t) = {
    arrow((x1, y), (x2, y))
    content(((x1 + x2) / 2, y + 0.25), text(size: 7.5pt, fill: ink, t))
  }
  msg(-1.1, 0, 0, [])
  content((0.15, -1.1), anchor: "west", text(size: 7.5pt, fill: ink)[цель тоже бьёт? → *клинч*, дальше не идём])
  msg(-2.2, 0, 3.6, [`take_damage(dmg, from)`])
  msg(-2.9, 3.6, 0, [`bool` — прошёл? иначе `blocked`])
  msg(-3.8, 0, 7.2, [`HitInfo` (+ `killed`, `blocked`)])
  msg(-4.6, 7.2, 10.6, [`on_hit(hit)`, `react(hit)` по фильтрам])
  content((10.75, -5.3), anchor: "west", text(size: 7.5pt, fill: ink)[кровь, искры,\ рычаг…])
  msg(-6.2, 0, 14, [`hit_landed(hit)` → `Juice.hit / kill / shake`])
}), caption: [Одно попадание катаной или пулей. Реакции живут на цели; атака о них ничего не знает.])

#table(columns: (auto, 1fr),
  [Реакция / фильтр], [Когда срабатывает],
  [`trigger = ANY`], [любой прошедший удар],
  [`NON_LETHAL` / `LETHAL`], [только не смертельный / только смертельный],
  [`BLOCKED`], [только заблокированный (броня)],
  [`kinds`], [`&"melee"`, `&"bullet"`; пусто — все],
  [`on_hit(hit)` на самой цели], [без фильтров — цель решает сама (`Switch`)],
)

= Пули: `BulletWorld`

Все пули уровня — одна нода, данные в packed-массивах (структура массивов). Спавн — `append`, удаление — swap-remove за O(1).

#figure(canvas(length: 0.95cm, {
  import draw: *
  let rows = ("_pos", "_vel", "_life", "_damage", "_hit_mask", "_color")
  let n = 8
  for (r, name) in rows.enumerate() {
    let y = -r * 0.6
    content((-0.3, y), anchor: "east", text(size: 7.5pt, raw(name)))
    for i in range(n) {
      let f = if i == 2 { c-leaf } else if i == n - 1 { c-comp } else { white }
      rect((i * 1.1, y - 0.25), (i * 1.1 + 1, y + 0.25), fill: f, stroke: 0.4pt + ink)
    }
  }
  for i in range(n) {
    content((i * 1.1 + 0.5, 0.55), text(size: 7.5pt, str(i)))
  }
  content((2 * 1.1 + 0.5, 1.05), text(size: 7.5pt, fill: rgb("#15803d"))[удаляем `i`])
  content((7 * 1.1 + 0.5, 1.05), text(size: 7.5pt, fill: rgb("#a16207"))[последняя])
  bezier((7 * 1.1 + 0.5, -3.3), (2 * 1.1 + 0.5, -3.3), (5, -4.4), mark: (end: ">", fill: ink, scale: 0.7), stroke: 0.6pt + ink)
  content((5, -4.3), text(size: 7.5pt)[копируется на место `i`, затем все массивы `resize(n-1)`])
}), caption: [Столбец — одна пуля. Поэтому индекс пули нельзя хранить между кадрами.])

Кадр: аффекторы (`affect_bullets`) → для каждой пули луч `pos → pos + vel·dt` → попадание: урон, `HitInfo`, реакции / искры о стену → `queue_redraw()`.

*Аффекторы* — любой объект с `affect_bullets(bullets, delta)`: отражение катаной (`MeleeAttack.deflect_bullets`), в будущем магниты и поля замедления.

= Сок: `Juice`

#figure(canvas(length: 0.95cm, {
  import draw: *
  let sx = 1.4
  line((0, 0), (11, 0), mark: (end: ">", fill: ink, scale: 0.6), stroke: 0.5pt + ink)
  line((0, 0), (0, 3.4), mark: (end: ">", fill: ink, scale: 0.6), stroke: 0.5pt + ink)
  content((11, -0.3), text(size: 7.5pt)[реальное время])
  content((0.1, 3.6), anchor: "west", text(size: 7.5pt)[`Engine.time_scale`])
  content((-0.2, 3), anchor: "east", text(size: 7.5pt)[1.0])
  content((-0.2, 0.75), anchor: "east", text(size: 7.5pt)[0.25])
  // импульс slow_motion
  let pts = ((0, 3), (1.5, 3), (1.5, 0.75), (3, 0.75))
  let t = 0
  while t <= 1 {
    let e = 1 - calc.pow(1 - t, 2.5)
    pts.push((3 + t * 2.5, 0.75 + e * 2.25))
    t += 0.1
  }
  pts.push((10.5, 3))
  line(..pts, stroke: 1.2pt + rgb("#db2777"))
  content((2.25, 0.45), text(size: 7.5pt)[hold])
  content((4.25, 1.3), text(size: 7.5pt)[recover])
  // удержание тени
  line((6.5, 1.2), (9.5, 1.2), stroke: (paint: rgb("#7c3aed"), thickness: 1pt, dash: "dashed"))
  content((8, 1.45), text(size: 7.5pt, fill: rgb("#7c3aed"))[`hold_time_scale` (тень, 0.4)])
}), caption: [`slow_motion(scale, hold, recover)` — импульс; удержания действуют, пока не отпущены. Итог — минимум из всех.])

#table(columns: (auto, auto, auto, auto, auto),
  [Событие], [scale], [hold], [recover], [тряска],
  [`hit()`], [0.25], [0.06 с], [0.10 с], [0.35],
  [`kill()`], [0.10], [0.12 с], [0.25 с], [0.6],
  [`clinch()`], [0.15], [0.10 с], [0.20 с], [0.5],
  [`hurt()`], [—], [—], [—], [0.4],
)

- Всё считается по *реальному* времени — `Time.get_ticks_usec()`, иначе замедление замедляло бы само себя.
- Тряска: `trauma ∈ [0,1]`, смещение `Camera2D.offset = max · trauma² · шум`.
- `spawn_effect(scene, pos, dir)` — одноразовые эффекты (частицы) в корень уровня.
- `Juice` — единственный владелец `Engine.time_scale`.

= Экранные эффекты: `ScreenFX`

Autoload-оверлей: `CanvasLayer` (слой 100) → один `ColorRect` на весь экран → шейдер, читающий уже нарисованный экран. HUD — на слой выше.

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 1.1), "st", [состояния\ `enter(id)` / `exit(id)`], bg: c-state, w: 3.6, h: 1)
  box((0, -0.3), "pl", [импульсы\ `pulse(name)`], bg: c-state, w: 3.6, h: 1)
  box((5.6, 0.4), "mx", [смешивание\ амплитуды: Σ, обрезка до 1\ цвета: среднее по силе], w: 4.6, h: 1.4)
  box((12, 0.4), "sh", [шейдер\ tint · desaturate\ aberration · vignette], bg: c-service, w: 3.6, h: 1.4)
  arrow("st.east", (2.6, 1.1), (2.6, 0.4), "mx.west")
  arrow("pl.east", (2.6, -0.3), (2.6, 0.4))
  arrow("mx.east", "sh.west", label: [`× intensity`])
  box((0, -1.8), "jc", [`Juice.clinch/kill/hurt`], bg: c-service, w: 3.6)
  box((0, 2.6), "sa", [`ShadowAbility`], bg: c-comp, w: 3.6)
  arrow("jc.north", "pl.south")
  arrow("sa.south", "st.north")
}), caption: [Все активные эффекты каждый кадр сводятся к одному набору параметров шейдера. Нет эффектов — оверлей скрыт.])

#table(columns: (auto, auto, 1fr, 1fr),
  [Пресет], [Вид], [Что на экране], [Кто вызывает],
  [`shadow`], [состояние], [фиолетовая виньетка, мир серее], [`ShadowAbility` (CONTROLLING)],
  [`clinch`], [импульс], [белая вспышка + аберрация], [`Juice.clinch()`],
  [`kill`], [импульс], [аберрация + обесцвечивание], [`Juice.kill()`],
  [`hurt`], [импульс], [красная виньетка], [`Juice.hurt()` ← урон по игроку],
)

- Пресет — `ScreenFXPreset` (Resource): амплитуды слоёв + огибающая `fade_in → hold → fade_out`. Можно делать `.tres` и `register(name, preset)`.
- Время реальное; `intensity = 0` выключает оверлей (доступность).
- События — через `Juice`, длительные состояния — владелец состояния сам делает `enter/exit`.

= Уровень: переключатели и цели

#figure(canvas(length: 0.95cm, {
  import draw: *
  box((0, 0), "atk", [удар катаной], bg: c-comp, w: 2.4)
  box((4.8, 0), "sw", [`Lever` / `Switch`\ `TOGGLE` · `ONCE` · `TIMED`], w: 3.8, h: 1.1)
  box((11.8, 1.3), "d", [`Door.set_active(on)`], bg: c-leaf, w: 4.6)
  box((11.8, 0), "x", [любая нода с `set_active(on)`], bg: c-leaf, w: 4.6)
  box((11.8, -1.3), "sig", [сигнал `switched(on)`], bg: c-engine, w: 4.6)
  arrow("atk.east", "sw.west", label: [`on_hit`])
  arrow("sw.east", (7.9, 0), (7.9, 1.3), "d.west")
  arrow("sw.east", "x.west")
  arrow((7.9, 0), (7.9, -1.3), "sig.west", dashed: true)
  content((8.1, 0.65), anchor: "west", text(size: 7.5pt, fill: ink)[`targets`])
}), caption: [Переключатель не знает, чем управляет: он вызывает `set_active` у всех `targets` и эмитит сигнал.])

- `Switch` — `Area2D` на слое 5: хитбокс удара его видит, ходьбе и пулям он не мешает.
- Новый переключатель (кнопка, нажимная плита, терминал) = `extends Switch`, вызывает `activate()` по своему событию.
- Новая цель (платформа, свет, спавнер) = любая нода с `set_active(on: bool)`.
- `Door` — `AnimatableBody2D` на слое 1: открывается сдвигом на `open_offset`, `inverted` — наоборот.

= Инпут

#table(columns: (auto, auto, 1fr),
  [Action], [Клавиша], [Что делает],
  [`forward` / `backward`], [D / A], [бег],
  [`jump`], [Space], [прыжок, отпрыжка от стены],
  [`down` + `jump`], [S + Space], [спрыгнуть с платформы],
  [`attack`], [ЛКМ], [действие управляемого тела: катана / захват],
  [`shadow`], [ПКМ], [выпустить / отменить тень],
  [`use`], [E], [зарезервировано (кнопки — в обсуждении)],
)
