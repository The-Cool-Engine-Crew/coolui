package coolui;

import flixel.group.FlxSpriteGroup;

/**
 * CoolUIGroup — Reemplazo de `FlxUIGroup`.
 *
 * En flixel-ui, `FlxUIGroup` era un `FlxSpriteGroup` con la interfaz `IFlxUI`
 * para participar en el bus de eventos. Aquí es simplemente un
 * `FlxSpriteGroup` con un campo `name` para que `CoolTabMenu` identifique
 * cada panel de pestaña.
 *
 * Uso (idéntico al anterior):
 *
 *   var tab = new CoolUIGroup();
 *   tab.add(new CoolInputText(...));
 *   tabMenu.addGroup(tab);
 *
 * Si necesitas hacer scroll del contenido, ajusta `scrollFactor` en los
 * hijos o usa el parámetro `scrollFactor` del constructor.
 */
class CoolUIGroup extends FlxSpriteGroup
{
	/** Nombre que usa `CoolTabMenu` para asociar el grupo a su pestaña. */
	public var name:String = "";

	public function new(x:Float = 0, y:Float = 0)
	{
		super(x, y);
	}
}
