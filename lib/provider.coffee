commands = require('./commands.json')
blocks = require('./id/block.json')
effects = require('./id/effect.json')
advancements = require('./id/advancement.json')
enchantments = require('./id/enchantment.json')
items = require('./id/item.json')
recipes = require('./id/recipe.json')
slots = require('./id/slot.json')
entities = require('./id/entity.json')
fs = require('fs')

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
			return @runCycle(args, commands['commands'][command['alias']]['cycleMarkers'])['cycle']

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
				realStop = commands['reference'][stop['include']]

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
				newCycle = commands['commands'][cmd]
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
				realStop = commands['reference'][stop['include']]
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
	unless lineText.includes(' ')
		out = @getCommandOption(lineText)
	else unless current?
		splitText = lineText.split(' ')
		lastText = splitText[splitText.length - 1]

	unless commands['commands'][current]? then null

	stop = @getCommandStop(lineText, commands['commands'][current])
	unless stop? then return []

	# replace with a switch win 

	if stop['type'] == 'command'
		out = @getCommandOption(lastText)
	else if stop['type'] == 'option'
		for opt of stop['value']
			if opt.startsWith(lastText)
				out.push {
					text: opt
					type: 'option'
					iconHTML: '<i class="icon option">?</i>'
				}
	else if stop['type'] == 'block'
		for block of blocks
			if block.startsWith(lastText)
				out.push {
					text: block
					type: 'block'
					iconHTML: '<img style="width:1.5em; height:1.5em;" src="' + __dirname + '/svgicon/block.svg">'
				}
	else if stop['type'] == 'effect'
		for effect of effects
			if effect.startsWith(lastText)
				out.push {
					text: effect
					type: 'effect'
					iconHTML: '<i class="icon effect">e</i>'
				}
	else if stop['type'] == 'advancement'
		for adv of advancements
			if adv.startsWith(lastText)
				out.push {
					text: adv
					type: 'advancement'
					iconHTML: '<i class="icon advancement">a</i>'
				}
	else if stop['type'] == 'enchantment'
		for ench of enchantments
			if ench.startsWith(lastText)
				out.push {
					text: ench
					type: 'enchantment'
					iconHTML: '<i class="icon enchantment" ><img style="width:1.5em; height:1.5em;" src="' + __dirname + '/svgicon/enchantment.svg"></i>'
				}
	else if stop['type'] == 'entity-id'
		for ent of entities
		if ent.startsWith(lastText)
			out.push
			text: ent
			type: 'entity-id'
			iconHTML: '<i class="icon entity">a</i>'
	else if stop['type'] == 'item'
		for item of items
		if item.startsWith(lastText)
			out.push
			text: item
			type: 'item'
			iconHTML: '<i class="icon item" ><img style="width:1.5em; height:1.5em;" src="' + __dirname + '/svgicon/item.svg"></i>'
	else if stop['type'] == 'recipe'
		for recipe of recipes
		if recipe.startsWith(lastText)
			out.push
			text: recipe
			type: 'recipe'
			iconHTML: '<i class="icon recipe" ><img style="width:1.5em; height:1.5em;" src="' + __dirname + '/svgicon/recipe.svg"></i>'
	else if stop['type'] == 'iventory-slot'
		for slot of slots['inventory']
		if slot.startsWith(lastText)
			out.push
			text: slot
			type: 'slot'
			iconHTML: '<i class="icon slot">s</i>'
	else if stop['type'] == 'objective-slot'
		for slot of slots['objective']
		if slot.startsWith(lastText)
			out.push
			text: slot
			type: 'slot'
			iconHTML: '<i class="icon slot">s</i>'
	else if stop['type'] == 'coord'
		out.push
		text: '0'
		displayText: stop['value']
		type: 'coord'
		iconHTML: '<i class="icon coord">~</i>'
	else if stop['type'] == 'center'
		out.push
		text: '0'
		displayText: stop['value']
		type: 'center'
		iconHTML: '<i class="icon coord">~</i>'
	else if stop['type'] == 'rotation'
		out.push
		text: '0'
		displayText: stop['value']
		type: 'rotation'
		iconHTML: '<i class="icon rotation">r</i>'
	else if stop['type'] == 'nbt'
		out.push
		snippet: '{$1}'
		displayText: stop['value']
		type: 'nbt'
		iconHTML: '<i class="icon nbt">{}</i>'
	else if stop['type'] == 'id'
		out.push
		snippet: '${1:' + stop['value'] + '}'
		displayText: stop['value']
		type: 'id'
		iconHTML: '<i class="icon id">ID</i>'
	else if stop['type'] == 'function'
		out.push
		snippet: '${1:' + stop['value'] + '}'
		displayText: stop['value']
		type: 'function'
		iconHTML: '<i class="icon function">f</i>'
	else if stop['type'] == 'entity'
		out.push
		snippet: '${1:' + stop['value'] + '}'
		displayText: stop['value']
		type: 'entity'
		iconHTML: '<i class="icon player">@</i>'
	else if stop['type'] == 'string'
		out.push
		snippet: '${1:' + stop['value'] + '}'
		displayText: stop['value']
		type: 'string'
		iconHTML: '<i class="icon string">s</i>'
	else if stop['type'] == 'greedy'
		out.push
		text: '\n'
		displayText: stop['value']
		replacementPrefix: ''
		type: 'string'
		iconHTML: '<i class="icon string">s</i>'
	out
getCommandOption: (text) ->
	out = []
	for cmd of Object.values(commands['commands'])
		if cmd['name'].startsWith(text)
			cmdObj =
				text: cmd['name']
				type: 'command'
				iconHTML: '<i class="icon command">/</i>'
				command: cmd
			out.push cmdObj
	out

# ---
# generated by js2coffee 2.2.0
