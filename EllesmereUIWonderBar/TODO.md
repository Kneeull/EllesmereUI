--PR up for wonderbar - it's not done yet, currently getting a *todo list of it to add into the commit so you can review and make any changes if you feel like it -> It's nowhere near as complex options wise as the M+ timer but the general logic is a pain. 

There are a couple of bugs I know of, one being the shop button that throws an error but it's unavoidable from all the implementations I've tried - including supprressing the error itself but it's a blizz error despite the shop opening? 

Sorry it's not done, was intending to finish it today but honestly the day got away from me.




# EllesmereUIWonderBar — Outstanding Issues

## InthisPR

- ✅ **Slot assignment dedup** — `PreviewPendingSlotAssignments` and `CommitPendingSlotAssignments` now share a `_ApplySlotAssignments(self, commit)` helper. `SLOT_FIXED_POS` lifted to a single module-level constant.
- ✅ **DeferUntilOOC frame leak** — was creating one persistent `Frame` per unique key. Now a single shared frame with a `pending[key] = fn` map; cleared on `PLAYER_REGEN_ENABLED` and the event is unregistered until the next call.
- ✅ **Dead popup state flags** — removed `_specPopupOpen`, `_lootPopupOpen`, `_loadoutPopupOpen` from SpecSwitch (set but never read anywhere; popup visibility was already checked via `pool._popup:IsShown()`).
- ✅ **Accent colour fetched repeatedly per `OnRefresh`** — hoisted to a single `local ar, ag, ab = WB:GetAccent()` at the top of Clock, Gold, and DataBar `OnRefresh`. Other modules call it at most once per refresh.
- ✅ **Removed unused media** — `media/microbar/chat.tga`, `media/microbar/profession.tga`, `media/profession/major.tga`, `media/profession/minor.tga`, `media/spec/PALADIN_ALT.blp`, `media/spec/WARLOCK_ALT.blp` (6 files, no code references).
- ✅ **Removed unused locale keys** — `OPT_ORDER_SLOT`, `REFRESH_STATS` from `locales/enUS.lua`.

## Remaining (not in this PR — bigger refactors)

### High Priority

- **Duplicate horizontal/vertical layout code across all visual modules** (Clock, System, Gold, Travel, SpecSwitch, Profession). Each `OnRefresh` contains a large `if isSide then ... else ...` block with near-identical sizing, text-fitting, and anchor logic (~40-50 lines each, ~300+ total). Worth extracting a shared layout helper, e.g. `ApplyModuleLayout(frame, opts)` taking icon+text+sub-text and a layout mode. Risk-prone — needs test passes for every module after.

- **Settings page in EUI not currently loading/being clickable** Not sure where this has introduced. I suspect the new format of the EUI.lua isn't as simple as adding it in two places now.

### Medium Priority

- **Module slots created upfront for all modules.** `ConstructBar` makes a named slot frame for every registered module, even ones that are permanently disabled. Could be lazy: create slot in module `OnCreate` instead. Touches enable-flow timing — confirm Options panel doesn't reach for slots before module `OnCreate` runs.

### Low / non-issues

- Travel macro seeding theoretical race — combat lockdown could (in theory) flip between `InCombatLockdown()` check and `SetAttribute` in `PreClick`. Window is sub-frame; not worth defending against.
- `GetWatchedFactionInfoCompat` returns multiple values from a possibly-partial table — caller already guards `if not name then return`. No action needed.


### Notes for shop LUA error
- I can't figure out how to fix this. Essentially when you click on the shop button, it loads but it giga errors for no reason? I can't figure out how to supress this either so if you can, I believe in you
21x [ADDON_ACTION_FORBIDDEN] AddOn 'EllesmereUIWonderBar' tried to call the protected function 'UNKNOWN()'.
[!BugGrabber/BugGrabber.lua]:540: in function '?'
[!BugGrabber/BugGrabber.lua]:524: in function <!BugGrabber/BugGrabber.lua:524>
[C]: ?
[C]: in function 'EventStoreUISetShown'
[Blizzard_CatalogShop/Blizzard_CatalogShop_Inbound.lua]:15: in function 'SetShown'
[Blizzard_UIParent/Mainline/UIParent.lua]:957: in function 'ToggleStoreUI'
[EllesmereUIWonderBar/EllesmereUIWonderBar.lua]:3717: in function 'HandleGenericButtonClick'
[EllesmereUIWonderBar/EllesmereUIWonderBar.lua]:3904: in function <EllesmereUIWonderBar/EllesmereUIWonderBar.lua:3903>
