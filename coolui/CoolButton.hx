package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * CoolButton — Drop-in replacement for `FlxUIButton` / `FlxButtonPlus`.
 *
 *   var btn = new CoolButton(x, y, "Click me", function() { trace("clicked"); });
 *   btn.resize(100, 24);
 *   btn.btnWidth  = 120;   // also works
 *   btn.btnHeight = 28;    // also works
 *   btn.label     = "New text";
 *
 * FIX: Mouse hit-test now uses `FlxG.mouse.getWorldPosition(camera)` so
 * buttons on HUD cameras (no scroll) are detected correctly.
 *
 * NEW: `label` getter / setter — change button text without rebuilding.
 * NEW: Subscribes to `CoolUITheme` so the button repaints on theme change.
 *
 * Styles: STYLE_DEFAULT · STYLE_ACCENT · STYLE_DANGER · STYLE_GHOST
 */
class CoolButton extends FlxSpriteGroup {
	public static inline var STYLE_DEFAULT:Int = 0;
	public static inline var STYLE_ACCENT:Int = 1;
	public static inline var STYLE_DANGER:Int = 2;
	public static inline var STYLE_GHOST:Int = 3;

	static inline var DEFAULT_W:Int = 80;
	static inline var DEFAULT_H:Int = 20;
	public static inline var CORNER_RADIUS:Int = 3;

	// ── Public properties ──────────────────────────────────────────────────
	public var onClick:Void->Void;
	public var enabled(get, set):Bool;

	/** Read / write button width — triggers rebuild. */
	public var btnWidth(get, set):Int;

	/** Read / write button height — triggers rebuild. */
	public var btnHeight(get, set):Int;

	/** Read / write label text without a full rebuild. */
	public var label(get, set):String;

	// ── Internals ──────────────────────────────────────────────────────────
	var _bg:FlxSprite;
	var _hoverOverlay:FlxSprite;
	var _label:FlxText;
	var _style:Int;
	var _bw:Int;
	var _bh:Int;
	var _enabled:Bool = true;
	var _tween:FlxTween;
	var _tweenOvr:FlxTween;
	var _hover:Bool = false;
	var _wasPressed:Bool = false;
	var _themeListener:Void->Void;

	public var justReleased:Bool = false;

	// ── Constructor ────────────────────────────────────────────────────────
	public function new(px:Float = 0, py:Float = 0, labelStr:String = "", ?onClick:Void->Void, width:Int = DEFAULT_W, height:Int = DEFAULT_H,
			style:Int = STYLE_DEFAULT) {
		super(px, py);
		this.onClick = onClick;
		_bw = (width > 0) ? width : DEFAULT_W;
		_bh = (height > 0) ? height : DEFAULT_H;
		_style = style;
		_build(labelStr);

		// Subscribe to theme changes — repaint automatically.
		_themeListener = function() {
			var txt = (_label != null) ? _label.text : "";
			_cancelTweens();
			for (m in members) {
				remove(m, true);
				m.destroy();
			}
			members.resize(0);
			_build(txt);
		};
		CoolUITheme.addListener(_themeListener);
	}

	// ── Getters / Setters ──────────────────────────────────────────────────
	function get_enabled():Bool
		return _enabled;

	function set_enabled(v:Bool):Bool {
		_enabled = v;
		alpha = v ? 1.0 : 0.40;
		return v;
	}

	function get_btnWidth():Int
		return _bw;

	function set_btnWidth(v:Int):Int {
		if (v > 0 && v != _bw)
			resize(v, _bh);
		return _bw;
	}

	function get_btnHeight():Int
		return _bh;

	function set_btnHeight(v:Int):Int {
		if (v > 0 && v != _bh)
			resize(_bw, v);
		return _bh;
	}

	function get_label():String
		return (_label != null) ? _label.text : "";

	function set_label(v:String):String {
		if (_label != null) {
			_label.text = v;
			_label.y = y + Std.int((_bh - _label.size) * 0.5);
		}
		return v;
	}

	// ── Public API ─────────────────────────────────────────────────────────

	/** FlxButtonPlus / FlxUIButton compat. */
	public function setLabelFormat(?font:String, size:Int = 8, color:Int = 0xFFFFFFFF, alignment:String = "center"):Void {
		if (_label == null)
			return;
		if (font != null)
			_label.font = font;
		_label.size = size;
		_label.color = FlxColor.fromInt(color);
		_label.alignment = switch (alignment.toLowerCase()) {
			case "left": LEFT;
			case "right": RIGHT;
			default: CENTER;
		};
		_label.y = y + Std.int((_bh - _label.size) * 0.5);
	}

	public function resize(w:Float, h:Float):Void {
		var lbl = (_label != null) ? _label.text : "";
		_bw = Std.int(w);
		_bh = Std.int(h);
		_cancelTweens();
		for (m in members) {
			remove(m, true);
			m.destroy();
		}
		members.resize(0);
		_build(lbl);
	}

	// ── Build ──────────────────────────────────────────────────────────────
	function _build(labelText:String):Void {
		var T = coolui.CoolUITheme.current;
		var bgC = FlxColor.fromInt(_bgColor(T));
		var brdC = FlxColor.fromInt(_borderColor(T));
		var txtC = _textColor(T);

		// FIX (scrollFactor): FlxSpriteGroup.add() calls preAdd() which copies the
		// GROUP's scrollFactor onto every new member — overriding any scrollFactor set
		// on the sprite BEFORE add().  Setting it on the GROUP first guarantees that
		// preAdd propagates (0, 0) to all members automatically, so the explicit per-
		// member calls below become redundant-but-harmless safety nets.
		// Without this, if the parent camera has any scroll (e.g. the FreeplayState
		// parallax camera), member sprites rendered with scrollFactor (1,1) appear
		// offset from their world positions while hitboxes (checked in world space) stay
		// correct — exactly the "visual wrong / hitbox right" symptom.
		scrollFactor.set(0, 0);

		// FIX (position): super(px, py) is called before _build(), so the group is
		// already at (x, y) when members are added — FlxSpriteGroup only propagates the
		// position *delta* to existing members. Members added afterwards keep whatever
		// absolute position they are given, so we must initialise them at (x, y) rather
		// than (0, 0).
		_bg = new FlxSprite(x, y);
		_bg.makeGraphic(_bw, _bh, FlxColor.TRANSPARENT);
		_bg.alpha = 0.82;
		_drawButton(_bg, bgC, brdC);
		add(_bg);
		// scrollFactor set after add() so preAdd() does not override it.
		_bg.scrollFactor.set(0, 0);

		_hoverOverlay = new FlxSprite(x, y);
		_hoverOverlay.makeGraphic(_bw, _bh, FlxColor.TRANSPARENT);
		_drawOverlayMask(_hoverOverlay, FlxColor.fromInt(T.accent));
		add(_hoverOverlay);
		// FIX (alpha): alpha must be set AFTER add() — FlxSpriteGroup.add() propagates
		// the group's current alpha (1.0) to new members, overwriting any value set
		// before.  Setting it here guarantees the overlay starts invisible regardless of
		// group state.
		_hoverOverlay.alpha = 0;
		_hoverOverlay.scrollFactor.set(0, 0);

		_label = new FlxText(x + 2, y, _bw - 4, "", 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(txtC);
		_label.y = y + Std.int((_bh - _label.size) * 0.5);
		add(_label);
		_label.scrollFactor.set(0, 0);
		_label.text = labelText;
	}

	// ── Drawing ────────────────────────────────────────────────────────────
	function _drawButton(s:FlxSprite, bgC:FlxColor, brdC:FlxColor):Void {
		var w = s.frameWidth;
		var h = s.frameHeight;
		var p = s.pixels;
		var rad = CORNER_RADIUS;
		var hiC = FlxColor.fromRGB(Std.int(Math.min(255, bgC.red + 70)), Std.int(Math.min(255, bgC.green + 70)), Std.int(Math.min(255, bgC.blue + 70)));
		hiC.alphaFloat = 0.55;
		var shC = FlxColor.fromRGB(Std.int(Math.max(0, bgC.red - 35)), Std.int(Math.max(0, bgC.green - 35)), Std.int(Math.max(0, bgC.blue - 35)));
		shC.alphaFloat = 0.55;

		for (py in 0...h) {
			var t:Float = (h > 1) ? py / (h - 1) : 0.0;
			var lift:Int = Std.int((1.0 - t) * 12);
			var drop:Int = Std.int(t * 8);
			var rowC = FlxColor.fromRGB(Std.int(Math.max(0, Math.min(255, bgC.red + lift - drop))),
				Std.int(Math.max(0, Math.min(255, bgC.green + lift - drop))), Std.int(Math.max(0, Math.min(255, bgC.blue + lift - drop))));
			for (px in 0...w) {
				if (_inCorner(px, py, w, h, rad))
					p.setPixel32(px, py, FlxColor.TRANSPARENT);
				else if (px == 0 || px == w - 1 || py == 0 || py == h - 1)
					p.setPixel32(px, py, brdC);
				else if (py == 1 || px == 1)
					p.setPixel32(px, py, hiC);
				else if (py == h - 2 || px == w - 2)
					p.setPixel32(px, py, shC);
				else
					p.setPixel32(px, py, rowC);
			}
		}
		s.pixels = p;
	}

	function _drawOverlayMask(s:FlxSprite, c:FlxColor):Void {
		var w = s.frameWidth;
		var h = s.frameHeight;
		var p = s.pixels;
		var rad = CORNER_RADIUS;
		c.alphaFloat = 1.0;
		for (py in 0...h)
			for (px in 0...w) {
				if (_inCorner(px, py, w, h, rad) || px == 0 || px == w - 1 || py == 0 || py == h - 1)
					p.setPixel32(px, py, FlxColor.TRANSPARENT);
				else
					p.setPixel32(px, py, c);
			}
		s.pixels = p;
	}

	inline function _inCorner(px:Int, py:Int, w:Int, h:Int, rad:Int):Bool {
		if (px < rad && py < rad) {
			var dx = rad - 1 - px;
			var dy = rad - 1 - py;
			return (dx * dx + dy * dy) >= rad * rad;
		}
		if (px >= w - rad && py < rad) {
			var dx = px - (w - rad);
			var dy = rad - 1 - py;
			return (dx * dx + dy * dy) >= rad * rad;
		}
		if (px < rad && py >= h - rad) {
			var dx = rad - 1 - px;
			var dy = py - (h - rad);
			return (dx * dx + dy * dy) >= rad * rad;
		}
		if (px >= w - rad && py >= h - rad) {
			var dx = px - (w - rad);
			var dy = py - (h - rad);
			return (dx * dx + dy * dy) >= rad * rad;
		}
		return false;
	}

	function _bgColor(T:CoolTheme):Int {
		return switch (_style) {
			case STYLE_ACCENT: T.accent;
			case STYLE_DANGER: T.error;
			case STYLE_GHOST: FlxColor.TRANSPARENT;
			default: T.bgHover;
		};
	}

	function _borderColor(T:CoolTheme):Int {
		return switch (_style) {
			case STYLE_ACCENT: T.accent;
			case STYLE_DANGER: T.error;
			default: T.borderColor;
		};
	}

	function _textColor(T:CoolTheme):Int {
		return switch (_style) {
			case STYLE_ACCENT: T.bgDark;
			case STYLE_DANGER: T.textPrimary;
			default: T.textPrimary;
		};
	}

	// ── Update ─────────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		justReleased = false;
		if (!_enabled)
			return;

		// FIX: use camera-aware mouse position so HUD buttons work correctly.
		var mp = FlxG.mouse.getWorldPosition(camera);
		var inBtn = mp.x >= x && mp.x <= x + _bw && mp.y >= y && mp.y <= y + _bh;
		mp.put();

		if (inBtn && _wasPressed && FlxG.mouse.justReleased)
			justReleased = true;
		_wasPressed = inBtn && FlxG.mouse.pressed;

		if (inBtn != _hover) {
			_hover = inBtn;
			_cancelTweens();
			if (_hover) {
				_tween = FlxTween.globalManager.tween(_bg, {alpha: 1.0}, 0.10, {ease: FlxEase.quartOut});
				_tweenOvr = FlxTween.globalManager.tween(_hoverOverlay, {alpha: 0.09}, 0.10, {ease: FlxEase.quartOut});
			} else {
				_tween = FlxTween.globalManager.tween(_bg, {alpha: 0.82}, 0.12, {ease: FlxEase.quartOut});
				_tweenOvr = FlxTween.globalManager.tween(_hoverOverlay, {alpha: 0.0}, 0.12, {ease: FlxEase.quartOut});
			}
		}
		if (inBtn && FlxG.mouse.justPressed) {
			_flashPress();
			if (onClick != null)
				onClick();
		}
	}

	function _flashPress():Void {
		_cancelTweens();
		_bg.alpha = 0.52;
		_hoverOverlay.alpha = 0.20;
		_tween = FlxTween.globalManager.tween(_bg, {alpha: 1.0}, 0.14, {ease: FlxEase.quartOut});
		_tweenOvr = FlxTween.globalManager.tween(_hoverOverlay, {alpha: 0.09}, 0.14, {ease: FlxEase.quartOut});
	}

	function _cancelTweens():Void {
		if (_tween != null) {
			_tween.cancel();
			_tween = null;
		}
		if (_tweenOvr != null) {
			_tweenOvr.cancel();
			_tweenOvr = null;
		}
	}

	/**
	 * Override FlxSpriteGroup.set_alpha so that _hoverOverlay is NOT touched.
	 *
	 * BUG: When callers fade a button in with FlxTween.tween(btn, {alpha:1}, …),
	 * the default FlxSpriteGroup.set_alpha propagates the value to every child,
	 * including _hoverOverlay.  That overlay is supposed to sit at alpha=0 normally
	 * (it peaks at 0.09 on hover, 0.20 on press — both managed by internal tweens).
	 * Propagating alpha=1 to it produces a full-opacity, accent-coloured rectangle
	 * that covers the whole button permanently.
	 *
	 * Fix: only propagate to _bg and _label.  The _hoverOverlay keeps its own
	 * internally managed alpha untouched.
	 */
	override function set_alpha(value:Float):Float {
		if (_bg    != null) _bg.alpha    = value;
		if (_label != null) _label.alpha = value;
		// _hoverOverlay is always kept at 0 when alpha is set externally (e.g. fade tweens).
		// Its visible alpha is controlled exclusively by the hover/press tweens in update().
		// Resetting here ensures that even if add() or a resize() already propagated the
		// group alpha to the overlay, this call will clean it up on the next set.
		if (_hoverOverlay != null) _hoverOverlay.alpha = 0;
		return alpha = value;
	}

	override public function destroy():Void {
		_cancelTweens();
		CoolUITheme.removeListener(_themeListener);
		_themeListener = null;
		onClick = null;
		super.destroy();
	}
}
