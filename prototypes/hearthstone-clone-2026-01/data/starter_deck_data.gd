# res://data/starter_deck_data.gd
class_name StarterDeckData
extends Resource

## Deck identifier
@export var id: String = ""

## Display name
@export var deck_name: String = ""

## Description of the deck's playstyle
@export_multiline var description: String = ""

## The class this deck belongs to
@export var class_id: String = ""


## Theme color for the deck
@export var theme_color: Color = Color.WHITE

## List of card IDs in this deck (15 cards)
@export var card_ids: Array[String] = []

## Key card highlight (the signature card of this deck)
@export var signature_card_id: String = ""
