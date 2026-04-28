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
 * CoolButton — Drop-in replacement for `FlxUIButton` / `CoolButtonPlus`.
 *
 *   var btn = new CoolButton(x, y, "Click me", function() { trace("clicked"); });
 *   btn.resize(100, 24);
 *   btn.btnWidth  = 120;   // also works
 *   btn.btnHeight = 28;    // also works
 *   btn.label     = "New text";
 *
 * FIXED:
 *   - onClick / onUp now fire on mouse *release* (like CoolButton), not on
 *     press. The flash animation still triggers on press.
 *   - Hit-test uses FlxG.mouse.getWorldPosition(camera) so it works
 *     correctly even when camera zoom != 1 (e.g. bump animations).
 *     is scrolled.
 *   - scrollFactor(0,0) is set on the GROUP itself in the constructor,
 *     BEFORE _build() adds any children. Flixel 5.x preAdd() copies the
 *     group's scrollFactor to every newly added child, so children
 *     automatically inherit (0,0). Setting it only on individual children
 *     (or setting it before add()) was insufficient — preAdd() overwrites
 *     whatever value the child had at add() time.
 *   - _centerLabel() uses the group's world y so label stays centred after
 *     any move / resize / font change.
 *   - set_alpha override correctly skips _hoverOverlay (prevents the
 *     accent overlay from becoming permanently visible during fade tweens).
 *   - onClick / onUp fire on any mouse *release* after a press-inside, not
 *     only when the cursor is still inside at release time. The old
 *     `_pressed && inBtn` guard caused silent click failures whenever the
 *     mouse drifted even one pixel outside the hit area between press and
 *     release — common on small buttons (default 80×20). Standard UI
 *     convention (HTML, desktop, CoolButton) requires only that the press
 *     originated inside; the release position does not matter.
 *     justReleased remains scoped to "released while hovering" for callers
 *     that need that narrower signal.
 *
 * NEW:
 *   - onDown   — fires when the mouse button is pressed over the button.
 *   - onUp     — alias for onClick (CoolButton naming convention).
 *   - onOver   — fires when the cursor enters the button area.
 *   - onOut    — fires when the cursor leaves the button area.
 *   - justPressed  — true for one frame on mouse-down over the button.
 *   - justReleased — true for one frame on mouse-up over the button.
 *   - Subscribes to CoolUITheme; repaints automatically on theme change.
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

	// ── Callbacks (CoolButton-compatible) ──────────────────────────────────

	/** Fires when the mouse is *released* while inside the button (= CoolButton.onUp). */
	public var onClick:Void->Void;

	/** Alias for onClick — CoolButton naming convention. Shares the same handler. */
	public var onUp:Void->Void;

	/** Fires when the mouse button is pressed down over this button. */
	public var onDown:Void->Void;

	/** Fires when the cursor enters the button area. */
	public var onOver:Void->Void;

	/** Fires when the cursor leaves the button area. */
	public var onOut:Void->Void;

	// ── State flags ────────────────────────────────────────────────────────

	/** True for exactly one frame when the mouse is pressed over this button. */
	public var justPressed:Bool = false;

	/** True for exactly one frame when the mouse is released over this button. */
	public var justReleased:Bool = false;

	// ── Properties ─────────────────────────────────────────────────────────
	public var enabled(get, set):Bool;

	/** Read / write button width — triggers a full rebuild. */
	public var btnWidth(get, set):Int;

	/** Read / write button height — triggers a full rebuild. */
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

	/** True while the mouse button is held down after pressing inside this button. */
	var _pressed:Bool = false;

	var _themeListener:Void->Void;

	// ── Constructor ────────────────────────────────────────────────────────
	public function new(px:Float = 0, py:Float = 0, labelStr:String = "", ?onClick:Void->Void, width:Int = DEFAULT_W, height:Int = DEFAULT_H,
			style:Int = STYLE_DEFAULT) {
		super(px, py);

		// FIX: Set scrollFactor on the GROUP before _build() adds any children.
		//
		// Flixel 5.x FlxSpriteGroup.preAdd() calls
		//   sprite.scrollFactor.copyFrom(this.scrollFactor)
		// for every member that is add()ed.  If we wait until after add() to
		// set scrollFactor on the children (old approach), the children get
		// the group's DEFAULT (1, 1) from preAdd, and our post-add set() is
		// the only correction.  That worked for the children we set explicitly,
		// but the group itself kept (1, 1), so the hit-test — which compares
		// world x/y against mouse.screenX/Y — failed whenever the camera was
		// scrolled (screenX ≠ worldX when scroll ≠ 0).
		//
		// Setting (0, 0) here means:
		//   • The group renders at screen position (x, y) regardless of camera.
		//   • preAdd propagates (0, 0) to every child automatically.
		//   • The hit-test  mx >= x  is always correct.
		scrollFactor.set(0, 0);

		this.onClick = onClick;
		_bw = (width > 0) ? width : DEFAULT_W;
		_bh = (height > 0) ? height : DEFAULT_H;
		_style = style;
		_build(labelStr);

		// Subscribe to theme changes — repaint automatically.
		_themeListener = function() _rebuild(get_label());
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
			_centerLabel();
		}
		return v;
	}

	// ── Public API ─────────────────────────────────────────────────────────

	/** Resize the button and rebuild its graphics. */
	public function resize(w:Float, h:Float):Void {
		var lbl = get_label();
		_bw = Std.int(w);
		_bh = Std.int(h);
		_rebuild(lbl);
	}

	/** CoolButtonPlus / FlxUIButton compatibility. */
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
		_centerLabel();
	}

	// ── Internal rebuild ───────────────────────────────────────────────────
	function _rebuild(labelText:String):Void {
		_cancelTweens();
		for (m in members) {
			remove(m, true);
			m.destroy();
		}
		members.resize(0);
		_hover = false;
		_pressed = false;
		_build(labelText);
	}

	// ── Build ──────────────────────────────────────────────────────────────
	function _build(labelText:String):Void {
		var T = coolui.CoolUITheme.current;
		var bgC = FlxColor.fromInt(_bgColor(T));
		var brdC = FlxColor.fromInt(_borderColor(T));
		var txtC = _textColor(T);

		// IMPORTANT: Children MUST be created at (0, 0), NOT at (x, y).
		// FlxSpriteGroup.add() in Flixel 5.x calls preAdd() which offsets every
		// newly added child by the group's current (x, y). Initialising at (x, y)
		// causes a double-offset → children end up at (2x, 2y), so the visual
		// appears far from where the hit-test fires ("click lands on nothing").
		_bg = new FlxSprite(0, 0);
		_bg.makeGraphic(_bw, _bh, FlxColor.TRANSPARENT);
		_bg.alpha = 0.82;
		_drawButton(_bg, bgC, brdC);
		add(_bg);
		// scrollFactor is already (0,0) via preAdd (group was set in constructor).
		// The explicit set below is redundant but kept for clarity.
		_bg.scrollFactor.set(0, 0);

		_hoverOverlay = new FlxSprite(0, 0);
		_hoverOverlay.makeGraphic(_bw, _bh, FlxColor.TRANSPARENT);
		_drawOverlayMask(_hoverOverlay, FlxColor.fromInt(T.accent));
		add(_hoverOverlay);
		// IMPORTANT: alpha must be set AFTER add(). FlxSpriteGroup.add()
		// propagates the group's current alpha to new members, which would
		// overwrite any value set before adding.
		_hoverOverlay.alpha = 0;
		_hoverOverlay.scrollFactor.set(0, 0);

		_label = new FlxText(2, 0, _bw - 4, labelText, 8);
		_label.alignment = CENTER;
		_label.color = FlxColor.fromInt(txtC);
		add(_label);
		_label.scrollFactor.set(0, 0);
		_centerLabel();
	}

	/**
	 * Vertically centres _label within the button.
	 * Uses absolute world-space y (= group.y + offset) because children of
	 * FlxSpriteGroup store absolute world positions, not relative offsets.
	 */
	function _centerLabel():Void {
		if (_label == null)
			return;
		_label.y = y + Std.int((_bh - _label.size) * 0.5);
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
			var lift = Std.int((1.0 - t) * 12);
			var drop = Std.int(t * 8);
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

		// Reset single-frame flags every tick.
		justPressed = false;
		justReleased = false;

		if (!_enabled)
			return;

		// FIX: Use getWorldPosition(camera) for hit testing.
		// screenX/Y breaks whenever the camera zoom != 1 (e.g. bump animations
		// set zoom to 1.02), because the sprite renders at worldX * zoom + offset
		// on screen, not at worldX. getWorldPosition() converts the raw screen
		// position back to world coords so the comparison against x/y is correct
		// regardless of zoom or camera position.
		var _mp = FlxG.mouse.getWorldPosition(camera);
		var inBtn = _mp.x >= x && _mp.x <= x + _bw && _mp.y >= y && _mp.y <= y + _bh;
		_mp.put();

		// ── Hover enter / leave ────────────────────────────────────────────
		if (inBtn != _hover) {
			_hover = inBtn;
			_cancelTweens();
			if (_hover) {
				_tween = FlxTween.globalManager.tween(_bg, {alpha: 1.0}, 0.10, {ease: FlxEase.quartOut});
				_tweenOvr = FlxTween.globalManager.tween(_hoverOverlay, {alpha: 0.09}, 0.10, {ease: FlxEase.quartOut});
				if (onOver != null)
					onOver();
			} else {
				_tween = FlxTween.globalManager.tween(_bg, {alpha: 0.82}, 0.12, {ease: FlxEase.quartOut});
				_tweenOvr = FlxTween.globalManager.tween(_hoverOverlay, {alpha: 0.0}, 0.12, {ease: FlxEase.quartOut});
				if (onOut != null)
					onOut();
			}
		}

		// ── Press (mouse down) ─────────────────────────────────────────────
		if (inBtn && FlxG.mouse.justPressed) {
			_pressed = true;
			justPressed = true;
			_flashPress();
			if (onDown != null)
				onDown();
		}

		// ── Release (mouse up) ────────────────────────────────────────────
		// FIX: fire onClick whenever the mouse is released after having been
		// pressed inside this button — regardless of where the release happens.
		// The old check `_pressed && inBtn` required the cursor to still be
		// inside the button at the moment of release, which caused silent
		// failures when the mouse moved even one pixel out of the hit area
		// between press and release (common on small buttons like the default
		// 80×20).  Standard UI convention (HTML, desktop, CoolButton) is:
		// "press inside → drag anywhere → release → click fires".
		//
		// justReleased stays scoped to "released while hovering" so external
		// code polling that flag gets the more useful "cursor is still here"
		// signal, while onClick/onUp fire unconditionally on any release.
		if (FlxG.mouse.justReleased) {
			if (_pressed) {
				if (inBtn) justReleased = true;
				if (onClick != null)
					onClick(); // primary callback (release semantics)
				if (onUp != null)
					onUp();
			}
			_pressed = false;
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
	 * BUG (original): When callers fade a button in with
	 *   FlxTween.tween(btn, {alpha: 1}, …)
	 * the default FlxSpriteGroup.set_alpha propagates the value to every
	 * child, including _hoverOverlay.  That overlay must sit at alpha = 0
	 * normally (it peaks at 0.09 on hover, 0.20 on press — both managed by
	 * internal tweens).  Propagating alpha = 1 to it produces a full-opacity,
	 * accent-coloured rectangle that covers the whole button permanently.
	 *
	 * Fix: only propagate to _bg and _label.  The _hoverOverlay keeps its
	 * own internally managed alpha untouched.
	 */
	override function set_alpha(value:Float):Float {
		if (_bg != null)
			_bg.alpha = value;
		if (_label != null)
			_label.alpha = value;
		if (_hoverOverlay != null)
			_hoverOverlay.alpha = 0;
		return alpha = value;
	}

	override public function destroy():Void {
		_cancelTweens();
		CoolUITheme.removeListener(_themeListener);
		_themeListener = null;
		onClick = null;
		onUp = null;
		onDown = null;
		onOver = null;
		onOut = null;
		super.destroy();
	}
}
