package coolui;

import flixel.FlxState;

/**
 * CoolUIState — Reemplazo de FlxUIState sin dependencia de flixel-ui.
 *
 * Extiende FlxState y expone transIn / transOut como Dynamic para
 * compatibilidad con estados que los asignan a null (TitleState, PlayState…).
 */
class CoolUIState extends FlxState
{
	/**
	 * Transición de entrada. Asigna null para desactivarla.
	 * Compatible con FlxTransitionableState.transIn.
	 */
	public var transIn  : Dynamic = null;

	/**
	 * Transición de salida. Asigna null para desactivarla.
	 * Compatible con FlxTransitionableState.transOut.
	 */
	public var transOut : Dynamic = null;
}
