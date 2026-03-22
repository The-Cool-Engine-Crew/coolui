package coolui;

import flixel.group.FlxSpriteGroup;

/**
 * CoolUIGroup — Drop-in replacement for `FlxUIGroup`.
 *
 * In flixel-ui, `FlxUIGroup` was a `FlxSpriteGroup` implementing `IFlxUI`
 * to participate in the event bus. Here it is simply a
 * `FlxSpriteGroup` with a `name` field so `CoolTabMenu` can identify
 * each tab panel.
 *
 * Usage (identical to before):
 *
 *   var tab = new CoolUIGroup();
 *   tab.add(new CoolInputText(...));
 *   tabMenu.addGroup(tab);
 *
 * To scroll the content, adjust `scrollFactor` on children
 * or use the constructor's `scrollFactor` parameter.
 */
class CoolUIGroup extends FlxSpriteGroup
{
	/** Name used by `CoolTabMenu` to match this group to its tab. */
	public var name:String = "";

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
	}
}
