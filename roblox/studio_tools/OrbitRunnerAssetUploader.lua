--[[
	Orbit Runner – subidor de mallas (plugin LOCAL de Studio).

	Por qué existe: AssetService:CreateAssetAsync solo funciona en plugins cargados
	localmente; el MCP de Studio no puede llamarla. Este plugin convierte los datos de malla
	exportados por roblox/assets_source/scripts/export_for_roblox.py (sincronizados por Rojo
	en ServerScriptService.MeshData) en EditableMesh y los sube como assets Mesh a la cuenta
	del usuario conectado en Studio.

	Cómo se usa:
	  · Automático: crear un StringValue "UploadRequest" dentro de ServerScriptService.MeshData
	    (Value = nombres de asset separados por comas, o vacío = todos). El plugin lo detecta,
	    sube las piezas y escribe el resultado JSON en el StringValue ServerStorage.UploadResult
	    ({ [asset] = { [pieza] = assetId } }). Es reanudable: no repite piezas con ID.
	  · Manual: botón "Subir mallas" en la barra de herramientas del plugin.

	Instalación: copiar este archivo a %LOCALAPPDATA%\Roblox\Plugins\ y reiniciar Studio.
	Fuente versionada en roblox/studio_tools/. No contiene credenciales.
]]

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local DESCRIPTION = "Orbit Runner (Roblox) – malla exportada desde Blender"
local busy = false

local function buildEditableMesh(part)
	local mesh = AssetService:CreateEditableMesh()
	local vertices, colors, normals = {}, {}, {}
	for i, p in part.positions do
		vertices[i] = mesh:AddVertex(Vector3.new(p[1], p[2], p[3]))
	end
	for i, c in part.colors do
		colors[i] = mesh:AddColor(Color3.new(c[1], c[2], c[3]), 1)
	end
	for i, n in part.normals do
		normals[i] = mesh:AddNormal(Vector3.new(n[1], n[2], n[3]))
	end
	for _, f in part.faces do
		local face = mesh:AddTriangle(vertices[f[1] + 1], vertices[f[2] + 1], vertices[f[3] + 1])
		mesh:SetFaceColors(face, { colors[f[4] + 1], colors[f[5] + 1], colors[f[6] + 1] })
		mesh:SetFaceNormals(face, { normals[f[7] + 1], normals[f[8] + 1], normals[f[9] + 1] })
	end
	return mesh
end

-- El resultado va a ServerStorage: MeshData lo gestiona Rojo y borraría el StringValue.
local function readResult()
	local holder = ServerStorage:FindFirstChild("UploadResult")
	if holder and holder.Value ~= "" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, holder.Value)
		if ok then
			return decoded
		end
	end
	return {}
end

local function writeResult(result, status)
	local holder = ServerStorage:FindFirstChild("UploadResult")
	if not holder then
		holder = Instance.new("StringValue")
		holder.Name = "UploadResult"
		holder.Parent = ServerStorage
	end
	holder.Value = HttpService:JSONEncode(result)
	holder:SetAttribute("Status", status)
end

local function upload(names)
	if busy then
		return
	end
	local folder = ServerScriptService:FindFirstChild("MeshData")
	if not folder then
		warn("[OrbitRunnerAssetUploader] falta ServerScriptService.MeshData")
		return
	end
	busy = true
	local result = readResult()
	local wanted = {}
	for name in string.gmatch(names or "", "[^,%s]+") do
		wanted[name] = true
	end
	local errors = 0
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") and module.Name:sub(1, 1) ~= "_" and (next(wanted) == nil or wanted[module.Name]) then
			local ok, data = pcall(require, module)
			if not ok then
				warn("[OrbitRunnerAssetUploader] no se pudo leer " .. module.Name .. ": " .. tostring(data))
				errors += 1
				continue
			end
			result[module.Name] = result[module.Name] or {}
			for partName, part in data.parts do
				if result[module.Name][partName] then
					continue -- ya subida
				end
				writeResult(result, "uploading " .. module.Name .. "/" .. partName)
				local built, mesh = pcall(buildEditableMesh, part)
				if not built then
					warn("[OrbitRunnerAssetUploader] " .. module.Name .. "/" .. partName .. ": " .. tostring(mesh))
					errors += 1
					continue
				end
				local called, status, id = pcall(function()
					return AssetService:CreateAssetAsync(mesh, Enum.AssetType.Mesh, {
						Name = "OrbitRunner_" .. module.Name .. "_" .. partName,
						Description = DESCRIPTION,
					})
				end)
				mesh:Destroy()
				if called and status == Enum.CreateAssetResult.Success then
					result[module.Name][partName] = id
					print(string.format("[OrbitRunnerAssetUploader] %s/%s -> %s", module.Name, partName, tostring(id)))
				else
					warn(string.format("[OrbitRunnerAssetUploader] %s/%s falló: %s %s", module.Name, partName,
						tostring(status), tostring(id)))
					errors += 1
				end
				task.wait(0.5) -- sin ráfagas contra el servicio de subida
			end
		end
	end
	writeResult(result, if errors == 0 then "done" else ("done with " .. errors .. " errors"))
	busy = false
end

local toolbar = plugin:CreateToolbar("Orbit Runner")
local button = toolbar:CreateButton("Subir mallas", "Sube las mallas de ServerScriptService.MeshData", "")
button.Click:Connect(function()
	task.spawn(upload, "")
end)

-- Petición automática (la crea el agente desde el MCP).
local function watch(folder)
	local function check(child)
		if child.Name == "UploadRequest" and child:IsA("StringValue") then
			local names = child.Value
			child:Destroy()
			task.spawn(upload, names)
		end
	end
	folder.ChildAdded:Connect(check)
	for _, child in folder:GetChildren() do
		check(child)
	end
end

local existing = ServerScriptService:FindFirstChild("MeshData")
if existing then
	watch(existing)
end
ServerScriptService.ChildAdded:Connect(function(child)
	if child.Name == "MeshData" then
		watch(child)
	end
end)
