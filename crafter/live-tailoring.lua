--LIVE 10/2022

--leather = {
--	tier1 = 'rawhide',
--	tier2 = 'tanned',
--	tier3 = 'cured',
--	tier4 = 'hard',
--	tier5 = 'rigid',
--	tier6 = 'embossed',
--	tier7 = 'rigid',
--	tier8 = 'runed',
--	tier9 = 'eldritch',
--	tier10 = 'tempered',
--}

--[1] = Alb , [2] = Mid, [3] = Hib
return T {
	T{
		--alb
	},
	T{
		--mid
	},
	T{	--hib
		--tier 1
		T{
			T{level = 15, name = 'rawhide brea gloves', mats = T{leather = 3, thread = 2}, itemId = 62281},
			T{level = 45, name = 'rawhide brea boots', mats = T{leather = 3, thread = 2}, itemId = 64841},
			T{level = 65, name = 'rawhide constaic boots', mats = T{leather = 5, thread = 2}, itemId = 14666},
			T{level = 95, name = 'rawhide cruaigh gloves', mats = T{leather = 10, thread = 4}, itemId = 27466},
		},
		--Tier 2
		T{
			T{level = 15, name = 'tanned brea gloves', mats = T{leather = 3, thread = 2}, itemId = 62537},
			T{level = 45, name = 'tanned brea boots', mats = T{leather = 3, thread = 2}, itemId = 65097},
			T{level = 65, name = 'tanned constaic boots', mats = T{leather = 5, thread = 2}, itemId = 14922},
			T{level = 95, name = 'tanned cruaigh gloves', mats = T{leather = 10, thread = 4}, itemId = 27722},
		},
	}
}