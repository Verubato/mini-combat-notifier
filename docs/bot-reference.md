# MiniCombatNotifier reference

## What it does

Shows a short text notification on screen when you enter combat and when you leave
it. Default texts are "<Entering Combat>" in red and "<Leaving Combat>" in green,
which fade in, hold briefly, and fade out. Useful for players who disable
Blizzard's scrolling combat text and lose its combat notifications.

## Facts

| Item | Value |
| --- | --- |
| Version | 1.2.6 |
| Author | Verz |
| Interface versions (TOC) | 120100, 50504, 40402, 38002, 38000, 30405, 30300, 20506, 11509 |
| Saved variables | MiniCombatNotifierDB |
| Slash commands | /mcn, /minicn, /minicombatnotifier (all open the settings panel) |
| Options location | Game options -> AddOns -> MiniCombatNotifier |
| Bundled libraries | LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, MiniFramework |
| Integrations | Fonts registered by other addons via LibSharedMedia appear in the Font dropdown |

## Features

- Triggers on the standard combat events (PLAYER_REGEN_DISABLED = entering,
  PLAYER_REGEN_ENABLED = leaving).
- Each notification fades in over 0.5 s, holds 0.5 s, and fades out over 0.5 s. The
  durations are stored in MiniCombatNotifierDB (FadeInDuration, HoldDuration,
  FadeOutDuration) but have no options-UI control.
- The text sits in a 500x60 banner anchored to the center of the screen, offset by
  the X/Y settings (default 0, 0 = dead center).
- Test mode: shows the entering-combat text permanently with a faint white
  background so it can be dragged to a new position. Dragging is unclamped, so the
  text itself can be placed near screen edges.

## Settings

Single options panel, grouped under three dividers. The panel header carries a
**Test** button and, top right, a **Reset to Defaults** button.

### Notification Text

| Setting | Type | Default |
| --- | --- | --- |
| Entering Combat: | edit box | "<Entering Combat>" |
| Leaving Combat: | edit box | "<Leaving Combat>" |

### Font

| Setting | Type | Default | Range / options |
| --- | --- | --- | --- |
| Entering Combat: | color swatch | red (1, 0.1, 0.1, 1) | |
| Leaving Combat: | color swatch | green (0, 1, 0, 1) | |
| Font: | dropdown | Friz Quadrata | LibSharedMedia fonts; falls back to 5 built-ins (Friz Quadrata, Arial Narrow, Morpheus, Skurri, 2002); each row previews in its own font |
| Style: | dropdown | Outline | Outline, Thick Outline, Monochrome, Outline + Mono, None |
| Font Size | slider | 16 | 8-48 |

### Position

| Setting | Type | Default | Range |
| --- | --- | --- | --- |
| X: | numeric edit box | 0 | -2000 to 2000 |
| Y: | numeric edit box | 0 | -2000 to 2000 |

Panel hint: "Click Test, then drag the text to reposition it."

### Test and Reset

The header's **Test** button toggles test mode (see Features above). Its
**Reset to Defaults** button resets every setting after a Yes/No confirmation
dialog.

## Version-gated behavior

- On Midnight (12.x) clients the settings panel cannot be opened during combat; the
  slash command prints "Can't do that during combat." instead.
- No behavior differs by content type or group size.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| No text on entering/leaving combat | There is no enable/disable toggle, so if configured it should fire on every combat transition. Check the text was not cleared in the options and the color alpha is not 0. |
| Text is in the wrong place / off screen | Set X and Y back toward 0 in the Position section, or use Reset to Defaults. Test-mode dragging is intentionally unclamped, so text can be dragged off the visible area. |
| Cannot drag the text | Dragging only works while test mode is on (Enable Test Mode button in the options). |
| Faint white box on screen | That is the test-mode background; click "Disable Test Mode" in the options. |
| Notification disappears too fast | Fade and hold durations (0.5 s each) are only adjustable by editing FadeInDuration, HoldDuration and FadeOutDuration in the MiniCombatNotifierDB saved variable; there is no UI for them. |
| Custom fonts missing from the dropdown | Only fonts registered through LibSharedMedia (usually by a SharedMedia addon) are listed; otherwise the 5 built-in fonts show. |
| README says there is no configuration UI | The README is outdated; a full options panel exists since version 1.1.0 (open with /mcn). |
