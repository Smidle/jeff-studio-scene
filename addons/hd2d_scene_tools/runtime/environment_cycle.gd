@tool
extends RefCounted
## Pure sampling: never writes the authored hour or base environment parameters.
static func sample(stage, hour: float, mode_override: int=-1, intensity_override: float=-1.0) -> Dictionary:
	var state := {"sky":stage.sky_color, "horizon":stage.horizon_color,
		"sun_color":stage.sun_color, "sun_energy":stage.sun_energy,
		"sun_elevation":stage.sun_elevation, "ambient_color":stage.ambient_color,
		"ambient_energy":stage.ambient_energy, "moon_energy":0.0,
		"fog_enabled":stage.fog_enabled, "fog_density":stage.fog_density}
	if stage.day_night_enabled:
		var elevation := sin((fposmod(hour,24.0)-6.0)/24.0*TAU)*75.0
		var daylight := smoothstep(-8.0,20.0,elevation)
		var sunrise := (1.0-smoothstep(0.0,25.0,absf(elevation)))*daylight
		state.sky=stage.night_sky_color.lerp(stage.sky_color,daylight)
		state.horizon=stage.night_horizon_color.lerp(stage.horizon_color,daylight).lerp(Color("efaf7c"),sunrise*0.6)
		state.sun_color=stage.sun_color.lerp(Color("ffc18b"),sunrise*0.65)
		state.sun_energy=stage.sun_energy*smoothstep(-3.0,30.0,elevation)
		state.sun_elevation=elevation
		state.ambient_color=Color("9cafd3").lerp(stage.ambient_color,daylight)
		state.ambient_energy=lerpf(stage.night_brightness,stage.ambient_energy,daylight)
		state.moon_energy=stage.moon_energy*smoothstep(0.0,25.0,-elevation)
	var selected: int=stage.weather_mode if mode_override<0 else mode_override
	var intensity: float=stage.weather_intensity if intensity_override<0 else intensity_override
	if selected>=2 and selected<=6 and intensity>0.0:
		var strength: float=clampf(intensity,0,1)
		# Retired IDs 1 and 7 fall back to Clear; remaining saved IDs stay stable.
		var mode: int=selected
		var sky_tint := Color("8b9da9")
		var horizon_tint := Color("b0bcc5")
		var sunlight := 0.62 if mode==3 else 0.38
		var haze := 0.003 if mode==3 else 0.0018
		if mode==4:
			sunlight=0.45;haze=0.014;horizon_tint=Color("c3ced0")
		elif mode==5:
			sunlight=0.30;haze=0.011;sky_tint=Color("b49460");horizon_tint=Color("c6a16c")
		elif mode==6:
			sunlight=0.18;haze=0.005;sky_tint=Color("67788c")
		state.sky=state.sky.lerp(state.sky.get_luminance()*sky_tint,strength*0.8)
		state.horizon=state.horizon.lerp(state.horizon.get_luminance()*horizon_tint,strength*0.8)
		state.sun_energy*=lerpf(1.0,sunlight,strength)
		state.moon_energy*=lerpf(1.0,0.65,strength)
		# Weather haze is part of the selected weather, independent of the base fog switch.
		state.fog_enabled=stage.fog_enabled or haze>0.0
		state.fog_density=maxf(stage.fog_density if stage.fog_enabled else 0.0,haze*strength)
	return state
