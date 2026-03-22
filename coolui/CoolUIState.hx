package coolui;

import flixel.FlxState;

/**
 * CoolUIState — Reemplazo de `FlxUIState` sin dependencia de flixel-ui.
 *
 * `FlxUIState` era básicamente `FlxState` + la interfaz `IFlxUI` para que
 * los widgets de flixel-ui pudieran disparar eventos con `getEvent()`.
 * Como nuestra librería usa callbacks directos (no el bus de eventos de
 * flixel-ui), esta clase solo necesita extender `FlxState`.
 *
 * Migración → en MusicBeatState (y cualquier otra clase que extendía
 * FlxUIState), cambia:
 *
 *   import flixel.addons.ui.FlxUIState;
 *   class MusicBeatState extends FlxUIState
 *
 * por:
 *
 *   import funkin.ui.CoolUIState;
 *   class MusicBeatState extends CoolUIState
 *
 * Todo lo demás queda igual.
 */
class CoolUIState extends FlxState
{
	// Vacío a propósito — toda la lógica viene de FlxState.
	// Si en algún archivo había overrides de getEvent() que respondían a
	// eventos de flixel-ui, se pueden eliminar: los widgets de CoolUI
	// ya los notifican por callback directo.
}
