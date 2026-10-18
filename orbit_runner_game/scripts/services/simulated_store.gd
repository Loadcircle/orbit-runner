class_name SimulatedStore
extends StoreProvider
## Stand-in for the store: asks for confirmation and succeeds. Nothing is
## charged; the dialog says so.


func is_available() -> bool:
	return true


func price(product: StoreProduct) -> String:
	return product.price_hint


func purchase(product: StoreProduct) -> bool:
	var title := TranslationServer.translate(product.title_key)
	var body := TranslationServer.translate("STORE_SIM_CONFIRM") % [title, price(product)]
	var choice := await Modal.ask(TranslationServer.translate("STORE_SIM_TITLE"), body,
			PackedStringArray([TranslationServer.translate("WORD_CANCEL"), TranslationServer.translate("STORE_BUY")]), 1)
	return choice == 1
