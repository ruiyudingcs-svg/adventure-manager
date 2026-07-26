## Localization boundary that makes missing keys visible during development.
class_name UiText
extends RefCounted


static func get_text(key: StringName, fallback: String = "") -> String:
	if key.is_empty():
		return fallback
	var translated := TranslationServer.translate(key)
	if translated == String(key):
		return fallback if not fallback.is_empty() \
			else "[MISSING:%s]" % key
	return translated
