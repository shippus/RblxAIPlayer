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

local function callOpenAI(key, messages)
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
		warn("[AIPlayer] OpenAI request failed: " .. tostring(result))
		return nil
	end
	if result.StatusCode ~= 200 then
		warn("[AIPlayer] OpenAI error " .. result.StatusCode .. ": " .. result.Body)
		return nil
	end

	local data = HttpService:JSONDecode(result.Body)
	return data.choices[1].message.content
end

local function callGoogleAI(key, messages)
	local systemInstruction = nil
	local contents = {}

	for _, msg in ipairs(messages) do
		if msg.role == "system" then
			systemInstruction = { parts = { { text = msg.content } } }
		else
			contents[#contents + 1] = {
				role = msg.role == "assistant" and "model" or "user",
				parts = { { text = msg.content } },
			}
		end
	end

	local body = {
		contents = contents,
		generationConfig = { maxOutputTokens = 100 },
	}
	if systemInstruction then
		body.systemInstruction = systemInstruction
	end

	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=" .. key,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(body),
		})
	end)

	if not ok then
		warn("[AIPlayer] Google AI request failed: " .. tostring(result))
		return nil
	end
	if result.StatusCode ~= 200 then
		warn("[AIPlayer] Google AI error " .. result.StatusCode .. ": " .. result.Body)
		return nil
	end

	local data = HttpService:JSONDecode(result.Body)
	return data.candidates[1].content.parts[1].text
end

local function callOpenRouter(key, messages)
	local ok, result = pcall(function()
		return HttpService:RequestAsync({
			Url = "https://openrouter.ai/api/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. key,
			},
			Body = HttpService:JSONEncode({
				model = "qwen/qwen3.5-9b", -- You can hook up your own stuff to change into different models taking advantage of the /v1/chat/completions endpoint.
				messages = messages,
				max_tokens = 100,
			}),
		})
	end)

	if not ok then
		warn("[AIPlayer] OpenRouter request failed: " .. tostring(result))
		return nil
	end
	if result.StatusCode ~= 200 then
		warn("[AIPlayer] OpenRouter error " .. result.StatusCode .. ": " .. result.Body)
		return nil
	end

	local data = HttpService:JSONDecode(result.Body)
	return data.choices[1].message.content
end

local PROVIDER_FUNCTIONS = {
	[1] = callOpenAI,
	[2] = callGoogleAI,
	[3] = callOpenRouter,
}

local function callProvider(player, key, messages)
	local providerId = player:GetAttribute("Provider") or 1
	local fn = PROVIDER_FUNCTIONS[providerId]
	if not fn then
		warn("[AIPlayer] Unknown provider " .. tostring(providerId) .. " for " .. player.Name)
		return nil
	end
	return fn(key, messages)
end

local function sendMessage(player, message)
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

		local reply = callProvider(player, key, history)
		if not reply then return end

		history[#history + 1] = {
			role = "assistant",
			content = reply,
		}

		-- Here we output the AI reply, i'll implement this later.
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("Provider", 1) -- Providers: 1 is OpenAI, 2 is Google AI Studio and 3 is OpenRouter, 4 is for a custom OpenAI compatible provider.
	player.Chatted:Connect(function(message)
		sendMessage(player, message)
	end)
end)
