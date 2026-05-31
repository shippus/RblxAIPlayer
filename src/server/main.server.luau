-- This script handles doing https requests to various APIs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

local playerKeys = {}
local playerHistory = {}

local setKeyEvent = rs.setKey

local systemPrompt = "You are a helpful assistant in a Roblox game. Keep replies short and relevant to the game context."

local SYSTEM_MESSAGE = {
	role = "system",
	content = systemPrompt,
}

setKeyEvent.OnServerEvent:Connect(function(player, newKey)
	if typeof(newKey) ~= "string" then
		warn("[AIPlayer] Invalid key type from " .. player.Name)
		return
	end

	playerKeys[player] = newKey
	print("[AIPlayer] API key set by " .. player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	playerKeys[player] = nil
	playerHistory[player] = nil
end)

local function callProvider(key, messages)
	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = "https://api.openai.com/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. key,
			},
			Body = HttpService:JSONEncode({
				model = "gpt-4o-mini",
				messages = messages,
				max_tokens = 100,
			}),
		})
	end)

	if not ok then
		warn("[AIPlayer] Request failed: " .. tostring(result))
		return nil
	end

	if result.StatusCode ~= 200 then
		warn("[AIPlayer] OpenAI error " .. result.StatusCode .. ": " .. result.Body)
		return nil
	end

	local data = HttpService:JSONDecode(result.Body)
	return data.choices[1].message.content
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		local key = playerKeys[player]
		if not key then return end

		if not playerHistory[player] then
			playerHistory[player] = { SYSTEM_MESSAGE }
		end
		local history = playerHistory[player]

		history[#history + 1] = {
			role = "user",
			content = string.format("[%s]: %s", player.Name, message),
		}
		while #history > 21 do
			table.remove(history, 2)
		end

		local reply = callProvider(key, history)
		if not reply then return end

		history[#history + 1] = {
			role = "assistant",
			content = reply,
		}

		-- Here we output the AI reply, i'll implement this later.
	end)
end)
