## The service bag `Boot.services()` returns (ADR-0001 Key Interfaces): four
## handles and no behaviour. A scene root reads it once and passes each service
## down by constructor argument; nothing deeper in the tree re-fetches it, and
## rules code never names this class (gate G3).
##
## [codeblock]
## var services: Services = Boot.services()
## var controller := RunController.new(run, draft, services.meta, services.card_database, ui_config)
## [/codeblock]
class_name Services
extends RefCounted

## The one owner of game data (ADR-0002); `Ready` when `BootResult.ok`.
var card_database: CardDatabase
## The profile owner (ADR-0004). `null` when a `meta` override or a failed load
## left no `MetaFacade`.
var profile_store: ProfileStore
## The Meta Progression seam: `MetaFacade`, or a `meta` override (ADR-0011 Decision 4).
## `null` when the data load failed and no `meta` override was given.
var meta: MetaApi
## The settings channel; always the same object as `meta.settings_bus`.
var settings_bus: SettingsBus
