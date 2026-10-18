class_name SimulatedAuth
extends AuthProvider
## Stand-in for Google/Facebook sign-in: a confirmation dialog, no network.


func sign_in(which: StringName) -> bool:
	var name := TranslationServer.translate("PROVIDER_" + String(which).to_upper())
	var choice := await Modal.ask(TranslationServer.translate("AUTH_SIM_TITLE") % name,
			TranslationServer.translate("AUTH_SIM_BODY") % name,
			PackedStringArray([TranslationServer.translate("WORD_CANCEL"), TranslationServer.translate("AUTH_CONTINUE")]), 1)
	if choice != 1:
		return false
	account["provider"] = String(which)
	account["linked_at"] = GameClock.now()
	SaveService.request_save()
	return true
