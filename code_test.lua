phase = nil

SELECT_GOLD = 0xCA60
MENU        = 0xCD9C

function contains(list, x)
	for _, v in pairs(list) do
		if v == x then return true end
	end
	return false
end

function param(num)
	frameptr = memory.readword(0x04)
	return memory.readword(frameptr + 0x0B + 2*num)
end

function vm()
	emu.pause()
	a = memory.readword(0x06)
	
	if a == MENU then
		-- Menu
		menutype = param(0)
		print(string.format("%x",menutype))
		if     menutype == 0x9A95 then phase = "Main Menu"
		elseif menutype == 0xBD5F then phase = "Move Menu"
		elseif menutype == 0xBE03 then phase = "Attack Menu"
		elseif menutype == 0xBEEA then phase = "Tactics Menu"
		elseif menutype == 0xBDF9 then phase = "Select General"
		else print("ERROR: unknown menu")
		end
		return
	elseif a == SELECT_GOLD then
		phase = "Select Gold"
	end
	
end

memory.registerexec(0xE517, vm)

for i=1,4 do
	emu.frameadvance()
end

print(phase)