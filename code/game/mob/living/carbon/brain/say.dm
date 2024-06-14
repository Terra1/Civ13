/mob/living/brain/say(var/message, var/howling = FALSE)
	if(!(container && istype(container, /obj/item/device/mmi)))
		return //No MMI, can't speak, bucko.
	// workaround for language bug that happens when you're spawned in
	if (!languages.len)
		languages = list(default_language)

	if (!message)
		return
	message = capitalize(sanitize(message))

	for (var/i in dictionary_list)
		message = replacetext(message,i[1],i[2])

	var/message_without_html = message

	if (dd_hassuffix(message, "!") && !dd_hassuffix(message, "!!"))
		message = "<span class = 'font-size: 1.1em;'>[message]</span>"
	else if (dd_hassuffix(message, "!!"))
		message = "<span class = 'font-size: 1.2em;'><b>[message]</b></span>"

	var/normal_message = message
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message, rp))
			normal_message = copytext(normal_message, length(rp)+1, length(normal_message)+1)

	var/normal_message_without_html = message_without_html
	for (var/rp in radio_prefixes)
		if (dd_hasprefix(normal_message_without_html, rp))
			normal_message_without_html = copytext(normal_message_without_html, length(rp)+1, length(normal_message_without_html)+1)

	for (var/mob/living/simple_animal/complex_animal/dog/D in view(7, src))
		D.hear_command(message_without_html, src)

	message_without_html = handle_speech_problems(message_without_html)[1]

/mob/living/brain/proc/forcesay(list/append)
	if (stat == CONSCIOUS)
		if (client)
			var/virgin = TRUE	//has the text been modified yet?
			var/temp = winget(client, "input", "text")
			if (findtextEx(temp, "Say \"", TRUE, 7) && length(temp) > 5)	//case sensitive means

				temp = replacetext(temp, ";", "")	//general radio

				if (findtext(trim_left(temp), ":", 6, 7))	//dept radio
					temp = copytext(trim_left(temp), 8)
					virgin = FALSE

				if (virgin)
					temp = copytext(trim_left(temp), 6)	//normal speech
					virgin = FALSE

				while (findtext(trim_left(temp), ":", TRUE, 2))	//dept radio again (necessary)
					temp = copytext(trim_left(temp), 3)

				if (findtext(temp, "*", TRUE, 2))	//emotes
					return
				temp = copytext(trim_left(temp), TRUE, rand(5,8))

				var/trimmed = trim_left(temp)
				if (length(trimmed))
					if (append)
						temp += pick(append)

					say(temp)
				winset(client, "input", "text=[null]")

/mob/living/brain/GetVoice()
	return real_name


/mob/living/brain/say_quote(var/message, var/datum/language/speaking = null)
	var/verb = "says"
	var/ending = copytext(message, length(message))

	if (speaking)
		verb = speaking.get_spoken_verb(ending)
	else
		if (ending == "!")
			verb=pick("exclaims","shouts","yells")
		else if (ending == "?")
			verb="asks"

	return verb