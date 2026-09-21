--!strict

local ShopPresentation = {
	CurrencyPrefix = "COINS",
	Layout = {
		PanelMinWidth = 480,
		TitleLeft = 18,
		TitleWidth = 180,
		CurrencyWidth = 160,
		CurrencyRight = 108,
		CloseWidth = 84,
		CloseRight = 12,
		HeaderTop = 8,
		HeaderHeight = 44,
		HeaderZIndex = 13,
	},
}

function ShopPresentation.FormatCurrency(currency: number): string
	assert(currency >= 0 and currency < math.huge, "Currency must be a finite non-negative number")
	return string.format("%s: %d", ShopPresentation.CurrencyPrefix, math.floor(currency))
end

function ShopPresentation.ValidateLayout(): boolean
	local layout = ShopPresentation.Layout
	local titleRight = layout.TitleLeft + layout.TitleWidth
	local currencyLeftAtMinimumWidth = layout.PanelMinWidth - layout.CurrencyRight - layout.CurrencyWidth
	local currencyRightGap = layout.CurrencyRight - (layout.CloseRight + layout.CloseWidth)
	assert(currencyLeftAtMinimumWidth > titleRight, "Currency label overlaps the shop title")
	assert(currencyRightGap >= 8, "Currency label overlaps the close button")
	assert(layout.HeaderZIndex > 11, "Currency label must render above the shop panel")
	return true
end

return table.freeze(ShopPresentation)
