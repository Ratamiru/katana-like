# Dialogue — ветвящиеся диалоги для Godot 4.5+

Диалоги пишутся в обычных текстовых файлах `.dlg` — одна строка = одна реплика.
Без JSON, без редактора-графа: открыл в любом редакторе и пишешь сценарий.

## Подключение к проекту

1. Скопировать папку `addons/dialogue/` в проект.
2. Project → Project Settings → Plugins → включить **Dialogue** (добавит autoload `Dialogue`).
   Или добавить autoload вручную: `Dialogue` → `res://addons/dialogue/dialogue_manager.gd`.
3. Создать `.dlg`-файл, перетащить его в поле `dialogue` у `DialogueTrigger` или вызвать
   `Dialogue.start(preload("res://dialogues/npc.dlg"))`.

Если в экспортированной игре диалоги не находятся — добавить `*.dlg` в
Export → Resources → «Filters to export non-resource files».

Чтобы создавать и править `.dlg` прямо в Godot: Editor Settings → Docks → FileSystem →
**TextFile Extensions** — добавить `dlg`. Тогда FileSystem → New → Text File… умеет создавать `.dlg`,
а двойной клик открывает его во встроенном редакторе. Создавать диалог через
New Resource → `DialogueResource` (.tres) тоже можно — текст пишется в поле `source` в инспекторе.

## Синтаксис `.dlg`

Пояснения справа после `#` — только для этой справки: в файле комментарий пишется отдельной строкой,
а `#слово` в конце реплики — это тег. Живой пример — `dialogues/old_man.dlg`.

```
# комментарий (только с начала строки)

~ start                           # узел — точка входа, на него можно прыгать
Кенжи: Привет, {player_name}!     # реплика «Имя: текст»; {выражение} подставляется
Просто текст без имени — рассказчик.
Кенжи: Я зол. #mood=angry #shake  # теги в конце строки → line.tags
Кенжи: [color=red]BBCode[/color] работает.

- Кто ты?                         # варианты выбора — подряд идущие строки «- »
	Кенжи: Никто.                 # тело варианта — с отступом
	=> start                      # переход в узел
- Дай денег [if gold < 10]        # вариант виден только при условии
- Расскажи ещё [once]             # вариант пропадает после выбора (навсегда, хранится в vars)
- Уйти
	=> END                        # конец диалога
Кенжи: Сюда сходятся все ветки, которые не ушли через =>.

set met = true                    # переменные (глобальные, Dialogue.vars)
set gold += 10                    # += -= *= /=
if gold > 100:                    # if / elif / else, двоеточие необязательно
	Кенжи: Богач.
elif met:
	Кенжи: Снова ты.
else:
	Кенжи: Кто ты такой?

do Juice.shake(0.3)               # вызвать код игры: autoload'ы видны по имени
do node("Door").set_active(true)  # нода текущей сцены по имени/пути
do emit("boss_fight", 2)          # сигнал Dialogue.event(&"boss_fight", [2])
do trigger.queue_free()           # локальные имена из start(..., {trigger = self})
```

- Отступ — табы или пробелы (таб = 4), главное — единообразно внутри блока.
- Текст до первого `~` — это неявный узел `start`. В конце узла диалог заканчивается (если не было `=>`).
- Реплика сразу перед вариантами показывается вместе с ними.
- Строка, начинающаяся с `set`/`do`/`if`/`- `, — команда. Если нужна такая реплика — начните её с `\`.
  Двоеточие, не отделяющее имя, экранируется: `Время\: полночь`.
- Ошибки (неизвестный узел, битое выражение, лишний отступ) пишутся в Output при загрузке файла с номером строки.

### Выражения

Выражения — это Godot `Expression` (синтаксис как в GDScript: `and`, `or`, `not`, `==`, методы, `randi_range()`…).
Имена ищутся по порядку: локальные из `start()` → `Dialogue.vars` → autoload'ы → синглтоны движка →
глобальные классы (`class_name`, для static) → иначе `0` (т.е. `false`).

Встроенные функции: `visited("узел")` — сколько раз заходили в узел, `node("путь")`, `emit("имя", ...)`,
`get_var("имя", по_умолчанию)`.

## API

```gdscript
Dialogue.start(dialogue, node := "start", locals := {}) -> DialogueRunner  # показать с окном
Dialogue.create_runner(dialogue, node, locals) -> DialogueRunner          # без окна
Dialogue.is_active() / Dialogue.stop()
Dialogue.vars                     # сохраняйте в сейв — там все переменные и выборы
Dialogue.pause_game = true        # ставить дерево на паузу во время диалога
Dialogue.balloon_scene = preload("res://ui/my_balloon.tscn")  # своё окно: метод run(runner)

signal started(resource) / ended(resource) / line_shown(line) / event(name, args)
```

Свой UI крутит раннер сам:

```gdscript
var line := runner.next()          # DialogueLine или null (конец)
line.speaker, line.text, line.tags, line.choices  # choices: [{text, tags}]
runner.choose(i)                   # после реплики с вариантами
```

`DialogueTrigger` (Area2D): режимы `ON_USE` (подойти и нажать `use_action`), `ON_ENTER`, `MANUAL`;
`once`, `body_group`, подсказка `prompt`. Метод `set_active(true)` — можно делать целью переключателя.

## Локализация

Текст реплик и вариантов проходит через `tr()` до подстановки `{…}` — ключом перевода служит исходная строка.

## Файлы

| Файл | Что это |
|---|---|
| `dialogue_parser.gd` | `.dlg` → плоский список инструкций + таблица узлов |
| `dialogue_resource.gd` | `DialogueResource` — скомпилированный диалог |
| `dialogue_format_loader.gd` | учит `load()` понимать `.dlg` |
| `dialogue_format_saver.gd` | сохраняет `DialogueResource` обратно в `.dlg` (Duplicate / Save As в редакторе) |
| `dialogue_runner.gd` | `DialogueRunner` — исполнение по шагам, без UI |
| `dialogue_line.gd` | `DialogueLine` — одна реплика для показа |
| `dialogue_manager.gd` | autoload `Dialogue` — старт, переменные, выражения |
| `dialogue_balloon.gd` | `DialogueBalloon` — стандартное окно |
| `dialogue_trigger.gd` | `DialogueTrigger` — зона запуска диалога |
