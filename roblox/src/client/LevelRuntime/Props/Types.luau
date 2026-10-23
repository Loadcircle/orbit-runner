--!strict
-- Tipos compartidos por los props del nivel.

export type Session = {
	onCheckpoint: (any, spawnFeet: Vector3, facing: Vector3) -> (),
	onGem: (any, index: number) -> (),
	onSpark: (any) -> (),
	finish: (any) -> (),
	setCameraYaw: (any, yaw: number) -> (),
	showPrompt: (any, owner: any, key: string) -> (),
	hidePrompt: (any, owner: any) -> (),
	gemAlreadyOwned: (any, index: number) -> boolean,
	playSfx: (any, name: string) -> (),
	vibrate: (any, milliseconds: number) -> (),
}

export type Context = {
	player: any, -- PlayerController
	session: Session,
	triggers: any, -- Triggers
	folder: Instance, -- Workspace.ActiveLevel
	geometry: Instance,
	triggerFolder: Instance,
	decor: Instance,
	biome: any, -- Palette.Biome
}

export type Entry = {
	pos: { number },
	rot: { number }?,
	scale: { number }?,
	params: { [string]: any }?,
	collider: { size: { number }, offset: { number } }?,
	asset: string?,
	[string]: any,
}

export type Prop = {
	step: ((self: any, dt: number, time: number) -> ())?,
	destroy: ((self: any) -> ())?,
}

return nil
