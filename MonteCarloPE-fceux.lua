CUR_GAME = nil

PadA  = {
{A=true},
{A=false}
}

PadUp  = {
{up=true},
{up=false}
}

PadDown  = {
{down=true},
{down=false}
}

PadLeft  = {
{left=true},
{left=false}
}

PadRight  = {
{right=true},
{right=false}
}

endFlag = false

function advanceRNG(num)

	RAM = {}

	for regY=5,0,-1 do
		RAM[0x98+regY] = memory.readbyte(0x98+regY)
	end

	RAM[0x9D] = memory.readbyte(0x9D)

	for i=1,num,1 do
		RAM[0x9D] = bit.bor(RAM[0x9D],0x01)

		for regY=5,0,-1 do
			RAM[0x9F+regY] = 0
		end

		for regY=5,0,-1 do
			


			RAM[0x73] = memory.readbyte(0xFC76 + regY)
			RAM[0x6C] = 0x08
			
			while RAM[0x6C] > 0 do
			
				carry = 0;
				
				for regX = 5,0,-1 do
			
					if bit.band(RAM[0x9F+regX],0x80)>0 then
						nextCarry = 1;
					else
						nextCarry = 0;
					end
				
					RAM[0x9F+regX] = bit.band(2*RAM[0x9F+regX]+carry,0xFF)
			
					carry = nextCarry;
			
				end
			
				if bit.band(RAM[0x73],0x80)>0 then
					carry = 1
				else
					carry = 0
				end
				
				RAM[0x73] = bit.band(2*RAM[0x73],0xFF)
				
				if carry~=0 then
					
					carry=0
					
					for regX=5,0,-1 do
					
						
						RAM[0x9F+regX] = RAM[0x9F+regX] + RAM[0x98+regX] + carry
						
						if RAM[0x9F+regX] > 0xFF then
							RAM[0x9F+regX] = bit.band(RAM[0x9F+regX],0xFF)
							carry = 1
						else
							carry = 0
						end
					
					end


				
				end
				
				RAM[0x6C] = RAM[0x6C] - 1
				
			end
			
		end

		carry = 1

		for regX=5,0,-1 do

			regA = XOR(RAM[0x9F+regX],0xFF) + carry
			
			if regA>0xFF then
				regA = bit.band(regA,0xFF)
				carry = 1
			else
				carry = 0
			end
			
			RAM[0x98+regX] = regA
			

		end

		RAM[0x67] = bit.band(RAM[0x98],0x7F)
		RAM[0x66] = RAM[0x99]
	
	end

	return 256*RAM[0x67]+RAM[0x66]
	
end

function getID(gen)
	return memory.readword(gen+0x13)
end

function getFamily(gen)
	address = 0x3285B + 0x09*getID(gen)
	return rom.readbyte(0x10 + address) + 256*rom.readbyte(0x10 + address + 1)
end

function getReliable(gen)
	return rom.readbyte(0x10 + 0x32854 + 0x09*getID(gen))
end

function getAmbition(gen)
	return rom.readbyte(0x10 + 0x32856 + 0x09*getID(gen))
end

function can_be_specialed(gen)
	activeNation = memory.readword(0x782A)
	
	activeTrust = memory.readbyte(activeNation + 0x06)
	genInt = memory.readbyte(gen + 0x04)
	genCharm = memory.readbyte(gen + 0x06)
	
	genLoyal = memory.readbyte(gen + 0x08)
	
	num1 = (100 - genLoyal)
	num2 = activeTrust + genInt + genCharm
	num3 = 200
	
	percent_chance = math.max(math.floor( 0.8*math.floor( (num1*num2)/num3 ) ),0)

	print("% chance of special: " .. percent_chance)
	return advanceRNG(1)%100 < percent_chance
end

function can_be_horsed(gen)
	activeNation = memory.readword(0x782A)
	
	activeTrust = memory.readbyte(activeNation + 0x06)
	genWar = memory.readbyte(gen + 0x05)
	genCharm = memory.readbyte(gen + 0x06)
	
	genLoyal = memory.readbyte(gen + 0x08)
	
	num1 = 100-genLoyal
	num2 = activeTrust + (3*genWar - genCharm)
	num3 = 200
	
	percent_chance = math.max(math.floor( (num1*num2)/num3 ),0)
	print("% chance of horse: " .. percent_chance)
	
	return advanceRNG(1)%100 < percent_chance
end

function can_be_golded(gen)

	genRel = getReliable(gen)
	genAmb = getAmbition(gen)
	genCharm = memory.readbyte(gen + 0x06)
	genLoyal = memory.readbyte(gen + 0x08)
	
	num1 = (100 - genLoyal)
	num2 = 2*(100-genRel)+genAmb-genCharm
	num3 = 200
	
	percent_chance = math.max(math.floor( (num1*num2)/num3 ),0)
	print("% chance of gold: " .. percent_chance)
	
	return advanceRNG(1)%100 < percent_chance
end

function can_be_lettered(gen)
	genLoyal = memory.readbyte(gen + 0x08)
	activeTrust = memory.readbyte(activeNation + 0x06)
	
	num1 = 100-genLoyal
	num3 = 200
	num2 = 3*activeTrust
	
	ACTING_GENERAL = memory.readword(0x7D38)
	
	curCharm = memory.readbyte(ACTING_GENERAL + 0x06)
	
	activeNation = memory.readword(0x782A)
	activeRuler = memory.readword(activeNation)
	
	if (ACTING_GENERAL == activeRuler) then curCharm = math.floor(0.8*curCharm) end
	
	if 3*activeTrust+curCharm > num2 then num2=3*activeTrust+curCharm end
	
	percent_chance = math.max(math.floor( (num1*num2)/num3 ),0)
	print("% chance of letter: " .. percent_chance)
	
	return advanceRNG(1)%100 < percent_chance
end

function push(button)
	joypad.set(1,button[1])
	waitFrames(1)
	joypad.set(1,button[1])
	waitFrames(1)
	joypad.set(1,button[2])
	waitFrames(1)
end

function waitFrames(n)
	for i=1,n,1 do
		emu.frameadvance()
	end
end

-- Waits n frames, or until the endFlag has been set (via a registered breakpoint function)
-- Returns true if end was hit, false if not
function waitFramesBreak(game,n)
	for i=1,n,1 do
		emu.frameadvance()
		if CUR_GAME.endFlag then 
			return true
		end
	end
	return false
end

-- Waits for breakpoint execution in the Koei VM
function waitVM(vm_addr)
	while (memory.readword(0x06) ~= vm_addr) do
		emu.frameadvance()
	end
end

function tab_concat(t1,t2)
	for _,v in ipairs(t2) do 
		table.insert(t1, v)
	end
end

function get_linked_list(addr)
	list = {}
	while (addr ~= 0x0000) do
		table.insert(list, addr)
		addr = memory.readword(addr)
	end
	return list
end

function get_seq_list(addr)
	list = {}
	cur = memory.readword(addr)
	while (cur ~= 0x0000) do
		table.insert(list, cur)
		addr = addr + 2
		cur = memory.readword(addr)
	end
	return list
end

function contains(list, x)
	for _, v in pairs(list) do
		if v == x then return true end
	end
	return false
end

function count(dic)
	i = 0
	for k,v in pairs(dic) do
		i = i + 1
	end
	return i
end

function general_value(gen)
	return memory.readbyte(gen+4) + memory.readbyte(gen+5) + memory.readbyte(gen+6)
end

function node(n)
--	if (n ~= nil) then print("node(" .. n .. ")")
--	else print("node(nil)") end
	return { name = n, action = nil, state = nil, parent = nil, children = nil, cn = 0, value = 0, visits = 0, terminal = false, terminalKids = 0} 
end

function markTerminal(node)
--	print("markTerminal")
	node.terminal = true
	if node.parent == nil then return end
	node.parent.terminalKids = node.parent.terminalKids + 1
	if node.parent.terminalKids == count(node.parent.children) then
		markTerminal(node.parent)
	end
end

function selection(node)
--	print("selection")
	topChild = nil
	topScore = -999
	
	c = math.sqrt(2)
	k = node.value / 2
	
	for i, kid in pairs(node.children) do
		if (kid.terminal) then
--			debugMsg("skipping terminal kid: " .. kid.name)
		else
			if (kid.visits > 0) then
				score = kid.value + c * math.sqrt( ( 2 * math.log(node.visits) ) / (kid.visits) )
			else
				score = k + c * math.sqrt( ( 2 * math.log(node.visits) ) / (node.cn + 1) )
			end
			if score > topScore then
				topChild = kid
				topScore = score
			end
		end
	end
	
	if topChild.visits == 0 then node.cn = node.cn + 1 end
	
	return topChild
end

function mcts(game, n, root)
	root.name = "root"
	for i=1,n do
		print("Iteration #" .. i)
		curNode = root
		if (curNode.terminal) then 
--			print("Terminal node: ending now")
			break 
		end
		curNode.visits = curNode.visits + 1
		while curNode.state ~= nil do
--			print("curNode.state ~= nil")
--			print("name: " .. curNode.name)
			if curNode.children == nil then
--				print("curNode.chidren == nil")
				savestate.load(curNode.state)
				game.expand(curNode)
				if curNode.children == nil then
					endFlag = true
					break
				end
			end
			curNode = selection(curNode)
			curNode.visits = curNode.visits + 1
		end
		
		if not endFlag then
--			print("not endFlag")
			savestate.load(curNode.parent.state)
			game.perform(curNode.action)
			sstate = savestate.create()
			savestate.save(sstate)
			savestate.persist(sstate)
			curNode.state = sstate
		end 
		
		if endFlag then
			print("endFlag .. marking terminal")
			markTerminal(curNode)
		else
			game.rollout()
		end
		
		result = game.score()
		endFlag = false
		
		while curNode ~= nil do
			if result > curNode.value then
				curNode.value = result
			end
			curNode = curNode.parent
		end

	end
	
	topKid = nil
	topScore = 0
	
	--print(root.children)
	
	for _,kid in pairs(root.children) do
		if (kid.value > topScore) then
			topKid = kid
			topScore = kid.value
		end 
	end
	
--	print("Selected kid w/ val " .. topKid.value)
	return topKid
	
end

function simulate(game, N, n)
	print("simulate(" .. game.name .. ", " .. N .. ", " .. n)
	root = node(nil)
	sstate = savestate.create()
	savestate.save(sstate)
	savestate.persist(sstate)
	root.state = sstate	
	for i=1,N,1 do
		print("Starting move " .. i)
		root = mcts(game, n, root)
		if root == nil then return end
		print("Chose action: " .. root.name)
		savestate.load(root.state)
		if root.children == nil then break end
		root.parent = nil
	end
end

ROMANCE2_RECRUIT = 
{
	name = "RTK2 RECRUIT",
	
	-- endFlag = false,
	
	get_provinces = function()
--		print("get_provinces")
		ACTIVE_NATION = memory.readword(0x782A)
		first_prov = memory.readword(ACTIVE_NATION + 0x02)
		return get_linked_list(first_prov)
	end,

	get_enemy_provinces = function()
--		print("enemy_provinces")
		enemy_provs = {}
		my_provs = ROMANCE2_RECRUIT:get_provinces()
--		print(my_provs)
		for i=0,0x28,1 do
			cur_prov = 0x73F4 + 0x19 * i
--			print("cur_prov")
--			print(string.format("%x", cur_prov))
			if memory.readbyte(cur_prov + 0x0E) ~= 0xFF then
				if not contains(my_provs, cur_prov) then
--					print(i+1)
--					print(string.format("%x", cur_prov) .. " @ " .. string.format("%x", cur_prov + 0x02) .. " = " .. string.format("%x", memory.readword(cur_prov + 0x02)))
					table.insert(enemy_provs, cur_prov)
				end
			end
		end
--		print("enemy_provs")
--		print(enemy_provs)
		return enemy_provs
	end,
	
	get_generals = function()
		provs = ROMANCE2_RECRUIT:get_provinces()
		gens = {}
		for provCount = 1, #provs do
			curProv = provs[provCount]
			first_gen = memory.readword(curProv + 0x02)
			cur_gens = get_linked_list(first_gen)
			tab_concat(gens, cur_gens)
		end
		return gens		
	end,	
	
	ended = function()
		ACTIVE_PROVINCE = memory.readword(0x782F)
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
		
		if ppu.readbyte(0x2707) == 0x59 then
--			print("Detected: at province screen")
			table.insert(acts, { id = "Select Recruit", name = "Select Recruit"} )
		elseif ppu.readbyte(0x22CD) == 0x50 then
--			print("Detected: selecting province")
			enemies = ROMANCE2_RECRUIT:get_enemy_provinces()
--			print("got enemies:")
--			print(enemies)
			for _,v in ipairs(enemies) do
				prov_num = (v-0x73F4)/0x19 + 1
				x_pos = rom.readbyte(0x10 + 0x31945 + 8*(prov_num-1))
				y_pos = rom.readbyte(0x10 + 0x31947 + 8*(prov_num-1))
--				print("Inserting prov_num " .. prov_num .. " @ " .. string.format("%x", v) .. " @ " .. x_pos .. ", " .. y_pos)
				table.insert(acts, { id = "Select Province @ " .. x_pos .. ", " .. y_pos, name = "Select Province", x = x_pos, y = y_pos} )
			end
		elseif ppu.readbyte(0x22E4) == 0x45 and ppu.readbyte(0x22F0) ~= 0x4D then
--			print("Detected: selecting enemy general")
			enemy_generals = get_seq_list(0x7A0F)
			for i,g in ipairs(enemy_generals) do
				-- Disqualify family members of nation ruler from being recruited
				nation = memory.readbyte(g + 0x07)*0x22 + 0x71D4
				ruler = memory.readword(nation)
				if getFamily(g) ~= getFamily(ruler) then
					table.insert(acts, { id = "Select General #" .. i, name = "Select General", x = i, gtype="you"})
				end
			end
		elseif ppu.readbyte(0x22CD) == 0x4D then
--			print("Detected: selecting recruit type")
			ACTIVE_PROVINCE = memory.readword(0x782F)
			NUM_HORSES = memory.readbyte(ACTIVE_PROVINCE + 0x17)
			NUM_GOLD = memory.readword(ACTIVE_PROVINCE + 0x08)
			
			ACTIVE_NATION = memory.readword(0x782A)
			RULER = memory.readword(ACTIVE_NATION)
			STATUS = memory.readbyte(RULER + 0x02)
			acted = ( bit.band(STATUS, 0x01) == 1 )
		
			TARGET_GENERAL = memory.readword(0x7D42)
		
			print("Current RNG = " .. advanceRNG(1)%100)
		
			num = 0
		
			-- Select only if leader is available to do so?
			if not acted and can_be_specialed(TARGET_GENERAL) then
				table.insert(acts, { id = "Special Attention", name = "Special Attention"})
				num = num+1
			end
			
			-- Select only if horses available?
			if (NUM_HORSES > 0) and can_be_horsed(TARGET_GENERAL) then 
				table.insert(acts, { id = "Horse", name = "Horse"})
				num = num+1
			end
			
			-- Select only if at least 100 gold
			if (NUM_GOLD >= 100) and can_be_golded(TARGET_GENERAL) then
				table.insert(acts, { id = "Gold", name = "Gold"})
				num = num+1
			end
			
			if can_be_lettered(TARGET_GENERAL) then 
				table.insert(acts, { id = "Letter", name = "Letter"})
				num = num+1
			end
			
		elseif ppu.readbyte(0x22F0) == 0x4D then
--			print("Detected: selecting acting general")
			prov_gens = get_seq_list(0x7A0F)
			for i,gen in ipairs(prov_gens) do
				status = memory.readbyte(gen + 0x02)
				acted = ( bit.band(status, 0x01) == 1 )
				if not acted then
--					print("Not acted: " .. string.format("%x", gen))
					table.insert(acts, { id = "Select General #" .. i, name = "Select General", x = i, gtype = "me"})
				else
--					print("Acted: " .. string.format("%x", gen))
				end
			end
		end	
		
		return acts
	end,
	
	perform = function(act, act2)
--		print("perform")
		if act.name == "RTK2 RECRUIT" then
			act = act2
		end
		
		if (act.name == "Select Recruit") then
--			print("Select Recruit")
			-- Scroll to "Person"
			relpos = memory.readbyte(0x7D2E)
			scroll = memory.readbyte(0x7915)
			menpos = relpos + scroll
			while menpos ~= 0x02 do
				if (menpos < 0x02) then 
					push(PadRight)
				end
				if (menpos > 0x02) then
					push(PadLeft)
				end
				relpos = memory.readbyte(0x7D2E)
				scroll = memory.readbyte(0x3915)
				menpos = relpos + scroll
			end
			
			waitFrames(13)
			
			-- Select "Person"
			push(PadA)
			
			-- Select "Recruit"
			waitFrames(42)
			push(PadA)
			
			-- Wait until province selection
			
			waitFrames(300)
			if memory.readbyte(0x0567) ~= 0x00 then
				print("end hit")
				endFlag = true
			else
				print("end not hit")
			end
		elseif (act.name == "Select Province") then
			print("Select Province @ " .. act.x .. ", " .. act.y)
			waitFrames(10)
			while (memory.readbyte(0x056A) < act.x) do
--				print("x = " .. memory.readbyte(0x56A))
				push(PadRight)
				waitFrames(1)
			end
			while (memory.readbyte(0x056A) > act.x) do
--				print("x = " .. memory.readbyte(0x56A))
				push(PadLeft)
				waitFrames(1)
			end
			while (memory.readbyte(0x0568) < act.y) do
--				print("y = " .. memory.readbyte(0x568))
				push(PadDown)
				waitFrames(1)
			end
			while (memory.readbyte(0x0568) > act.y) do
--				print("y = " .. memory.readbyte(0x568))
				push(PadUp)
				waitFrames(1)
			end
			
			push(PadA)
			
			while memory.readbyte(0x050E) ~= 0x98 do
				emu.frameadvance()
			end
		elseif (act.name == "Select General") then
--			print("Select General")
			
			waitFrames(10)
			
			
			num = act.x - 1
--			print("Num: " .. num)
			page_num = 0
			if num > 7 then
				page_num = math.floor(num/8)
				for i=0,page_num-1 do
					push(PadRight)
					waitFrames(20)
					push(PadA)
					waitFrames(60)
				end
			end
			
			entry = num % 8
			for i=0,entry-1 do
					push(PadDown)
					waitFrames(20)				
			end
			
			print("Page " .. page_num .. ", entry " .. entry)
			
			push(PadA)
			waitFrames(240)
			push(PadLeft)
			waitFrames(60)
			
--			print(act.gtype)
			if (act.gtype == "me") then
--				print("me")
				while ppu.readbyte(0x22F0) ~= 0x4D and ppu.readbyte(0x20B8) ~= 0x56 do
					emu.frameadvance()
				end			
--				print("finished ppu wait")
				waitFrames(240)	
--				print("finished 2nd wait")
			end
		elseif (act.name == "Special Attention") then
			push(PadA)
			waitFrames(240)	
			push(PadLeft)  
			while ppu.readbyte(0x22F0) ~= 0x4D and ppu.readbyte(0x20B8) ~= 0x56 do
				emu.frameadvance()
			end	
			waitFrames(240)	
		elseif (act.name == "Horse") then
			push(PadDown)
			waitFrames(6)
			push(PadA)
			waitFrames(360)	
		elseif (act.name == "Gold") then
			push(PadRight) 
			waitFrames(6)
			push(PadA)
			waitFrames(360)	
		elseif (act.name == "Letter") then
			push(PadRight) 
			waitFrames(12)
			push(PadDown)
			waitFrames(12)
			push(PadA)
			waitFrames(360)	
		else
			print("UNKNOWN ACT")
			while true do emu.frameadvance() end
		end
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
	
	rollout = function()
--		print("rollout")
		endFlag = false
		while (not endFlag) do
			acts = ROMANCE2_RECRUIT:getActs()
			if #acts == 0 then
				endFlag = true
				return
			end
			a = acts[math.random(#acts)]
			ROMANCE2_RECRUIT:perform(a)			
		end
	end,
	
	score = function()
--		print("score")
		gens = ROMANCE2_RECRUIT:get_generals()
		total = 0
		for _,gen in ipairs(gens) do
			genval = general_value(gen)
			total = total + genval
		end
--		print(total)
		return total
	end
}

ROMANCE2_BATTLE = 
{
	name = "RTK2 BATTLE",
	
	-- endFlag = false,
	
	ended = function()
		return false
	end,
	
	getActs = function()
		acts = {}
		
		return acts
	end,
	
	perform = function(act, act2)
--		print("perform")
		if act.name == "RTK2 BATTLE" then
			act = act2
		end
		
		if (act.name == "test") then
			print("test")
		else
			print("UNKNOWN ACT")
			while true do emu.frameadvance() end
		end
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
	
	rollout = function()
--		print("rollout")
--      replace this with CPU takeover
		endFlag = false
		while (not endFlag) do
			acts = ROMANCE2_BATTLE:getActs()
			if #acts == 0 then
				endFlag = true
				return
			end
			a = acts[math.random(#acts)]
			ROMANCE2_BATTLE:perform(a)			
		end
	end,
	
	score = function()
--		print("score")
		total = 0
		return total
	end
}

CUR_GAME = ROMANCE2_BATTLE

function bp()
	CUR_GAME.endFlag = true
end

-- "To be continued next month"
memory.registerexec(0xA587, bp)

simulate(ROMANCE2_RECRUIT, 100, 100)