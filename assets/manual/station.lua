function F.station(station_name)
	if event.train then
		atc_send("B0WOL")
		atc_set_text_inside(station_name)
		interrupt(10, "depart")
	end
	if event.int and event.message == "depart" then
		atc_set_text_inside("")
		atc_send("OCD1SM")
	end
end
