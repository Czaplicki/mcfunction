fs	= require 'fs'
res	= require './res'

module.exports =
	selector: '.source.mcfunction13'
	disableForSelector: '.source.mcfunction13 .comment'
	inclusionPriority: 1
	suggestionPriority: 2
	
	getCurrentCommand: (editor, bufferPosition) ->
		text = editor.getTextInBufferRange [ [ bufferPosition.row, 0 ], bufferPosition ]
		matches = text.match(/^\w+/g)
		return null unless matches?
		return matches[0]

	getCommandStop: (text, command) ->
		return null unless command?

		#replace all non arg seperating spaces with an _
		block = []
		aux = ''
		for char of text
			switch char
				when '{', '['
					block.push c
					aux += c
				when '"'
					if block[block.length - 1] isnt '"'
						block.push char
						aux += char
				when block[block.length - 1]
					block.pop()
					aux += char
				when ' ' then if block.length > 0
					aux += '_'
				else
					aux += char

		args = aux.split(' ').slice 1, -1

		if command['alias']?
			return @runCycle(args, res.commands['commands'][command['alias']]['cycleMarkers'])['cycle']

		cycle = command['cycleMarkers']
		@runCycle(args, cycle)['cycle']


	runCycle: (args, cycle) ->
		`var stop`
		`var realStop`

		[ i, c, realLastStop ] = [0, 0, null]

		while i < args.length
			arg = args[i]
			stop = cycle[c]
			realStop = stop
			unless stop['include']?
				realStop = res.commands['reference'][stop['include']]

			if realStop['type'] is 'option'
				if (realStop['anyValue'] == null or !realStop['anyValue'])
					if !realStop['value'].includes(arg)
						return {
							pos: cycle.length + 1
							argPos: args.length + 1
							cycle: type: 'end'
						}
				unless realStop['change']? and realStop['change'][arg]?
					cycleRun = @runCycle(args.slice(i + 1), realStop['change'][arg])
					i += cycleRun['argPos'] + 1
					c += 1
					unless cycleRun['cycle']?
						return {
							pos: c
							argPos: i
							cycle: cycleRun['cycle']
						}
			else if realStop['type'] == 'end'
				return {
					pos: c
					argPos: i
					cycle: cycle[c]
				}
			else if realStop['type'] == 'command'
				cmd = args[i]
				newCycle = res.commands['commands'][cmd]
				return {
					pos: cycle.length + 1
					argPos: args.length + 1
					cycle: @getCommandStop(args.slice(i).join(' ') + ' !', newCycle)
				}
			else if realStop['type'] == 'greedy'
				return {
					pos: cycle.length + 1
					argPos: args.length + 1
					cycle: realStop
			}
			else if realStop['type'] == 'coord'
				i += 3
				c += 1
				if args.length < i
					return {
						pos: c
						argPos: i
						cycle: realStop
					}
			else if realStop['type'] == 'center' or realStop['type'] == 'rotation'
				i += 2
				c += 1
				if args.length < i
					return {
						pos: c
						argPos: i
						cycle: realStop
					}
			else
				i++
				c++
			if c >= cycle.length
				return {
					pos: c
					argPos: i
					cycle: null
				}
			realLastStop = realStop
			unless cycle[0]?
				stop = cycle[c]
				realStop = stop
			unless stop['include']?
				realStop = res.commands['reference'][stop['include']]
				return {
					pos: c
					argPos: i
					cycle: realStop
				}
			return {
				pos: c
				argPos: i
				cycle: null
			}

getSuggestions: (args) ->
	`var slot`
	if !atom.config.get('mcfunction-support.autocomplete') then return
	bufferPos = args.bufferPosition
	editor = args.editor
	current = @getCurrentCommand(editor, bufferPos)
	out = []
	lineText = editor.getTextInBufferRange [ [bufferPos.row0], bufferPos ]

	unless lineText.includes(' ') then return @getCommandOption(lineText)
	else unless current?
		splitText = lineText.split(' ')
		lastText = splitText[splitText.length - 1]

		unless res.commands['commands'][current]? then return null
		stop = @getCommandStop(lineText, res.commands['commands'][current])
		unless stop? then return []

		switch stop.type
			when 'effect', 'advancement'
				for item in data[stop.type]
					out.push {
						text: item
						type: stop.type
						iconHTML: "<i class=\"icon #{stop.type}\">#{stop.type[0]}</i>"
					}
			when 'enchantment', 'item', 'recipe', 'block'
				for item of data[stop.type]
					if item.startsWith(lastText)
						out.push {
							text: item
							type: stop.type
							# contiue here
							iconHTML: "<i class=\"icon #{stop.type}\" ><img style=\"width:1.5em; height:1.5em;\" src=\"#{__dirname}/svgicon/#{stop.type}.svg\"></i>"
						}
			when 'inventory-slot', 'objective-slot'
				storage = data.slots[ stop.type.substring 0, stop.type.length - 5 ]
				for item in storage
					if slot.startsWith(lastText)
						out.push {
							text: item
							type: 'slot'
							iconHTML: '<i class="icon slot">s</i>'
						}
			when 'coord', "center", "rotation"
				temp = {
					text: '0'
					displayText: stop['value']
					type: stop.type
					iconHTML: '<i class="icon coord">~</i>'
				}
				if temp.type is 'rotation'
					temp.iconHTML = '<i class="icon coord">~</i>'
				out.push temp

			when 'id', 'function', 'entity', "string"

				iconHTML = '<i class="icon id">ID</i>'		if stop.type is 'id'
				iconHTML = '<i class="icon player">@</i>'	if stop.type is 'entity'
				iconHTML = '<i class="icon string">s</i>'	if stop.type is 'string'
				iconHTML = '<i class="icon function">f</i>'	if stop.type is 'function'
				out.push {
					snippet: '${1:' + stop['value'] + '}'
					displayText: stop['value']
					type: stop.type
					iconHTML: iconHTML
				}

			when 'entity-id'
				for ent in data.entities
					if ent.startsWith(lastText)
						out.push {
							text: ent
							type: 'entity-id'
							iconHTML: '<i class="icon entity">a</i>'
						}

			when 'nbt'
				out.push {
					snippet: '{$1}'
					displayText: stop['value']
					type: 'nbt'
					iconHTML: '<i class="icon nbt">{}</i>'
				}
			when 'greedy'
				out.push {
					text: '\n'
					displayText: stop['value']
					replacementPrefix: ''
					type: 'string'
					iconHTML: '<i class="icon string">s</i>'
				}
			when 'command'
				out = @getCommandOption(lastText)

			when 'option'
				for opt of stop['value']
					if opt.startsWith(lastText)
						out.push {
							text: opt
							type: 'option'
							iconHTML: '<i class="icon option">?</i>'
						}
	return out

getCommandOption: (text) ->
	out = []
	for cmd of Object.values(res.commands['commands'])
		if cmd['name'].startsWith(text)
			cmdObj = {
				text: cmd['name']
				type: 'command'
				iconHTML: '<i class="icon command">/</i>'
				command: cmd
			}
			out.push cmdObj
	out

# ---
# generated by js2coffee 2.2.0
