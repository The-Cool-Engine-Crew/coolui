package coolui;

/**
 * CoolTheme — Visual theme data structure.
 * All colours are ARGB integers (0xFFRRGGBB).
 */
typedef CoolTheme = {
	var bgDark        : Int;
	var bgPanel       : Int;
	var bgPanelAlt    : Int;
	var bgHover       : Int;
	var borderColor   : Int;
	var accent        : Int;
	var accentAlt     : Int;
	var textPrimary   : Int;
	var textSecondary : Int;
	var rowSelected   : Int;
	var rowEven       : Int;
	var rowOdd        : Int;
	var error         : Int;
}
