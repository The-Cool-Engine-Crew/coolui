package coolui;

import coolui.CoolTheme;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;



/**
 * CoolTabMenu — Tab menu 100 % nativo, sin dependencia de flixel-ui.
 *
 * Reemplaza tanto `FlxUITabMenu` como el `CoolTabMenu` que estaba en
 * `funkin.debug` (que extendía `FlxUITabMenu`). Mueve este archivo a
 * `source/funkin/ui/` y actualiza los imports.
 *
 * API compatible con la versión anterior:
 *
 *   var menu = new CoolTabMenu(null, [
 *     {name:"tab1", label:"Propiedades"},
 *     {name:"tab2", label:"Animaciones"},
 *   ], true);
 *   menu.resize(300, 400);
 *   menu.addGroup(myGroup);
 *   menu.selected_tab_id = "tab1";
 *
 * Diferencias respecto a la versión anterior:
 *  • NO extiende FlxUITabMenu → cero dependencias de flixel-ui.
 *  • `addGroup()` recibe un `CoolUIGroup` (en vez de `FlxUIGroup`).
 *    Si pasas `FlxSpriteGroup` normal también funciona por duck-typing.
 *  • `selected_tab_id` es una propiedad con setter (antes era field de FlxUITabMenu).
 */
class CoolTabMenu extends FlxSpriteGroup
{
	// ── Constantes de diseño ────────────────────────────────────────────────

	public static inline var TAB_BAR_H  : Int   = 28;
	public static inline var ACCENT_BAR : Int   = 2;
	public static inline var TAB_FONT   : Int   = 10;
	static         inline var FADE_TIME : Float = 0.08;

	// ── Estado interno ──────────────────────────────────────────────────────

	var _tabDefs  : Array<{name:String, label:String}>;
	var _groups   : Map<String, FlxSpriteGroup> = new Map();
	var _pw       : Int = 300;
	var _ph       : Int = 400;

	// Chrome
	var _tabBarBg   : FlxSprite;
	var _tabBarLine : FlxSprite;
	var _bodyBg     : FlxSprite;
	var _tabBtns    : Array<_TabBtn> = [];
	var _fadeTween  : FlxTween;

	var _selectedId : String = "";

	// ── Propiedad selected_tab_id ───────────────────────────────────────────

	public var selected_tab_id(get, set):String;

	function get_selected_tab_id():String  return _selectedId;
	function set_selected_tab_id(id:String):String
	{
		if (_selectedId == id) return id;
		_selectedId = id;
		_syncGroupVisibility();
		_updateHighlights();
		_fadeBody();
		return id;
	}

	// ── Constructor ─────────────────────────────────────────────────────────

	/**
	 * @param back_    Ignorado (existía en FlxUITabMenu para el fondo). Puede ser null.
	 * @param tabs     Lista de tabs: [{name:"id", label:"Texto visible"}, ...]
	 * @param wrap     Si true, al llegar al último tab vuelve al primero con flechas.
	 *                 (reservado para futura implementación; actualmente no afecta).
	 */
	public function new(?back_:FlxSprite, tabs:Array<{name:String, label:String}>, wrap:Bool = true)
	{
		super();
		_tabDefs = tabs ?? [];
		if (_tabDefs.length > 0)
			_selectedId = _tabDefs[0].name;
		_buildChrome();
	}

	// ── API pública ─────────────────────────────────────────────────────────

	/** Cambia el tamaño del panel. Llama después de new() si necesitas un tamaño distinto. */
	public function resize(w:Float, h:Float):Void
	{
		_pw = Std.int(w);
		_ph = Std.int(h);
		_buildChrome();
		_repositionGroups();
	}

	/**
	 * Asocia un grupo de widgets a la pestaña cuyo `name` coincide con
	 * `group.name`. Si el grupo no tiene nombre asignado, se usa el orden
	 * de llamada (primer addGroup → primera pestaña, etc.).
	 */
	public function addGroup(group:FlxSpriteGroup):Void
	{
		// Intentar nombre via duck-typing
		var gName:String = "";
		try { gName = Reflect.field(group, "name") ?? ""; } catch (_:Dynamic) {}

		// Si no tiene nombre, asignamos por orden de inserción
		if (gName == "")
		{
			var idx = Lambda.count(_groups);
			if (idx < _tabDefs.length)
				gName = _tabDefs[idx].name;
		}

		if (gName == "") return;

		_groups.set(gName, group);

		// Posicionar debajo de la barra de tabs
		_placeGroup(group);
		add(group);

		// Visibilidad inicial
		group.visible = (gName == _selectedId);
	}

	/** Refresca los colores del chrome cuando cambia el tema. */
	public function refresh():Void
	{
		_buildChrome();
	}

	// ── Gestión de grupos ───────────────────────────────────────────────────

	function _syncGroupVisibility():Void
	{
		for (id => group in _groups)
			group.visible = (id == _selectedId);
	}

	function _placeGroup(group:FlxSpriteGroup):Void
	{
		group.x = x;
		group.y = y + TAB_BAR_H + 1;
		// Los hijos usan scrollFactor del padre; si quieres fijarlos en pantalla
		// usa scrollFactor.set(0,0) en cada widget del grupo.
	}

	function _repositionGroups():Void
	{
		for (group in _groups)
			_placeGroup(group);
	}

	// ── Chrome ──────────────────────────────────────────────────────────────

	function _buildChrome():Void
	{
		var T  = coolui.CoolUITheme.current;
		_destroyOwnChrome();

		var pw = (_pw > 0) ? _pw : 300;
		var ph = (_ph > 0) ? _ph : 400;

		// Fondo de la barra de tabs
		_tabBarBg = new FlxSprite(0, 0);
		_tabBarBg.makeGraphic(pw, TAB_BAR_H, T.bgPanelAlt);
		_tabBarBg.scrollFactor.set();
		add(_tabBarBg);

		// Línea separadora accent
		_tabBarLine = new FlxSprite(0, TAB_BAR_H);
		_tabBarLine.makeGraphic(pw, 1, T.accent);
		_tabBarLine.alpha = 0.4;
		_tabBarLine.scrollFactor.set();
		add(_tabBarLine);

		// Body
		var bodyH = ph - TAB_BAR_H - 1;
		_bodyBg = new FlxSprite(0, TAB_BAR_H + 1);
		_bodyBg.makeGraphic(pw, (bodyH > 0) ? bodyH : 1, T.bgPanel);
		_bodyBg.scrollFactor.set();
		add(_bodyBg);

		// Botones de tab
		_buildTabBtns(pw, T);
		_updateHighlights();
	}

	function _buildTabBtns(pw:Int, T:CoolTheme):Void
	{
		for (b in _tabBtns) { remove(b, true); b.destroy(); }
		_tabBtns = [];
		if (_tabDefs == null || _tabDefs.length == 0) return;

		var n    = _tabDefs.length;
		var btnW = Std.int(pw / n);
		var last = pw - btnW * (n - 1);

		for (i in 0...n)
		{
			var bw  = (i == n - 1) ? last : btnW;
			var btn = new _TabBtn(btnW * i, 0, bw, TAB_BAR_H,
			                     _tabDefs[i].label, _tabDefs[i].name, T);
			btn.scrollFactor.set();
			btn.onClick = function(name:String) { selected_tab_id = name; };
			_tabBtns.push(btn);
			add(btn);
		}
	}

	function _updateHighlights():Void
	{
		var T = coolui.CoolUITheme.current;
		for (b in _tabBtns)
			b.setActive(b.tabName == _selectedId, T);
	}

	function _fadeBody():Void
	{
		if (_fadeTween != null) _fadeTween.cancel();
		if (_bodyBg == null) return;
		_bodyBg.alpha = 0.55;
		_fadeTween = FlxTween.globalManager.tween(
			_bodyBg, {alpha: 1.0}, FADE_TIME, {ease: FlxEase.quartOut}
		);
	}

	function _destroyOwnChrome():Void
	{
		if (_fadeTween  != null) { _fadeTween.cancel(); _fadeTween = null; }
		for (b in _tabBtns)     { remove(b, true); b.destroy(); }
		_tabBtns = [];
		inline function _kill(s:FlxSprite):Void
			if (s != null) { remove(s, true); s.destroy(); }
		_kill(_bodyBg);     _bodyBg     = null;
		_kill(_tabBarLine); _tabBarLine = null;
		_kill(_tabBarBg);   _tabBarBg   = null;
	}

	override public function destroy():Void
	{
		_destroyOwnChrome();
		super.destroy();
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// _TabBtn — botón de pestaña individual (privado al módulo)
// ─────────────────────────────────────────────────────────────────────────────

private class _TabBtn extends FlxSpriteGroup
{
	public var tabName : String;
	public var onClick : String -> Void;

	var _bg        : FlxSprite;
	var _underline : FlxSprite;
	var _label     : FlxText;

	var _bw       : Int;
	var _bh       : Int;
	var _isActive : Bool = false;
	var _isHover  : Bool = false;

	public function new(bx:Float, by:Float, bw:Int, bh:Int,
	                    labelStr:String, name:String, T:CoolTheme)
	{
		super(bx, by);
		tabName = name;
		_bw = bw;
		_bh = bh;

		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(bw, bh, T.bgHover);
		add(_bg);

		_underline = new FlxSprite(0, bh - CoolTabMenu.ACCENT_BAR);
		_underline.makeGraphic(bw, CoolTabMenu.ACCENT_BAR, T.accent);
		_underline.visible = false;
		add(_underline);

		var sep = new FlxSprite(bw - 1, 3);
		sep.makeGraphic(1, bh - 6, T.borderColor);
		sep.alpha = 0.2;
		add(sep);

		_label = new FlxText(0, 0, bw, labelStr, CoolTabMenu.TAB_FONT);
		_label.alignment = CENTER;
		_label.color     = FlxColor.fromInt(T.textSecondary);
		_label.alpha     = 0.75;
		_label.scrollFactor.set();
		_label.y = Std.int((bh - _label.height) * 0.5) - 1;
		add(_label);
	}

	public function setActive(active:Bool, T:CoolTheme):Void
	{
		_isActive = active;
		if (active)
		{
			var c = FlxColor.fromInt(T.accent);
			c.alphaFloat = 0.18;
			_bg.makeGraphic(_bw, _bh, c);
			_label.color = FlxColor.WHITE;
			_label.alpha = 1.0;
			_underline.makeGraphic(_bw, CoolTabMenu.ACCENT_BAR, T.accent);
			_underline.visible = true;
		}
		else
		{
			_bg.makeGraphic(_bw, _bh, T.bgHover);
			_label.color = FlxColor.fromInt(T.textSecondary);
			_label.alpha = _isHover ? 1.0 : 0.75;
			_underline.visible = false;
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		var hover = (FlxG.mouse.x >= x && FlxG.mouse.x <= x + _bw
		          && FlxG.mouse.y >= y && FlxG.mouse.y <= y + _bh);

		if (hover != _isHover)
		{
			_isHover = hover;
			if (!_isActive)
				_label.alpha = hover ? 1.0 : 0.75;
		}
		if (hover && FlxG.mouse.justPressed && onClick != null)
			onClick(tabName);
	}

	override public function destroy():Void
	{
		onClick = null;
		super.destroy();
	}
}
