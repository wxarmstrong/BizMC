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