extends DialogueTrigger

## NPC в нашей игре: DialogueTrigger из аддона + правила проекта.
## Аддон ничего не знает про тень, поэтому ограничение — здесь, а не в addons/:
## заговорить можно, только когда игрок управляет основным телом
## (тело может стоять в зоне NPC, пока управляешь тенью, — тогда E не должен открывать диалог).


func can_start() -> bool:
	var pawn := PlayerPawn.possessed
	return super() and pawn != null and pawn.is_in_group(body_group)
