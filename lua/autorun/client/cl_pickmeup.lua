hook.Add( "AddToolMenuCategories", "Cat", function()
	spawnmenu.AddToolCategory( "Options", "NPC Revive System", "#NPC Revive System" )
end )

hook.Add( "PopulateToolMenu", "Cat", function()
	spawnmenu.AddToolMenuOption( "Options", "NPC Revive System", "NPCRevivalMenu", "#NPC Revival Settings", "", "", function( panel )
		local super = LocalPlayer():IsSuperAdmin()

		panel:ClearControls()

		if not super then
			panel:Help( "Only super admins can change NPC Revival Settings." )
			return
		end

		panel:CheckBox( "Enable NPC Revival", "pickup_system_enabled" )
		panel:CheckBox( "Revive Under Fire", "pickup_revive_underfire" )
		panel:NumSlider( "Revive Distance", "pickup_revive_distance", 0, 100, 0 )
	end )
end )