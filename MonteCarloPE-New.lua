--2AB4 = 
--2B74 = ?
--2B9C = 0x2 flag for Issen ready to go

BEST_SCORE = 0

DEBUG = false

CUR_GAME = nil 

function read_ppu(addr)
	memory.usememorydomain("PPU Bus")
	txt = memory.readbyte(addr)
	memory.usememorydomain("System Bus")	
	return txt
end

function perm_loop()
	while true do
		emu.frameadvance()
	end
end

function push_buttons(buttons)
	controller = {}
	for _,b in ipairs(buttons) do
		controller[b] = true
	end
	joypad.set(controller)
	emu.frameadvance()
end

function tab_concat(t1,t2)
	for _,v in ipairs(t2) do 
		table.insert(t1, v)
	end
end

function get_linked_list(addr)
--	print("get_linked_list")
	list = {}
	while (addr ~= 0x0000) do
--		print(string.format("%x", addr))
		table.insert(list, addr)
		addr = memory.read_u16_le(addr)
	end
	return list
end

function get_seq_list(addr)
	list = {}
	cur = memory.read_u16_le(addr)
	while (cur ~= 0x0000) do
		table.insert(list, cur)
		addr = addr + 2
		cur = memory.read_u16_le(addr)
	end
	return list
end

function contains(list, x)
	for _, v in pairs(list) do
		if v == x then return true end
	end
	return false
end

function general_value(gen)
	return memory.readbyte(gen+4) + memory.readbyte(gen+5) + memory.readbyte(gen+6)
end

function debugMsg(msg)
	if (DEBUG) then debugMsg(msg) end
end

function waitFrames(n)
	for i=1,n,1 do
		emu.frameadvance()
	end
end

function waitFramesBreak(n, game)
	--debugMsg(bp)
	for i=1,n,1 do
		emu.frameadvance()
		if game.ended() then game.endFlag = true break end
	end
	return false
end

function waitFrameBreak(game)
	return waitFramesBreak(1, game)
end

function count(dic)
	i = 0
	for k,v in pairs(dic) do
		i = i + 1
	end
	return i
end

function node(n)
	return { name = n, action = nil, state = nil, parent = nil, children = nil, cn = 0, value = 0, visits = 0, terminal = false, terminalKids = 0} 
end

function markTerminal(node)
	debugMsg("markTerminal")
	debugMsg("Marking as terminal: " .. node.name)
	node.terminal = true
	if node.parent == nil then 
		debugMsg("Root node detected: ending here")
		return
	end
	node.parent.terminalKids = node.parent.terminalKids + 1
	debugMsg("Parent has " .. node.parent.terminalKids .. " terminal kids out of " .. count(node.parent.children) .. " children total")
	if node.parent.terminalKids == count(node.parent.children) then
		markTerminal(node.parent)
	end
end

function selection(node)
	debugMsg("selection")
	topChild = nil
	topScore = -999
	
	c = math.sqrt(2)
	k = node.value / 2
	--k = 0
	
	for i, kid in pairs(node.children) do
		if (kid.terminal) then
			debugMsg("skipping terminal kid: " .. kid.name)
		else
			if (kid.visits > 0) then
				score = kid.value + c * math.sqrt( ( 2 * math.log(node.visits) ) / (kid.visits) )
			--	score = (kid.value / (kid.visits) ) + c * math.sqrt( ( 2 * math.log(node.visits) ) / (kid.visits) )
			else
				score = k + c * math.sqrt( ( 2 * math.log(node.visits) ) / (node.cn + 1) )
			end
			if score > topScore then
				topChild = kid
				topScore = score
			end
		end
	end
	
	if topChild == nil then
		debugMsg("selection ERROR: node has no children")
	end
	
	if topChild.visits == 0 then node.cn = node.cn + 1 end
	
	debugMsg("Selected action: " .. topChild.name)
	return topChild
end

function MonteCarloTreeSearch(game, n, root)

	root.name = "root"

	for i=1,n,1 do
		print("Iteration #" .. i)
		curNode = root
		if curNode.terminal then break end
		curNode.visits = curNode.visits + 1
		-- memorysavestate.loadcorestate(curNode.state)
		
		while (curNode.state ~= nil) do
			-- memorysavestate.loadcorestate(curNode.state)
			if (curNode.children == nil) then
				memorysavestate.loadcorestate(curNode.state)
				game.expand(curNode)
				-- skip analysis and designate this node as terminal if no children
				if curNode.children == nil then
--					debugMsg("No children. skipping...")
					game.endFlag = true
					break
				end
			end
			curNode = selection(curNode)
--			print("Selected action: " .. curNode.name)
			curNode.visits = curNode.visits + 1
		end
		
		
		
		if not game.endFlag then
			memorysavestate.loadcorestate(curNode.parent.state)
			game.perform(curNode.action)
			curNode.state = memorysavestate.savecorestate()
--			if game.rawscore() < BEST_SCORE then
--				print("skipping (too deep)")
--				game.endFlag = true
--			end
		end
		
		if (game.endFlag) then
			markTerminal(curNode)
		else
			-- rollout
		end
		
		
			result = game.score()
			debugMsg(result)
			if (result > BEST_SCORE) then
				BEST_SCORE = result
				print("New best score: " .. BEST_SCORE)
				--client.pause()
			end
	--		debugMsg("Score: " .. result)
			game.endFlag = false
			
			while (curNode ~= nil) do
				if (result > curNode.value) then
					curNode.value = result
				end
	--			curNode.value = curNode.value + result;
				curNode = curNode.parent
			end

		
	end
	
	topKid = nil
	topScore = -999
	
	if root.children == nil then return nil end
	
	for i, kid in pairs(root.children) do
		if (kid.value > topScore) then
--		if (kid.value / kid.visits > topScore) then
			topKid = kid
			topScore = kid.value
--			topScore = kid.value / kid.visits
		end 
	end
	
	return topKid
end

function simulate(game, N, n)
	root = node(nil)
	root.state = memorysavestate.savecorestate()
	for i=1,N,1 do
		print("Starting move " .. i)
		root = MonteCarloTreeSearch(game, n/math.pow(1.01,i), root)
		if root == nil then return end
		memorysavestate.loadcorestate(root.state)
		print("Selected move: " .. root.name .. " (score = " .. root.value .. ")" )
		if root.parent == nil then break end;
		root.parent = nil
	end
end

ROMANCE2_RECRUIT = { 
	name = "RTK2 RECRUIT",

	endFlag = false,
	
	get_provinces = function()
--		print("get_provinces")
		ptr_ACTIVE_NATION = 0x782A
		ACTIVE_NATION = memory.read_u16_le(ptr_ACTIVE_NATION)
		first_prov = memory.read_u16_le(ACTIVE_NATION + 0x02)
		return get_linked_list(first_prov)
	end,
	
	get_enemy_provinces = function()
		enemy_provs = {}
		my_provs = ROMANCE2_RECRUIT:get_provinces()
		for i=0,0x28,1 do
			cur_prov = 0x73F4 + 0x19 * i
			if memory.read_u16_le(cur_prov + 0x02) ~= 0x0000 then
				if not contains(my_provs, cur_prov) then
--					print(i+1)
					table.insert(enemy_provs, cur_prov)
				end
			end
		end
		return enemy_provs
	end,
	
	get_generals = function()
		provs = ROMANCE2_RECRUIT:get_provinces()
		gens = {}
		for provCount = 1, #provs do
			curProv = provs[provCount]
			first_gen = memory.read_u16_le(curProv + 0x02)
			cur_gens = get_linked_list(first_gen)
			tab_concat(gens, cur_gens)
		end
		return gens		
	end,
	
	ended = function()
			ACTIVE_PROVINCE = memory.read_u16_le(0x782F)
			prov_gens = get_linked_list(ACTIVE_PROVINCE + 0x02)
			for i,gen in ipairs(prov_gens) do
				status = memory.readbyte(gen + 0x02)
				acted = ( bit.band(status, 0x01) == 1 )
				if not acted then
					return false
				end
			end
			return true
	end,
	
	getActs = function()
--		print("getActs")
		acts = {}

		if (read_ppu(0x2707) == 0x59) then
			print("Detected: at province screen")
			table.insert(acts, { id = "Select Recruit", name = "Select Recruit"} )	
		elseif (read_ppu(0x22CD) == 0x50) then
			print("Detected: selecting province")
			enemies = ROMANCE2_RECRUIT:get_enemy_provinces()
			memory.usememorydomain("PRG ROM")
			for _,v in ipairs(enemies) do
				prov_num = (v-0x73F4)/0x19 + 1
				x_pos = memory.readbyte(0x31945 + 8*(prov_num-1))
				y_pos = memory.readbyte(0x31947 + 8*(prov_num-1))
				table.insert(acts, { id = "Select Province @ " .. x_pos .. ", " .. y_pos, name = "Select Province", x = x_pos, y = y_pos} )
			end
			memory.usememorydomain("System Bus")
		elseif read_ppu(0x22E4) == 0x45 and read_ppu(0x22F0) ~= 0x4D then
			print("Detected: selecting enemy general")
			enemy_generals = get_seq_list(0x7A0F)
			for i,g in ipairs(enemy_generals) do
				table.insert(acts, { id = "Select General #" .. i, name = "Select General", x = i, gtype="you"})
			end
		elseif read_ppu(0x22CD) == 0x4D then
			print("Detected: selecting recruit type")
			ACTIVE_PROVINCE = memory.read_u16_le(0x782F)
			NUM_HORSES = memory.readbyte(ACTIVE_PROVINCE + 0x17)
			NUM_GOLD = memory.read_u16_le(ACTIVE_PROVINCE + 0x08)
			
			ACTIVE_NATION = memory.read_u16_le(0x782A)
			RULER = memory.read_u16_le(ACTIVE_NATION)
			STATUS = memory.readbyte(RULER + 0x02)
			acted = ( bit.band(STATUS, 0x01) == 1 )
		
			-- Select only if leader is available to do so?
			if not acted then
				table.insert(acts, { id = "Special Attention", name = "Special Attention"})
			end
			
			-- Select only if horses available?
			if (NUM_HORSES > 0) then 
				table.insert(acts, { id = "Horse", name = "Horse"})
			end
			
			-- Select only if at least 100 gold
			if (NUM_GOLD >= 100) then
				table.insert(acts, { id = "Gold", name = "Gold"})
			end
			
			table.insert(acts, { id = "Letter", name = "Letter"})
		elseif read_ppu(0x22F0) == 0x4D then
			print("Detected: selecting acting general")
			prov_gens = get_seq_list(0x7A0F)
			for i,gen in ipairs(prov_gens) do
				status = memory.readbyte(gen + 0x02)
				acted = ( bit.band(status, 0x01) == 1 )
				if not acted then
					print("Not acted: " .. string.format("%x", gen))
					table.insert(acts, { id = "Select General #" .. i, name = "Select General", x = i, gtype = "me"})
				else
					print("Acted: " .. string.format("%x", gen))
				end
			end
		end
		
		return acts
	end,
	
	expand = function(p)
--		print("expand")
		acts = ROMANCE2_RECRUIT:getActs()
		kids = {}
		for k,v in ipairs(acts) do
			kids[v.id] = node(v.id)
			kids[v.id].action = v
			kids[v.id].parent = p
		end
		if #acts == 0 then kids = nil end
		p.children = kids
	end,
	
	perform = function(act,act2)
		if (act.name == "RTK2 RECRUIT") then
			act = act2
		end
		print("perform(" .. act.name .. ")")
		
		if (act.name == "Select Recruit") then
--			print("Select Recruit")
			-- Scroll to "Person"
			relpos = memory.readbyte(0x7D2E)
			memory.usememorydomain("Battery RAM")
			scroll = memory.readbyte(0x3915)
			memory.usememorydomain("System Bus")
			menpos = relpos + scroll
			while menpos ~= 0x02 do
				if (menpos < 0x02) then 
					push_buttons({"P1 Right"})
				end
				if (menpos > 0x02) then
					push_buttons({"P1 Left"})
				end
				relpos = memory.readbyte(0x7D2E)
				memory.usememorydomain("Battery RAM")
				scroll = memory.readbyte(0x3915)
				memory.usememorydomain("System Bus")
				menpos = relpos + scroll
			end
			
			waitFrames(13)
			
			-- Select "Person"
			push_buttons({"P1 A"})
			
			-- Select "Recruit"
			waitFrames(42)
			push_buttons({"P1 A"})
			
			-- Wait until province selection
			
			waitFrames(300)
			if memory.readbyte(0x0567) ~= 0x00 then
				endFlag = true
			end
			
		elseif (act.name == "Select Province") then
--			print("Select Province")
			while (memory.readbyte(0x056A) < act.x) do
				push_buttons({"P1 Right"})
			end
			while (memory.readbyte(0x056A) > act.x) do
				push_buttons({"P1 Left"})
			end
			while (memory.readbyte(0x0568) < act.y) do
				push_buttons({"P1 Down"})
			end
			while (memory.readbyte(0x0568) > act.y) do
				push_buttons({"P1 Up"})
			end
			
			push_buttons({"P1 A"})
			
			while memory.readbyte(0x050E) ~= 0x98 do
				emu.frameadvance()
			end
			
		elseif (act.name == "Select General") then
--			print("Select General")
			
			waitFrames(10)
			
			
			num = act.x - 1
			print("Num: " .. num)
			page_num = 0
			if num > 7 then
				page_num = math.floor(num/8)
				for i=0,page_num-1 do
					push_buttons({"P1 Right"})
					waitFrames(20)
					push_buttons({"P1 A"})
					waitFrames(60)
				end
			end
			
			entry = num % 8
			for i=0,entry-1 do
					push_buttons({"P1 Down"})
					waitFrames(20)				
			end
			
			print("Page " .. page_num .. ", entry " .. entry)
			
			push_buttons({"P1 A"})
			waitFrames(240)
			push_buttons({"P1 Left"})
			waitFrames(60)
			
--			print(act.gtype)
			if (act.gtype == "me") then
--				print("me")
				while read_ppu(0x22F0) ~= 0x4D and read_ppu(0x20B8) ~= 0x56 do
					emu.frameadvance()
				end			
--				print("finished ppu wait")
				waitFrames(240)	
--				print("finished 2nd wait")
			end
			
		elseif (act.name == "Special Attention") then
			push_buttons({"P1 A"})
			push_buttons({"P1 A"})
			waitFrames(240)	
			push_buttons({"P1 Left"})	  
			while read_ppu(0x22F0) ~= 0x4D and read_ppu(0x20B8) ~= 0x56 do
				emu.frameadvance()
			end	
			waitFrames(240)	
		elseif (act.name == "Horse") then
			push_buttons({"P1 Down"})
			push_buttons({"P1 Down"})
			waitFrames(6)
			push_buttons({"P1 A"})
			push_buttons({"P1 A"})
			waitFrames(360)	
		elseif (act.name == "Gold") then
			push_buttons({"P1 Right"})
			push_buttons({"P1 Right"})
			waitFrames(6)
			push_buttons({"P1 A"})
			push_buttons({"P1 A"})
			waitFrames(360)	
		elseif (act.name == "Letter") then
			push_buttons({"P1 Right"})
			push_buttons({"P1 Right"})
			waitFrames(12)
			push_buttons({"P1 Down"})
			push_buttons({"P1 Down"})
			waitFrames(12)
			push_buttons({"P1 A"})
			push_buttons({"P1 A"})
			waitFrames(360)	
		else
			debugMsg("Perform ERROR: \"" .. act.name .. "\" not known")
		end
	end,
	
	rollout = function()
--		print("rollout")
		--Rollout logic:
		---Arbitrary action until end
		endFlag = false
		while (not endFlag) do
			acts = ROMANCE2_RECRUIT:getActs()
			-- random item
			if #acts == 0 then
				endFlag = true
				return
			end
			a = acts[math.random(#acts)]
--			print("Performing random act: " .. a.id)
--			print(a.name)
			ROMANCE2_RECRUIT:perform(a)
		end
	end,
	
	rawscore = function()
		gens = ROMANCE2_RECRUIT:get_generals()

		total = 0
		for _,gen in ipairs(gens) do
			genval = general_value(gen)
			total = total + genval
		end

		return total
	end,
	
	score = function()
		return ROMANCE2_RECRUIT:rawscore()
	end
}

OnimushaTactics = { 
	name = "Onimusha Tactics",

	SELECT_BATTLE_UNIT = 0x19,
	UNIT_MENU = 0x1D,
	SELECT_MOVE = 0x1A,
	SELECT_ATTACK = 0x1E,
	
	endFlag = false,
	
	ended = function()
		-- player dead
		if mainmemory.readbyte(0x2AE2) == 0 then
			debugMsg("endFlag: player dead")
--			client.pause()
			return true
		end
		-- all enemies dead
		if mainmemory.readbyte(0x38A0) == 0x4B or mainmemory.readbyte(0x38A0) == 0x2F or mainmemory.readbyte(0x38A0) == 0x01 then
			debugMsg("endFlag: stage won")
--			client.pause()
			return true
		end
		
		return false
		
--		UNIT_ADDR = 0x28DC
--		UNIT_SIZE = 0xEC		
		
--		allDead = true
--		for i=0,15,1 do
--			uaddr = UNIT_ADDR + i*UNIT_SIZE
--			uid = mainmemory.readbyte(uaddr)
--			ustat = mainmemory.readbyte(uaddr + 0x4A)	
--			if uid > 0x17 and bit.band(ustat,2) ~= 0 then allDead = false break end
--		end
--		if allDead then return true end
--		return false
	end,
	
	getActs = function()
		acts = {}

		SystemDataPtr = mainmemory.read_s16_le(0x2538)
		GameDataPtr = mainmemory.read_s16_le(SystemDataPtr + 0xC)
		CursorX = mainmemory.readbyte(GameDataPtr + 0x62E)
		CursorY = mainmemory.readbyte(GameDataPtr + 0x630)

		UnitXPosArr = GameDataPtr + 0xA8C
		UnitYPosArr = GameDataPtr + 0xA9C

		UNIT_ADDR = 0x28DC
		UNIT_SIZE = 0xEC
		
		gameMode = mainmemory.readbyte(0x38A0)

--		debugMsg(string.format("%x",gameMode))
		if (gameMode == OnimushaTactics.SELECT_BATTLE_UNIT) then
--			debugMsg("  Current mode: Select Battle Unit")
			--Generate list of player units
			--Determine which ones are alive and can act
			--For each one, insert a selection act into acts
			
			for i=0,15,1 do
				curUnit = UNIT_ADDR + i*UNIT_SIZE
				unitID = mainmemory.readbyte(curUnit)
				unitFlags = mainmemory.readbyte(curUnit+0xB8)
				unitStatus = mainmemory.readbyte(curUnit+0x4A)
							
				if (unitID > 0 and unitID <= 16)    -- if unit is player-controlled
					and bit.band(unitFlags,1) == 0  -- if unit has not finished turn
					and bit.band(unitStatus,1) == 1 -- if unit is alive
					then
--					debugMsg("Unit ID: " .. unitID)
					unitXpos = mainmemory.readbyte(UnitXPosArr + i)
					unitYpos = mainmemory.readbyte(UnitYPosArr + i)
--					debugMsg("Pos: " .. unitXpos .. ", " .. unitYpos)
					table.insert(acts, { id = "Select Unit @ " .. unitXpos .. ", " .. unitYpos, name = "Select Unit", x = unitXpos, y = unitYpos } ) 
				end
			end
			
--			table.insert(acts, { id = "End Phase", name = "End Phase" } )
		elseif (gameMode == OnimushaTactics.UNIT_MENU) then
		
			--unitNum = mainmemory.readbyte(0x379C)
			unitNum = 2
--			debugMsg(unitNum)
			curUnit = UNIT_ADDR + unitNum*UNIT_SIZE
			unitFlags = mainmemory.readbyte(curUnit+0xB8)
			
--			debugMsg("  Current mode: Unit Menu")
--			debugMsg("Unit flags: " .. unitFlags)
			if (bit.band(unitFlags,4) == 0 and bit.band(unitFlags,2) == 0) then
				table.insert(acts, { id = "Select Move", name = "Select Move" } )
			end
			if (bit.band(unitFlags,2) == 0) then
				table.insert(acts, { id = "Select Attack", name = "Select Attack" } )
			end
			
			issen = (mainmemory.readbyte(0x285A) == 0x01)
			
			-- Only end the turn if you have attacked or if Issen is available
			if issen then print("ACTIVATING ISSEN") end
			if (bit.band(unitFlags,2) ~= 0 or issen) then
				table.insert(acts, { id = "Done", name = "Done"} )
			end

		elseif (gameMode == OnimushaTactics.SELECT_MOVE) then
		
			--unitNum = mainmemory.readbyte(0x379C)
			unitNum = 2
			curUnit = UNIT_ADDR + unitNum*UNIT_SIZE
			unitFlags = mainmemory.readbyte(curUnit+0xB8)
			unitX = mainmemory.readbyte(UnitXPosArr + unitNum)
			unitY = mainmemory.readbyte(UnitYPosArr + unitNum)
--			debugMsg(unitX .. "," .. unitY)
--			debugMsg("  Current mode: Select Move")
			-- scan all tiles to see which are highlighted
			-- insert act for each move
			
			for yPos=0,15,1 do
				baseRow = 0x249C + 4*yPos
				for xPos=0,15,1 do
--					debugMsg("Checking " .. xPos .. ", " .. yPos)
					exactRow = baseRow + math.floor(xPos/8)
--					debugMsg("exactRow: " .. string.format("%x", exactRow))
					baseVal = mainmemory.readbyte(exactRow)
--					debugMsg("baseVal: " .. string.format("%x", baseVal))
					digit = math.pow(2,xPos%8)
--					debugMsg("Digit: " .. digit)
					if (xPos == unitX and yPos == unitY) then
--						debugMsg("lol")
					elseif bit.band(baseVal,digit) ~= 0 then
--						debugMsg("Possible move detected: " .. xPos .. ", " .. yPos)

						-- NOTE: we should only insert this move if it's actually adjacent to an enemy. So let's add a check for that
						for i=0,15,1 do
--							debugMsg(string.format("%x",UnitXPosArr))
--							debugMsg(string.format("%x",UnitYPosArr))
							if (xPos + 1 == mainmemory.readbyte(UnitXPosArr + i) and yPos == mainmemory.readbyte(UnitYPosArr + i)) or
 							   (xPos - 1 == mainmemory.readbyte(UnitXPosArr + i) and yPos == mainmemory.readbyte(UnitYPosArr + i)) or
                               (xPos == mainmemory.readbyte(UnitXPosArr + i) and yPos + 1 == mainmemory.readbyte(UnitYPosArr + i)) or
							   (xPos == mainmemory.readbyte(UnitXPosArr + i) and yPos - 1 == mainmemory.readbyte(UnitYPosArr + i)) then
							   
								uaddr = UNIT_ADDR + i * UNIT_SIZE
								uid = mainmemory.readbyte(uaddr)
								ustat = mainmemory.readbyte(uaddr + 0x4A)
								
--								debugMsg("data")
--								debugMsg(uid)
--								debugMsg(ustat)
								
								if uid > 0x17 and bit.band(ustat,2) ~= 0 then						
--									debugMsg("Possible move detected: " .. xPos .. ", " .. yPos)
									table.insert(acts, { id = "Move to " .. xPos .. ", " .. yPos, name = "Move", x = xPos, y  = yPos } )
								end
							end
						end						
						
						
	--					
					end
				end
			end
		elseif (gameMode == OnimushaTactics.SELECT_ATTACK) then
		
			--unitNum = mainmemory.readbyte(0x379C)
			unitNum = 2
			curUnit = UNIT_ADDR + unitNum*UNIT_SIZE
			unitFlags = mainmemory.readbyte(curUnit+0xB8)		
		
--			debugMsg("Current mode: Select Attack")
			-- scan all tiles to see which are highlighted and contain an attackable enemy unit
			-- insert act for each attack
			
			for yPos=0,15,1 do
				baseRow = 0x249C + 4*yPos
--				debugMsg("baseRow: " .. string.format("%x", baseRow))
				for xPos=0,15,1 do
--					debugMsg("Checking " .. xPos .. ", " .. yPos)
					exactRow = baseRow + math.floor(xPos/8)
--					debugMsg("exactRow: " .. string.format("%x", exactRow))
					baseVal = mainmemory.readbyte(exactRow)
--					debugMsg("baseVal: " .. string.format("%x", baseVal))
					digit = math.pow(2,xPos%8)
--					debugMsg("Digit: " .. digit)
					if bit.band(baseVal,digit) ~= 0 then
						for i=0,15,1 do
--							debugMsg(string.format("%x",UnitXPosArr))
--							debugMsg(string.format("%x",UnitYPosArr))
							if xPos == mainmemory.readbyte(UnitXPosArr + i) and yPos == mainmemory.readbyte(UnitYPosArr + i) then
								uaddr = UNIT_ADDR + i * UNIT_SIZE
								uid = mainmemory.readbyte(uaddr)
								ustat = mainmemory.readbyte(uaddr + 0x4A)
								
--								debugMsg("data")
--								debugMsg(uid)
--								debugMsg(ustat)
								
								if uid > 0x17 and bit.band(ustat,2) ~= 0 then						
--									debugMsg("Possible attack detected: " .. xPos .. ", " .. yPos)
									table.insert(acts, { id = "Attack " .. xPos .. ", " .. yPos, name = "Attack", x = xPos, y  = yPos } )
								end
							end
						end
					end
				end
			end
		end
		
		if #acts == 0 then
			mainmemory.writebyte(0x2AE2,0)
			endFlag = true
		end
		
		return acts
	end,
	
	expand = function(p)
--		debugMsg("  expand")
		acts = OnimushaTactics:getActs()

		kids = {}
		for k,v in ipairs(acts) do
			kids[v.id] = node(v.id)
			kids[v.id].action = v
			kids[v.id].parent = p
		end
		
		if #acts == 0 then kids = nil end
		
		p.children = kids
	end,
	
	perform = function(act,act2)
		if (act.name == "Onimusha Tactics") then
			act = act2
		end
		
--		debugMsg("  perform")
--		debugMsg(act)
		
		SpriteDataPtr = mainmemory.read_s16_le(0x2538)
		DataPtr2 = mainmemory.read_s16_le(SpriteDataPtr + 0xC)
		CursorX = mainmemory.readbyte(DataPtr2 + 0x62E)
		CursorY = mainmemory.readbyte(DataPtr2 + 0x630)			
		
		gameMode = mainmemory.readbyte(0x38A0)
	
		if act.name == "End Phase" then
--			debugMsg("End Phase")
			joypad.set({Start = true})
			
			while (mainmemory.readbyte(0x38A0) ~= 0x34) do
				emu.frameadvance()
			end
			
			joypad.set({Up = true})
			waitFrames(1)
			joypad.set({A = true})
			waitFrames(2)
			joypad.set({Left = true})
			waitFrames(1)
			joypad.set({A = true})
	
			
			while (mainmemory.readbyte(0x38A0) ~= 0x50 and not OnimushaTactics.endFlag) do
				--debugMsg("wait for 0x50")
				endFlag = waitFrameBreak(OnimushaTactics)
				if (endFlag) then
					debugMsg("endFlag 1")
					return
				end
			end
			while (mainmemory.readbyte(0x38A0) ~= 0x19 and not OnimushaTactics.endFlag) do
				--debugMsg("wait for 0x19")
				endFlag = waitFrameBreak(OnimushaTactics)
				if (endFlag) then
--					debugMsg("endFlag 2")
					return
				end
			end
		elseif act.name == "Select Unit" or act.name == "Move" or act.name == "Attack" then
			targetX = act.x
			targetY = act.y
--			debugMsg(targetX .. "," .. targetY)
--			debugMsg(CursorX .. "," .. CursorY)
			while (CursorX < targetX) do
				joypad.set({Left = true})
				emu.frameadvance()
				CursorX = mainmemory.readbyte(DataPtr2 + 0x62E)	
			end
			
			while (CursorX > targetX) do
				joypad.set({Right = true})
				emu.frameadvance()
				CursorX = mainmemory.readbyte(DataPtr2 + 0x62E)	
			end 

			while (CursorY > targetY) do
				joypad.set({Down = true})
				emu.frameadvance()
				CursorY = mainmemory.readbyte(DataPtr2 + 0x630)	
			end 
			
			while (CursorY < targetY) do
				joypad.set({Up = true})
				emu.frameadvance()
				CursorY = mainmemory.readbyte(DataPtr2 + 0x630)	
			end 
			
			waitFrames(10)
			joypad.set({A = true})
			while (mainmemory.readbyte(0x38A0) ~= 0x1D and not OnimushaTactics.endFlag) do
				endFlag = waitFrameBreak(OnimushaTactics)
				if (endFlag) then
					return 
				end
			end	
			waitFrames(10)
		elseif act.name == "Select Move" then
			while (mainmemory.readbyte(0x281F) ~= 0) do
				joypad.set({Down = true})
				emu.frameadvance()
			end
			joypad.set({A = true})
			while (mainmemory.readbyte(0x38A0) ~= 0x1A) do
				emu.frameadvance()
			end
		elseif act.name == "Select Attack" then
			while (mainmemory.readbyte(0x281F) ~= 1) do
				joypad.set({Down = true})
				emu.frameadvance()
			end
			joypad.set({A = true})
			while (mainmemory.readbyte(0x38A0) ~= 0x1E and not OnimushaTactics.endFlag) do
				endFlag = waitFrameBreak(OnimushaTactics)
				if (endFlag) then
					return 
				end
			end
		elseif act.name == "Done" then
			joypad.set({Up = true})
			emu.frameadvance()
			joypad.set({A = true})
			waitFrames(10)
			
			--check if any units still to act
			found = false
			for i=0,15,1 do
				curUnit = UNIT_ADDR + i*UNIT_SIZE
				unitID = mainmemory.readbyte(curUnit)
				unitFlags = mainmemory.readbyte(curUnit+0xB8)
				unitStatus = mainmemory.readbyte(curUnit+0x4A)
							
				if (unitID > 0 and unitID <= 16)    -- if unit is player-controlled
					and bit.band(unitFlags,1) == 0  -- if unit has not finished turn
					and bit.band(unitStatus,1) == 1 -- if unit is alive
					then
					found = true
					break
				end
			end			
			
			--If there are still more units
			if found then
				while (mainmemory.readbyte(0x38A0) ~= 0x19) do
					emu.frameadvance()
				end
			--If there are no more units to act, proceed to next turn
			else		
				while (mainmemory.readbyte(0x38A0) ~= 0x50 and not OnimushaTactics.endFlag) do
					--debugMsg("wait for 0x50")
					endFlag = waitFrameBreak(OnimushaTactics)
					if (endFlag) then
--						debugMsg("endFlag 1")
						return
					end
				end
				while (mainmemory.readbyte(0x38A0) ~= 0x19 and not OnimushaTactics.endFlag) do
					--debugMsg("wait for 0x19")
					endFlag = waitFrameBreak(OnimushaTactics)
					if (endFlag) then
--						debugMsg("endFlag 2")
						return
					end
				end
			end
		else
			debugMsg("Perform ERROR: \"" .. act.name .. "\" not known")
		end
	end,
	
	rollout = function()
		debugMsg("rollout")
		--Rollout logic:
		---Arbitrary action until end
		endFlag = false
		while (not endFlag) do
			acts = OnimushaTactics:getActs()
			-- random item
			if #acts == 0 then
				endFlag = true
				return
			end
			a = acts[math.random(#acts)]
			debugMsg("Performing random act: " .. a.id)
			OnimushaTactics:perform(a)
		end
	end,
	
	rawscore = function()
		return 30000 - emu.framecount()
	end,
	
	score = function()
		UNIT_ADDR = 0x28DC
		UNIT_SIZE = 0xEC
		
		if mainmemory.readbyte(0x38A0) == 0x4B then
			return 30000 - emu.framecount()
		else
			debugMsg(mainmemory.readbyte(0x38A0))
			return 0
		end
		
	end
}

ROMANCE2_BATTLE = { 
	name = "RTK2 BATTLE",

	endFlag = false,
	
	ended = function()
		return false
	end,
	
	getActs = function()
--		print("getActs")
		acts = {}
		
		return acts
	end,
	
	expand = function(p)
--		print("expand")
		acts = ROMANCE2_BATTLE:getActs()
		kids = {}
		for k,v in ipairs(acts) do
			kids[v.id] = node(v.id)
			kids[v.id].action = v
			kids[v.id].parent = p
		end
		if #acts == 0 then kids = nil end
		p.children = kids
	end,
	
	perform = function(act,act2)
		if (act.name == "RTK2 BATTLE") then
			act = act2
		end
		print("perform(" .. act.name .. ")")
		if (act.name == "test") then
			print("lol")
		else
			print("Perform ERROR: \"" .. act.name .. "\" not known")
		end
	end,
	
	rollout = function()
--		print("rollout")
		--Rollout logic:
		---Arbitrary action until end
		endFlag = false
		while (not endFlag) do
			acts = ROMANCE2_BATTLE:getActs()
			-- random item
			if #acts == 0 then
				endFlag = true
				return
			end
			a = acts[math.random(#acts)]
--			print("Performing random act: " .. a.id)
--			print(a.name)
			ROMANCE2_BATTLE:perform(a)
		end
	end,
	
	rawscore = function()
		total = 0

		return total
	end,
	
	score = function()
		return ROMANCE2_RECRUIT:rawscore()
	end
}

CUR_GAME = ROMANCE2_BATTLE

debugMsg("Starting simulation")
simulate(CUR_GAME, 20, 20)