package coolui;

import coolui.CoolTheme;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;


/**
 * CoolDropDown — Reemplazo de `FlxUIDropDownMenu` sin flixel-ui.
 *
 * API compatible:
 *
 *   // Con array de strings
 *   var dd = new CoolDropDown(x, y,
 *     CoolDropDown.makeStrIdLabelArray(["Opción A", "Opción B"]),
 *     function(id:String) { trace(id); }
 *   );
 *
 *   // Con header personalizado
 *   var dd = new CoolDropDown(x, y, data, cb,
 *     new CoolDropDown.DropDownHeader("Selecciona...", new CoolDropDown.DropDownHeaderStyle())
 *   );
 *
 *   dd.selectedLabel   // texto de la opción activa
 *   dd.selectedId      // id de la opción activa
 *
 * El dropdown se abre hacia abajo. Si no cabe en pantalla, se abre hacia arriba.
 * Clic fuera del dropdown lo cierra.
 *
 * Nota: a diferencia de FlxUIDropDownMenu, la lista flotante se gestiona con
 * `FlxG.state.add/remove` para que quede encima de todos los demás elementos.
 * Si lo usas en un SubState, pasa el grupo contenedor al constructor o llama
 * `setStateTarget(grupo)` antes de añadir al estado.
 */
/** Estructura de datos de cada opción. Compatible con StrNameLabel de flixel-ui. */
typedef DropDownData = { name:String, label:String }

/** Cabecera del dropdown (label del botón cerrado). */
typedef DropDownHeader = { text:String, ?style:DropDownHeaderStyle }
typedef DropDownHeaderStyle = { ?fontSize:Int, ?color:Int }

class CoolDropDown extends FlxSpriteGroup
{
	// ── Tipos públicos ───────────────────────────────────────────────────────

	public static inline var ROW_H : Int = 18;

	// ── Propiedades públicas ─────────────────────────────────────────────────

	/** Callback al seleccionar: `callback(id:String)`. */
	public var callback : String -> Void;

	public var selectedLabel(get, set) : String;
	public var selectedId(get, never)  : String;

	// ── Internals ────────────────────────────────────────────────────────────

	var _data        : Array<DropDownData>;
	var _selectedIdx : Int = 0;
	var _w           : Int;
	var _header      : DropDownHeader;

	var _btnBg    : FlxSprite;
	var _btnLabel : FlxText;
	var _btnArrow : FlxText;

	var _list        : _DropList;
	var _listTarget  : FlxGroup; // grupo donde se monta la lista flotante

	// ── Constructor ──────────────────────────────────────────────────────────

	/**
	 * @param px       X
	 * @param py       Y
	 * @param data     Array de {name, label}
	 * @param callback Llamado con el `name` del item seleccionado
	 * @param header   Texto/estilo del botón cerrado (opcional)
	 * @param _unused1 Ignorado (compat FlxUIDropDownMenu)
	 * @param _unused2 Ignorado (compat FlxUIDropDownMenu)
	 * @param width    Ancho (por defecto 120)
	 */
	public function new(px:Float = 0, py:Float = 0,
	                    data:Array<DropDownData>,
	                    ?callback:String->Void,
	                    ?header:DropDownHeader,
	                    _unused1:Dynamic = null, _unused2:Dynamic = null,
	                    width:Int = 120)
	{
		super(px, py);
		_data     = data ?? [];
		_w        = width;
		_header   = header ?? {text: _data.length > 0 ? _data[0].label : "—"};
		this.callback = callback;
		_build();
	}

	// ── Helpers estáticos ────────────────────────────────────────────────────

	/**
	 * Convierte un array de strings a la estructura de datos del dropdown.
	 * Compatible con `FlxUIDropDownMenu.makeStrIdLabelArray`.
	 */
	public static function makeStrIdLabelArray(arr:Array<String>, useIndexAsId:Bool = false)
		: Array<DropDownData>
	{
		return [for (i => s in arr) {name: useIndexAsId ? Std.string(i) : s, label: s}];
	}

	// ── Getters ──────────────────────────────────────────────────────────────

	function get_selectedLabel():String
		return (_selectedIdx >= 0 && _selectedIdx < _data.length) ? _data[_selectedIdx].label : "";

	function set_selectedLabel(v:String):String
	{
		for (i in 0..._data.length)
		{
			if (_data[i].label == v) { _selectedIdx = i; break; }
		}
		if (_btnLabel != null) _btnLabel.text = v;
		return v;
	}

	function get_selectedId():String
		return (_selectedIdx >= 0 && _selectedIdx < _data.length) ? _data[_selectedIdx].name : "";

	// ── Build ────────────────────────────────────────────────────────────────

	function _build():Void
	{
		var T = coolui.CoolUITheme.current;

		_btnBg = new FlxSprite(0, 0);
		_btnBg.makeGraphic(_w, ROW_H, T.bgPanelAlt);
		add(_btnBg);

		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.7;
		_drawBorder(_btnBg, brd);

		_btnLabel = new FlxText(4, 1, _w - 20, _header.text, 8);
		_btnLabel.color = FlxColor.fromInt(T.textPrimary);
		_btnLabel.scrollFactor.set();
		add(_btnLabel);

		_btnArrow = new FlxText(_w - 14, 1, 12, "▾", 9);
		_btnArrow.color = FlxColor.fromInt(T.accent);
		_btnArrow.scrollFactor.set();
		add(_btnArrow);
	}

	function _drawBorder(s:FlxSprite, c:FlxColor):Void
	{
		var w = s.frameWidth; var h = s.frameHeight;
		var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	// ── Update ───────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Clic en el botón del dropdown
		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.x; var my = FlxG.mouse.y;
			var inBtn = mx >= x && mx <= x + _w && my >= y && my <= y + ROW_H;

			if (inBtn)
			{
				if (_list == null) _openList();
				else               _closeList();
			}
			else if (_list != null && !_list.containsMouse(FlxG.mouse.x, FlxG.mouse.y))
			{
				_closeList();
			}
		}
	}

	// ── Lista flotante ───────────────────────────────────────────────────────

	function _openList():Void
	{
		var T = coolui.CoolUITheme.current;
		var maxVisible = 8;
		var listH = Math.min(_data.length, maxVisible) * ROW_H;
		var openDown = (y + ROW_H + listH < FlxG.height);
		var listY = openDown ? (y + ROW_H) : (y - listH);

		_list = new _DropList(x, listY, _w, _data, _selectedIdx,
		                      T, function(idx:Int)
		{
			_selectedIdx   = idx;
			_btnLabel.text = _data[idx].label;
			_closeList();
			if (callback != null) callback(_data[idx].name);
		});

		// Añadir al estado / grupo más alto disponible
		var target:FlxGroup = (_listTarget != null) ? _listTarget : FlxG.state;
		target.add(_list);
	}

	function _closeList():Void
	{
		if (_list == null) return;
		var target:FlxGroup = (_listTarget != null) ? _listTarget : FlxG.state;
		target.remove(_list, true);
		_list.destroy();
		_list = null;
	}

	/** Establece el grupo donde se montará la lista flotante. */
	public function setStateTarget(g:FlxGroup):Void
		_listTarget = g;

	override public function destroy():Void
	{
		_closeList();
		callback = null;
		super.destroy();
	}
}

// ─────────────────────────────────────────────────────────────────────────────
// _DropList — lista flotante renderizada como sprite group
// ─────────────────────────────────────────────────────────────────────────────

private class _DropList extends FlxSpriteGroup
{
	static inline var MAX_VISIBLE : Int = 8;

	var _data     : Array<{name:String, label:String}>;
	var _selected : Int;
	var _onSelect : Int -> Void;
	var _w        : Int;
	var _scroll   : Int = 0;

	public function new(lx:Float, ly:Float, w:Int, data, selected:Int,
	                    T:CoolTheme, onSelect:Int->Void)
	{
		super(lx, ly);
		_data     = data;
		_selected = selected;
		_w        = w;
		_onSelect = onSelect;
		_build(T);
	}

	function _build(T:CoolTheme):Void
	{
		var visible = Std.int(Math.min(_data.length, MAX_VISIBLE));
		var h = visible * CoolDropDown.ROW_H;

		// Fondo
		var bg = new FlxSprite(0, 0);
		bg.makeGraphic(_w, h, T.bgPanel);
		add(bg);

		// Borde
		var brdCol = FlxColor.fromInt(T.borderColor);
		brdCol.alphaFloat = 0.9;
		var bw = _w; var bh = h;
		var p = bg.pixels;
		for (i in 0...bw) { p.setPixel32(i, 0, brdCol); p.setPixel32(i, bh-1, brdCol); }
		for (j in 0...bh) { p.setPixel32(0, j, brdCol); p.setPixel32(bw-1, j, brdCol); }
		bg.pixels = p;

		for (i in 0...visible)
		{
			var idx = i + _scroll;
			var rowBg = new FlxSprite(1, i * CoolDropDown.ROW_H);
			var rowColor = (idx == _selected)
				? FlxColor.fromInt(T.rowSelected)
				: (i % 2 == 0 ? FlxColor.fromInt(T.rowEven) : FlxColor.fromInt(T.rowOdd));
			rowBg.makeGraphic(_w - 2, CoolDropDown.ROW_H, rowColor);
			add(rowBg);

			var lbl = new FlxText(5, i * CoolDropDown.ROW_H + 1, _w - 10, _data[idx].label, 8);
			lbl.color = FlxColor.fromInt(idx == _selected ? T.textPrimary : T.textSecondary);
			add(lbl);
		}
	}

	public function containsMouse(mx:Float, my:Float):Bool
	{
		var visible = Std.int(Math.min(_data.length, MAX_VISIBLE));
		return mx >= x && mx <= x + _w && my >= y && my <= y + visible * CoolDropDown.ROW_H;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (FlxG.mouse.justPressed)
		{
			var mx = FlxG.mouse.x; var my = FlxG.mouse.y;
			if (!containsMouse(mx, my)) return;
			var row = Std.int((my - y) / CoolDropDown.ROW_H) + _scroll;
			if (row >= 0 && row < _data.length && _onSelect != null)
				_onSelect(row);
		}
	}

	override public function destroy():Void { _onSelect = null; super.destroy(); }
}
