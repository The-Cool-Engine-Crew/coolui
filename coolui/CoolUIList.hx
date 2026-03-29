package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import openfl.desktop.Clipboard;
import openfl.desktop.ClipboardFormats;

/**
 * CoolUIList — Scrollable selectable list.
 *
 * FIX: Camera-aware mouse position in hit-tests.
 * FIX: _ListRow hover uses 0.85 alpha dim → 1.0 bright (was 1.25, invalid).
 * FIX: _dirty flag avoids rebuilding rows when data hasn't changed.
 * NEW: Ctrl+C copies the selected item text to the system clipboard.
 */
class CoolUIList extends FlxSpriteGroup {
	static inline var ROW_H:Int   = 18;
	static inline var SCROLL_W:Int = 8;

	public var onSelect:Int->String->Void;
	public var onDoubleClick:Int->String->Void;
	public var selectedIndex(get, set):Int;

	var _items:Array<String>   = [];
	var _selIdx:Int            = -1;
	var _scroll:Int            = 0;
	var _focused:Bool          = false;
	var _dirty:Bool            = false; // NEW: flag to avoid redundant rebuilds

	var _w:Int; var _h:Int; var _visRows:Int;
	var _bg:FlxSprite;
	var _rows:Array<_ListRow> = [];
	var _scrollBg:FlxSprite;
	var _scrollBar:FlxSprite;
	var _lastClickTime:Float = -1;
	static inline var DCLICK_TIME:Float = 0.3;

	public function new(px:Float = 0, py:Float = 0, width:Int = 200, height:Int = 150) {
		super(px, py);
		_w = (width > 0) ? width : 200;
		_h = (height > 0) ? height : 150;
		_visRows = Std.int(_h / ROW_H);
		_build();
	}

	function get_selectedIndex():Int return _selIdx;
	function set_selectedIndex(v:Int):Int {
		_selIdx = Std.int(Math.max(-1, Math.min(_items.length - 1, v)));
		_ensureVisible(_selIdx);
		_dirty = true;
		return _selIdx;
	}

	public var selectedItem(get, never):String;
	function get_selectedItem():String
		return (_selIdx >= 0 && _selIdx < _items.length) ? _items[_selIdx] : "";

	public function setItems(items:Array<String>):Void {
		_items = items ?? [];
		_scroll = 0;
		if (_selIdx >= _items.length) _selIdx = _items.length - 1;
		_dirty = true;
		_updateScrollBar();
	}

	public function addItem(item:String):Void {
		_items.push(item);
		_dirty = true;
		_updateScrollBar();
	}

	public function removeItemAt(idx:Int):Void {
		if (idx < 0 || idx >= _items.length) return;
		_items.splice(idx, 1);
		if (_selIdx >= _items.length) _selIdx = _items.length - 1;
		_dirty = true;
		_updateScrollBar();
	}

	function _build():Void {
		var T = coolui.CoolUITheme.current;
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_w, _h, T.bgPanel);
		var brdC = FlxColor.fromInt(T.borderColor);
		brdC.alphaFloat = 0.7;
		var p = _bg.pixels;
		for (i in 0..._w) { p.setPixel32(i, 0, brdC); p.setPixel32(i, _h-1, brdC); }
		for (j in 0..._h) { p.setPixel32(0, j, brdC); p.setPixel32(_w-1, j, brdC); }
		_bg.pixels = p;
		add(_bg);

		_scrollBg = new FlxSprite(_w - SCROLL_W, 0);
		_scrollBg.makeGraphic(SCROLL_W, _h, T.bgPanelAlt);
		add(_scrollBg);

		_scrollBar = new FlxSprite(_w - SCROLL_W, 0);
		_scrollBar.makeGraphic(SCROLL_W, 20, T.accent);
		_scrollBar.alpha = 0.5;
		add(_scrollBar);

		_rebuildRows();
		_updateScrollBar();
	}

	function _rebuildRows():Void {
		for (r in _rows) { remove(r, true); r.destroy(); }
		_rows = [];
		_dirty = false;

		var T = coolui.CoolUITheme.current;
		for (i in 0..._visRows) {
			var idx = i + _scroll;
			if (idx >= _items.length) break;
			var rowW = _w - SCROLL_W - 2;
			var row  = new _ListRow(1, i * ROW_H, rowW, ROW_H, idx, _items[idx], idx == _selIdx, T);
			row.scrollFactor.set(0, 0);
			row.onClick = function(ri:Int) {
				var now = haxe.Timer.stamp();
				var dbl = _lastClickTime >= 0 && (now - _lastClickTime) < DCLICK_TIME;
				_lastClickTime = now;
				selectedIndex = ri;
				if (onSelect != null)      onSelect(ri, _items[ri]);
				if (dbl && onDoubleClick != null) onDoubleClick(ri, _items[ri]);
				_focused = true;
			};
			_rows.push(row);
			add(row);
		}
	}

	function _updateScrollBar():Void {
		if (_scrollBar == null) return;
		var total = _items.length;
		if (total <= _visRows) { _scrollBar.visible = false; return; }
		_scrollBar.visible = true;
		var ratio  = _visRows / total;
		var barH   = Std.int(Math.max(16, _h * ratio));
		var scrollRange = total - _visRows;
		var barY   = (scrollRange > 0) ? Std.int((_scroll / scrollRange) * (_h - barH)) : 0;
		_scrollBar.setGraphicSize(SCROLL_W, barH);
		_scrollBar.updateHitbox();
		_scrollBar.y = barY;
	}

	function _ensureVisible(idx:Int):Void {
		if (idx < 0) return;
		if (idx < _scroll) _scroll = idx;
		if (idx >= _scroll + _visRows) _scroll = idx - _visRows + 1;
		_scroll = Std.int(Math.max(0, _scroll));
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);

		// Flush dirty flag
		if (_dirty) { _rebuildRows(); _updateScrollBar(); }

		// FIX: camera-aware mouse position
		var mp       = FlxG.mouse.getWorldPosition(camera);
		var mx       = mp.x; var my = mp.y;
		mp.put();
		var inBounds = mx >= x && mx <= x + _w && my >= y && my <= y + _h;

		if (inBounds) {
			_focused = true;
			if (FlxG.mouse.wheel != 0) {
				_scroll = Std.int(Math.max(0, Math.min(_items.length - _visRows, _scroll - FlxG.mouse.wheel)));
				_dirty  = true;
				_updateScrollBar();
			}
		} else if (FlxG.mouse.justPressed) {
			_focused = false;
		}

		if (_focused) {
			if (FlxG.keys.justPressed.UP   && _selIdx > 0)                    selectedIndex = _selIdx - 1;
			if (FlxG.keys.justPressed.DOWN && _selIdx < _items.length - 1)    selectedIndex = _selIdx + 1;
			if (FlxG.keys.justPressed.ENTER && _selIdx >= 0 && onSelect != null)
				onSelect(_selIdx, _items[_selIdx]);
			// NEW: Ctrl+C copies selected item to clipboard
			if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.C && _selIdx >= 0)
				Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, _items[_selIdx]);
		}
	}

	override public function destroy():Void {
		onSelect = null; onDoubleClick = null;
		for (r in _rows) r.destroy();
		_rows = [];
		super.destroy();
	}
}

private class _ListRow extends FlxSpriteGroup {
	public var onClick:Int->Void;
	var _idx:Int; var _bw:Int; var _bh:Int;
	var _hover:Bool = false;
	var _bg:FlxSprite;

	public function new(rx:Float, ry:Float, w:Int, h:Int, idx:Int, text:String, selected:Bool, T:CoolTheme) {
		super(rx, ry);
		_idx = idx; _bw = w; _bh = h;
		_bg = new FlxSprite(0, 0);
		var bgC = selected ? T.rowSelected : (idx % 2 == 0 ? T.rowEven : T.rowOdd);
		_bg.makeGraphic(w, h, bgC);
		add(_bg);
		if (selected) {
			var accent = new FlxSprite(0, 0);
			accent.makeGraphic(2, h, T.accent);
			add(accent);
		}
		var lbl = new FlxText(6, 1, w - 8, text, 8);
		lbl.color = FlxColor.fromInt(selected ? T.textPrimary : T.textSecondary);
		lbl.scrollFactor.set(0, 0);
		add(lbl);
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		var mp    = FlxG.mouse.getWorldPosition(camera);
		var hover = mp.x >= x && mp.x <= x + _bw && mp.y >= y && mp.y <= y + _bh;
		mp.put();
		if (hover != _hover) {
			_hover    = hover;
			// FIX: alpha > 1.0 is clamped to 1.0 — use 0.80 dim / 1.0 bright.
			_bg.alpha = hover ? 1.0 : 0.80;
		}
		if (hover && FlxG.mouse.justPressed && onClick != null) onClick(_idx);
	}
	override public function destroy():Void { onClick = null; super.destroy(); }
}
