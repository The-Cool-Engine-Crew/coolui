package coolui;

import flixel.FlxState;

/**
 * CoolUIState — Drop-in replacement for FlxUIState, no flixel-ui required.
 *
 * Extends FlxState and exposes transIn / transOut as Dynamic for
 * compatibility with states that assign them to null (TitleState, PlayState…).
 */
class CoolUIState extends FlxState {
	/**
	 * Entry transition. Assign null to disable it.
	 * Compatible with FlxTransitionableState.transIn.
	 */
	public var transIn:Dynamic = null;

	/**
	 * Exit transition. Assign null to disable it.
	 * Compatible with FlxTransitionableState.transOut.
	 */
	public var transOut:Dynamic = null;
}
