package coolui;

import coolui.CoolTheme;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

/**
 * CoolModal — A blocking dialog that overlays the entire screen.
 *
 * While the modal is visible, all input to sprites behind it is blocked
 * by an invisible full-screen overlay that consumes mouse clicks.
 *
 * Static API:
 *
 *   // Simple confirm / cancel dialog:
 *   CoolModal.show("Are you sure?", "Delete file",
 *     {label:"Yes", onClick: function() doDelete()},
 *     {label:"No",  onClick: null}
 *   );
 *
 *   // Custom content:
 *   var m = new CoolModal("Settings", 300, 200);
 *   m.addContent(mySettingsGroup);
 *   m.addButton({label:"Save", onClick: function() m.hide()});
 *   m.addButton({label:"Cancel", onClick: function() m.hide()});
 *   FlxG.state.add(m);
 *   m.show();
 *
 *   CoolModal.hideAll();  // dismiss all open modals
 */

typedef CoolModalButton = {label:String, ?onClick:Void->Void}

class CoolModal extends FlxSpriteGroup {
	static inline var ANIM_TIME:Float = 0.15;
	static inline var FOOTER_H:Int    = 36;
	static inline var HEADER_H:Int    = 28;
	static inline var BTN_W:Int       = 70;
	static inline var BTN_H:Int       = 22;
	static inline var MARGIN:Int      = 10;

	// ── Singleton-style static API ────────────────────────────────────────────
	static var _instances:Array<CoolModal> = [];

	/**
	 * Show a quick confirm/cancel dialog.
	 * Buttons are created right to left from the `buttons` array.
	 */
	public static function show(message:String, title:String = "", ...buttons:CoolModalButton):Void {
		var m = new CoolModal(title, 280, 120);
		m._addMessageLabel(message);
		for (b in buttons) m.addButton(b);
		FlxG.state.add(m);
		m.show();
	}

	/** Dismiss all open modals. */
	public static function hideAll():Void {
		for (m in _instances.copy()) m.hide();
	}

	// ── Instance ──────────────────────────────────────────────────────────────
	var _title:String;
	var _w:Int; var _h:Int;

	var _overlay:FlxSprite;    // full-screen input blocker
	var _panel:FlxSprite;
	var _titleLabel:FlxText;
	var _closeBtn:FlxSprite;
	var _closeLbl:FlxText;
	var _btnRow:Array<CoolButton> = [];
	var _content:FlxSpriteGroup;
	var _tween:FlxTween;

	/** Called when the modal is dismissed (by any means). */
	public var onClose:Void->Void;

	public function new(title:String = "", panelWidth:Int = 300, panelHeight:Int = 200) {
		super(0, 0);
		_title = title;
		_w     = panelWidth;
		_h     = panelHeight;
		scrollFactor.set(0, 0);
		_build();
		visible = false;
		_instances.push(this);
	}

	function _build():Void {
		var T   = coolui.CoolUITheme.current;
		var sw  = FlxG.width;
		var sh  = FlxG.height;
		var px  = Std.int((sw - _w) / 2);
		var py  = Std.int((sh - _h) / 2);

		// Full-screen semi-transparent blocker
		_overlay = new FlxSprite(0, 0);
		_overlay.makeGraphic(sw, sh, 0xBB000000);
		_overlay.scrollFactor.set(0, 0);
		add(_overlay);

		// Panel background
		_panel = new FlxSprite(px, py);
		_panel.makeGraphic(_w, _h, T.bgPanel);
		_panel.scrollFactor.set(0, 0);
		_drawPanelBorder(_panel, FlxColor.fromInt(T.accent));
		add(_panel);

		// Header bar
		var header = new FlxSprite(px, py);
		header.makeGraphic(_w, HEADER_H, T.bgPanelAlt);
		header.scrollFactor.set(0, 0);
		var hbrd = FlxColor.fromInt(T.borderColor);
		hbrd.alphaFloat = 0.6;
		var hp = header.pixels;
		for (i in 0..._w) hp.setPixel32(i, HEADER_H - 1, hbrd);
		header.pixels = hp;
		add(header);

		// Title
		_titleLabel = new FlxText(px + MARGIN, py + Std.int((HEADER_H - 10) / 2), _w - 36, _title, 10);
		_titleLabel.color = FlxColor.fromInt(T.textPrimary);
		_titleLabel.scrollFactor.set(0, 0);
		add(_titleLabel);

		// ✕ close button
		_closeBtn = new FlxSprite(px + _w - 22, py + Std.int((HEADER_H - 14) / 2));
		_closeBtn.makeGraphic(14, 14, T.bgHover);
		_closeBtn.scrollFactor.set(0, 0);
		add(_closeBtn);
		_closeLbl = new FlxText(px + _w - 22, py + Std.int((HEADER_H - 10) / 2) - 1, 14, "x", 9);
		_closeLbl.alignment = CENTER;
		_closeLbl.color = FlxColor.fromInt(T.textSecondary);
		_closeLbl.scrollFactor.set(0, 0);
		add(_closeLbl);

		// Content area (children go here)
		_content = new FlxSpriteGroup(px + MARGIN, py + HEADER_H + MARGIN);
		_content.scrollFactor.set(0, 0);
		add(_content);
	}

	function _drawPanelBorder(s:FlxSprite, c:FlxColor):Void {
		var w = s.frameWidth; var h = s.frameHeight; var p = s.pixels;
		c.alphaFloat = 0.7;
		for (i in 0...w) { p.setPixel32(i, 0, c); p.setPixel32(i, h-1, c); }
		for (j in 0...h) { p.setPixel32(0, j, c); p.setPixel32(w-1, j, c); }
		s.pixels = p;
	}

	/** Add a sprite / group to the modal content area. */
	public function addContent(obj:flixel.FlxBasic):Void {
		// Propagate the content area's scrollFactor (0,0) to the new member.
		// _content.scrollFactor was set before any content was added, so Flixel's
		// forEach propagation didn't reach this object yet. We do it manually here
		// so that native overlays (e.g. CoolInputText._field) can compute the
		// correct screen position even when the game camera is scrolled.
		if (Std.isOfType(obj, FlxSprite)) {
			var s:FlxSprite = cast obj;
			s.scrollFactor.set(0, 0);
		}
		_content.add(obj);
	}

	/** Add a button to the footer row. Buttons are added left to right. */
	public function addButton(def:CoolModalButton):Void {
		var T   = coolui.CoolUITheme.current;
		var sw  = FlxG.width;
		var sh  = FlxG.height;
		var px  = Std.int((sw - _w) / 2);
		var py  = Std.int((sh - _h) / 2);

		var idx = _btnRow.length;
		var bx  = px + _w - MARGIN - BTN_W - idx * (BTN_W + 6);
		var by  = py + _h - FOOTER_H + Std.int((FOOTER_H - BTN_H) / 2);

		var style = (idx == 0) ? CoolButton.STYLE_ACCENT : CoolButton.STYLE_DEFAULT;
		var btn   = new CoolButton(bx, by, def.label, null, BTN_W, BTN_H, style);
		btn.scrollFactor.set(0, 0);
		btn.onClick = function() {
			if (def.onClick != null) def.onClick();
			hide();
		};
		_btnRow.push(btn);
		add(btn);
	}

	function _addMessageLabel(msg:String):Void {
		var T  = coolui.CoolUITheme.current;
		var sw = FlxG.width; var sh = FlxG.height;
		var px = Std.int((sw - _w) / 2);
		var py = Std.int((sh - _h) / 2);
		var lbl = new FlxText(px + MARGIN, py + HEADER_H + MARGIN, _w - MARGIN * 2, msg, 9);
		lbl.color = FlxColor.fromInt(T.textSecondary);
		lbl.scrollFactor.set(0, 0);
		add(lbl);
	}

	/** Fade in and show the modal. */
	public function show():Void {
		visible = true;
		alpha   = 0;
		if (_tween != null) _tween.cancel();
		_tween = FlxTween.globalManager.tween(this, {alpha: 1.0}, ANIM_TIME, {ease: FlxEase.quartOut});
	}

	/** Fade out and remove from state. */
	public function hide():Void {
		if (_tween != null) _tween.cancel();
		_tween = FlxTween.globalManager.tween(this, {alpha: 0.0}, ANIM_TIME, {
			ease: FlxEase.quartIn,
			onComplete: function(_) {
				visible = false;
				var parent = this.group;
				if (parent != null) parent.remove(this, true);
				if (onClose != null) onClose();
			}
		});
	}

	override public function update(elapsed:Float):Void {
		super.update(elapsed);
		if (!visible) return;

		var mp  = FlxG.mouse.getWorldPosition(camera);
		var mx  = mp.x; var my = mp.y;
		mp.put();
		var sw  = FlxG.width; var sh = FlxG.height;
		var px  = Std.int((sw - _w) / 2);
		var py  = Std.int((sh - _h) / 2);

		// ✕ button
		var inClose = mx >= px + _w - 22 && mx <= px + _w - 8 && my >= py + 7 && my <= py + 21;
		_closeBtn.alpha = inClose ? 1.0 : 0.7;
		if (inClose && FlxG.mouse.justPressed) hide();

		// ESC key closes
		if (FlxG.keys.justPressed.ESCAPE) hide();

		// Consume clicks on the overlay (prevent interaction with sprites behind)
		// The overlay sprite captures the click; nothing behind this group fires.
	}

	override public function destroy():Void {
		_instances.remove(this);
		if (_tween != null) { _tween.cancel(); _tween = null; }
		onClose = null;
		super.destroy();
	}
}
