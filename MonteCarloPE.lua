BEST_SCORE = 0

DEBUG = false

function count(dic)
	i = 0
	for k,v in pairs(dic) do
		i = i + 1
	end
	return i
end

function debugMsg(msg)
	if DEBUG then print(msg) end
end

function waitFrames(n)
	for i=1,n,1 do
		emu.frameadvance()
	end
end

function waitFramesBreak(n, game)
	for i=1,n,1 do
		emu.frameadvance()
		if game.endFlag return true end
	end
	return false
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
--		print("Iteration #" .. i)
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
--			debugMsg("Selected action: " .. curNode.name)
			curNode.visits = curNode.visits + 1
		end
		
		
		
		if not game.endFlag then
			memorysavestate.loadcorestate(curNode.parent.state)
			game.perform(curNode.action)
			curNode.state = memorysavestate.savecorestate()
			if game.rawscore() < BEST_SCORE then
--				print("skipping (too deep)")
				game.endFlag = true
			end
		end
		
		if (game.endFlag) then
			markTerminal(curNode)
		else
			game.rollout()
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