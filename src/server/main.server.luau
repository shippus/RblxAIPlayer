-- This script handles doing https requests to various APIs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")

local key -- This is given a value through a remote event from the client, so that it isn't hardcoded in the script. It doesn't save between sessions.

local setKeyEvent = rs.setKey

local conversationHistory = {
	{
		role = "system",
		content = "You are a friendly AI player in a Roblox game. Keep replies short.",
	},
}

local function callProvider(messages)
	if not key then return nil end

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
		if not key then return end

		conversationHistory[#conversationHistory + 1] = {
			role = "user",
			content = string.format("[%s]: %s", player.Name, message),
		}

		-- Keep history bounded; always preserve the system prompt at index 1.
		while #conversationHistory > 21 do
			table.remove(conversationHistory, 2)
		end

		local reply = callProvider(conversationHistory)
		if not reply then return end

		conversationHistory[#conversationHistory + 1] = {
			role = "assistant",
			content = reply,
		}

		aiResponseEvent:FireAllClients(reply)
	end)
end)
