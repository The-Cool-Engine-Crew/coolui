package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;

typedef DropDownData   = {name:String, label:String}
typedef DropDownHeader = {text:String, ?style:DropDownHeaderStyle}
typedef DropDownHeaderStyle = {?fontSize:Int, ?color:Int}

/**
 * CoolDropDown — Drop-in replacement for `FlxUIDropDownMenu`.
 *
 * FIX: Mouse hit-test uses `FlxG.mouse.getWorldPosition(camera)` so the
 * button is detected correctly on HUD cameras.
 */
class CoolDropDown extends FlxSpriteGroup {
	public static inline var ROW_H:Int = 18;

	public var callback:String->Void;
	public var selectedLabel(get, set):String;
	public var selectedId(get, set):String;

	var _data:Array<DropDownData>;
	var _selectedIdx:Int = 0;
	var _w:Int;
	var _header:DropDownHeader;
	var _btnBg:FlxSprite;
	var _btnLabel:FlxText;
	var _btnArrow:FlxText;
	var _list:_DropList;
	var _listTarget:FlxGroup;

	public function new(px:Float = 0, py:Float = 0, data:Array<DropDownData>, ?callback:String->Void,
	                    ?header:DropDownHeader, _unused1:Dynamic = null, _unused2:Dynamic = null, width:Int = 120) {
		super(px, py);
		_data    = data ?? [];
		_w       = width;
		_header  = header ?? {text: _data.length > 0 ? _data[0].label : "-"};
		this.callback = callback;
		_build();
	}

	public static function makeStrIdLabelArray(arr:Array<String>, useIndexAsId:Bool = false):Array<DropDownData>
		return [for (i => s in arr) {name: useIndexAsId ? Std.string(i) : s, label: s}];

	function get_selectedLabel():String
		return (_selectedIdx >= 0 && _selectedIdx < _data.length) ? _data[_selectedIdx].label : "";
	function set_selectedLabel(v:String):String {
		for (i in 0..._data.length) if (_data[i].label == v) {
			_selectedIdx = i;
			if (_btnLabel != null) _btnLabel.text = v;
			break;
		}
		return v;
	}
	function get_selectedId():String
		return (_selectedIdx >= 0 && _selectedIdx < _data.length) ? _data[_selectedIdx].name : "";
	function set_selectedId(v:String):String {
		for (i in 0..._data.length) if (_data[i].name == v) {
			_selectedIdx = i;
			if (_btnLabel != null) _btnLabel.text = _data[i].label;
			break;
		}
		return v;
	}

	public function setData(items:Array<DropDownData>):Void {
		_data = items ?? [];
		_selectedIdx = (_data.length > 0) ? 0 : -1;
		if (_btnLabel != null)
			_btnLabel.text = (_selectedIdx >= 0) ? _data[_selectedIdx].label : (_header?.text ?? "");
		_closeList();
	}

	function _build():Void {
		var T = coolui.CoolUITheme.current;
		_btnBg = new FlxSprite(0, 0);
		_btnBg.makeGraphic(_w, ROW_H, T.bgPanelAlt);
		add(_btnBg);
		var brd = FlxColor.fromInt(T.borderColor);
		brd.alphaFloat = 0.7;
		_drawBorder(_btnBg, brd);

		_btnLabel = new FlxText(4, 1, _w - 20, _header.text, 8);
		_btnLabel.color = FlxColor.fromInt(T.textPrimary);
		_btnLabel.scrollFactor.set(0, 0);
		add(_btnLabel);

		_btnArrow = new FlxText(_w - 14, 1, 12, "v", 9);
		_btnArrow.color = FlxColor.fromInt(T.accent);
		_btnArrow.scrollFactor.set(0, 0);
		add(_btnArrow);
	}

	function _drawBorder(s:FlxSprite, c:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!FlxG.mouse.justPressed) return;

		// FIX: camera-aware mouse position
		var mp   = FlxG.mouse.getWorldPosition(camera);
		var mx   = mp.x; var my = mp.y;
		mp.put();

		var inBtn = mx >= x && mx <= x + _w && my >= y && my <= y + ROW_H;
		if (inBtn) {
			if (_list == null) _openList(); else _closeList();
		} else if (_list != null && !_list.containsMouse(mx, my)) {
			_closeList();
		}
	}

	function _openList():Void {
		var T          = coolui.CoolUITheme.current;
		var maxVisible = 8;
		var listH      = Math.min(_data.length, maxVisible) * ROW_H;
		var openDown   = (y + ROW_H + listH < FlxG.height);
		var listY      = openDown ? (y + ROW_H) : (y - listH);

		_list = new _DropList(x, listY, _w, ROW_H, _data, _selectedIdx, T, function(idx:Int) {
			_selectedIdx   = idx;
			_btnLabel.text = _data[idx].label;
			_closeList();
			if (callback != null) callback(_data[idx].name);
		});
		_list.scrollFactor.set(0, 0);
		_list.cameras = cameras;
		var target:FlxGroup = (_listTarget != null) ? _listTarget : FlxG.state;
		target.add(_list);
	}

	function _closeList():Void {
		if (_list == null) return;
		var target:FlxGroup = (_listTarget != null) ? _listTarget : FlxG.state;
		target.remove(_list, true);
		_list.destroy();
		_list = null;
	}

	public function setStateTarget(g:FlxGroup):Void _listTarget = g;

	override public function destroy():Void {
		_closeList();
		callback = null;
		super.destroy();
	}
}

private class _DropList extends FlxSpriteGroup {
	static inline var MAX_VISIBLE:Int = 8;

	var _data     : Array<{name:String, label:String}>;
	var _selected : Int;
	var _onSelect : Int->Void;
	var _w        : Int;
	var _rowH     : Int = CoolDropDown.ROW_H;
	var _scroll   : Int = 0;
	var _T        : CoolTheme;
	var _rowBgs   : Array<FlxSprite> = [];

	public function new(lx:Float, ly:Float, w:Int, rowH:Int, data, selected:Int, T:CoolTheme, onSelect:Int->Void) {
		super(lx, ly);
		_data = data; _selected = selected; _w = w;
		_rowH = (rowH > 0) ? rowH : CoolDropDown.ROW_H;
		_onSelect = onSelect; _T = T;
		_build(T);
	}

	function _build(T:CoolTheme):Void {
		var visible = Std.int(Math.min(_data.length, MAX_VISIBLE));
		var h = visible * _rowH;
		var bg = new FlxSprite(0, 0);
		bg.makeGraphic(_w, h, T.bgPanel);
		add(bg);

		var brdCol = FlxColor.fromInt(T.borderColor);
		brdCol.alphaFloat = 0.9;
		var p = bg.pixels;
		for (i in 0..._w) { p.setPixel32(i, 0, brdCol); p.setPixel32(i, h-1, brdCol); }
		for (j in 0...h) { p.setPixel32(0, j, brdCol); p.setPixel32(_w-1, j, brdCol); }
		bg.pixels = p;

		_rowBgs = [];
		for (i in 0...visible) {
			var idx = i + _scroll;
			var rowBg = new FlxSprite(1, i * _rowH);
			var rowColor = (idx == _selected) ? FlxColor.fromInt(T.rowSelected)
			               : (i % 2 == 0 ? FlxColor.fromInt(T.rowEven) : FlxColor.fromInt(T.rowOdd));
			rowBg.makeGraphic(_w - 2, _rowH, rowColor);
			add(rowBg);
			_rowBgs.push(rowBg);
			var lbl = new FlxText(5, i * _rowH + 1, _w - 10, _data[idx].label, 8);
			lbl.color = FlxColor.fromInt(idx == _selected ? T.textPrimary : T.textSecondary);
			add(lbl);
		}
	}

	function _rebuildRows():Void {
		for (m in members) { remove(m, true); m.destroy(); }
		members.resize(0); _rowBgs = [];
		_build(_T);
	}

	public function containsMouse(mx:Float, my:Float):Bool {
		var visible = Std.int(Math.min(_data.length, MAX_VISIBLE));
		return mx >= x && mx <= x + _w && my >= y && my <= y + visible * _rowH;
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		// FIX: camera-aware mouse position
		var mp = FlxG.mouse.getWorldPosition(camera);
		var mx = mp.x; var my = mp.y;
		mp.put();

		if (containsMouse(mx, my) && FlxG.mouse.wheel != 0) {
			var maxScroll = Std.int(Math.max(0, _data.length - MAX_VISIBLE));
			_scroll = Std.int(Math.max(0, Math.min(maxScroll, _scroll - FlxG.mouse.wheel)));
			_rebuildRows();
		}
		if (FlxG.mouse.justPressed) {
			if (!containsMouse(mx, my)) return;
			var row = Std.int((my - y) / _rowH) + _scroll;
			if (row >= 0 && row < _data.length && _onSelect != null) _onSelect(row);
		}
	}

	override public function destroy():Void { _onSelect = null; super.destroy(); }
}
