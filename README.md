# Critline

- **Original creator:** Sordit

- Previous maintainer: Uggh
- Previous maintainer: Feyde

Critline is an addon that will remember your highest hits and crits (including heals and pet attacks), and display them in a fairly simple tooltip. It sports many features by default, including advanced filtering, a standalone frame, splash on new record and more. All this can be disabled if you just want the basic functionality. Read on for more info!

**If you would like to contribute to the localization, please head over to the [CurseForge localization page](https://legacy.curseforge.com/wow/addons/critline/localization). Any and all translations, reviews and corrections are greatly appreciated.**

### Spell list

This is where you can review and manage all of your registered spells. On its own it shows the registered records and target. Functionality is added by other modules and is accessed via the menu button on the right hand side of each spell.

Filters, reset and announce modules are dependent on the spell list module.

This module can be disabled by deleting `SpellList.lua` in your Critline folder.

### Filters

The filter module lets you control which spells you want to register and show, as well as which targets you want to allow.

It comes with integrated aura and mob filters, for those known auras/mobs that may mess up your records. Generally I include anything that boosts your effects by 10% or more. You can also add custom entries.

The module also adds spell filter functionality to the spell list. Enabled spells will be accounted for when records are broken, and will show up in tooltips. Disabled spells are grayed out in the spell list.

This module requires the spell list module.

This module can be disabled by deleting `FilterCore.lua` and `FilterGUI.lua` in your Critline folder.

### Splash

The splash module, when enabled, will display a message on your screen whenever you break a record. You can choose to use the default style, or have the messages make use of your combat text addon of choice.

This module can be disabled by deleting `Splash.lua` in your Critline folder.

### Display

The display module allows for easy access to all your records. It will show the normal and crit record of each tree, and when you hover over the frame, it will show you a tooltip with all the records.

This module can be disabled by deleting `Display.lua` in your Critline folder.

### Minimap

The minimap module provides easy access to the options. Right click it to show the config frame, and left click it to toggle the display frame.

This module can be disabled by deleting `Minimap.lua` in your Critline folder.

### Announce

This module adds announcing functionality to the spell list. This allows you to let people know of your awesome records.

This module requires the spell list module.

This module can be disabled by deleting `Announce.lua` in your Critline folder.

### Reset

This module adds reset and revert functionality to the spell list. It lets you permanently delete unwanted records, or revert records achieved in the last fight. Records that are eligible for reversion are annotated with green text in the spell list.

This module requires the spell list module.

This module can be disabled by deleting `Reset.lua` in your Critline folder.

### Broker

This module provides a DataBroker feed for each tree, that shows the records, much like the display module.
You can shift click it to insert your top records into the chat, or click it normally to open the config.

This module can be disabled by deleting `Broker.lua` in your Critline folder.

### Advanced

This module lets you manipulate how data is stored and presented, and is not for the faint of heart!
With it, you can make spells be regarded as a different spell, sharing its records. You can also have spells appear with a different name or icon, or specify which spell should be presented in a given tooltip. Spell IDs are accepted as the soure spell. Be sure to enable debugging with '/cl debug' to reveal spell IDs in tooltips and debug messages.

This module can be disabled by deleting `Advanced.lua` in your Critline folder.

### Aura tracker

This module mainly exists for debugging purposes and does not actually affect the addon in any way.
It registers auras that you and neutral and hostile NPCs have gained, and displays them in a sortable and filterable list. Spell ID and NPC ID of the caster is included.

This module can be disabled by disabling the Critline: AuraMonitor addon.

### Profiles

This module allows you to share settings among characters, and manage profiles easily.
The spell profile contains all your spell records, as well as data regarding which trees you are recording.
The "general" profile contains all other settings. This profile is character specific by default.
This way you can use the same general settings (such as functionality and appearance) on all your characters, while still using separate spell databases.
The general and spell profiles are stored separately, and will not collide. For example, you can use the 'Default' profile both for the general and the spell profiles. They are not considered the same. Changes made to the general profile would not affect the spell profile.

This module can be disabled by deleting `Profiles.lua` in your Critline folder. Note that profiles will still be used, you are only disabling the ability to manage them.
