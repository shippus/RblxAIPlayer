-- Services
local HttpService = game:GetService("HttpService")
local players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")


local provider = 1
local plrprompt = nil

local playerKeys = {}

local function setKey(plr, key)
	playerKeys[plr] = key
end

local function callOpenAI(prompt, APIkey)
	return HttpService:RequestAsync({
		Url = "https://api.openai.com/v1/responses",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. APIkey -- I'll introduce API keys later.
		},
		Body = HttpService:JSONEncode({
			model = "gpt-5.4-nano",
			input = {
				{
					role = "user",
					content = {
						{
							type = "input_text",
							text = prompt
						}
					}
				}
			}
		})
	})
end

-- Player setup
players.PlayerAdded:Connect(function(plr)
	plr:SetAttribute("provider", 1)
	plr.Chatted:Connect(function(msg)
		local success, result = pcall(function()
			if provider == 1 then
				callOpenAI(plrprompt, playerKeys[plr])
			else
				print("I'll add more providers later.")
			end
		end)
	end)
end)

-- Deletes the player's key after leaving.
players.PlayerRemoving:Connect(function(plr)
	playerKeys[plr] = nil
end)