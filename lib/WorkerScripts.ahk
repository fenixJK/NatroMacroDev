; Production worker builders are shared with CI so emitted stdin scripts are validated.

nm_BuildBitterberryFeederScript() {
	script :=
	(
	'
	#NoTrayIcon
	#SingleInstance Force

	#Include "%A_ScriptDir%\lib"
	#Include "Gdip_All.ahk"
	#Include "Gdip_ImageSearch.ahk"
	#Include "Roblox.ahk"
	#Include "nm_OpenMenu.ahk"
	#Include "nm_InventorySearch.ahk"

	CoordMode "Mouse", "Screen"
	OnExit(ExitFunc)
	pToken := Gdip_Startup()

	bitmaps := Map()
	bitmaps["itemmenu"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACcAAAAuAQAAAACD1z1QAAAAAnRSTlMAAHaTzTgAAAB4SURBVHjanc2hDcJQGAbAex9NQCCQyA6CqGMswiaM0lGACSoQDWn6I5A4zNnDiY32aCPbuoujA1rNUIsggqZRrgmGdJAd+qwN2YdDdEiPXUCgy3lGQJ6I8VK1ZoT4cQBjVa2tUAH/uTHwvZbcMWfClBduVK2i9/YB0wgl4MlLHxIAAAAASUVORK5CYII=")
	bitmaps["questlog"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACoAAAAnAQAAAABRJucoAAAAAnRSTlMAAHaTzTgAAACASURBVHjajczBCcJAEEbhl42wuSUVmFjJphRL2dLGEuxAxQIiePCw+MswBRgY+OANMxgUoJG1gZj1Bd0lWeIIkKCrgBqjxzcfjxs4/GcKhiBXVyL7M0WEIZiCJVgDoJPPJUGtcV5ksWMHB6jCWQv0dl46ToxqzJZePHnQw9W4/QAf0C04CGYsYgAAAABJRU5ErkJggg==")
	bitmaps["beemenu"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACsAAAAsAQAAAADUI3zVAAAAAnRSTlMAAHaTzTgAAACaSURBVHjadc5BDgIhDAXQT9U4y1m6G24inkyO4lGaOUm9AW7MzMY6HyQxJjaBFwotxdW3UAEjNhCc+/1z+mXGmgCH22Ti/S5bIRoXSMgtmTASBeOFsx6td/lDIgGIJ8Czl6kVRAguGL4mW9NcC8zJUjRvlCXXZH3kxiUYW+sBgewhRPq3exIwEOhYiZHl/nS3HdIBePQBlfvtDUnsNfflK46tAAAAAElFTkSuQmCC")
	bitmaps["item"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAMAAAAUAQMAAAByNRXfAAAAA1BMVEXU3dp/aiCuAAAAC0lEQVR42mMgEgAAACgAAU1752oAAAAASUVORK5CYII=")
	bitmaps["bitterberry"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAG8AAAAbCAMAAABFqCGFAAAB11BMVEUbKjUcKzYdLDceLDceLTgfLjkgLzohMDoiMDsjMTwkMj0kMz0lND4mND8oNkApN0EqOEMrOUMsOkQtO0UuPEYvPUcwPkgyQEkzQUo0QUs1Q0w3RU44RU85Rk86SFE8SVM9SlM+S1Q/TFVATVZCT1hDUFlEUVlFUVpGU1xHVFxJVV5KVl9LV19NWWJPW2NRXWVSXmZUYGhVYWhWYWlXYmpXY2tbZm5cZ29daG9eanFibXRibnVkb3ZlcHdoc3ptd35ueX9veoBweoFzfYN0foR1f4V2gIZ4god6hIp7hYt+h41/iY6Aio+FjpSGj5SHkJWKk5iLlJmMlZqNlpqOl5uQmJ2QmZ2Rmp6Sm5+UnKCVnaGZoaWbo6ecpKigp6uhqKyjq66mrbCnrrGnr7Kor7OrsrWss7avtrmwt7myuLu2vL+4v8G5wMK6wMO8wsS+xMa/xcfAxsjBx8nDyMrEyszGzM3HzM7Izc/Jzs/Jz9DK0NHN0tPP1NXQ1dbR1tfS19jV2drX3NzY3N3Z3d7b4ODc4OHe4uLf4+Pg5OTg5eXi5ubj5+fm6urn6+vo7Ovp7ezq7e3r7u7r7+7s8O/t8fDu8fHv8vHw8/Lx9PPx9fTy9fTz9vX09/ZX5XClAAACKElEQVR42u3W61NMYQDH8W9iu7uEhAhJURIphYRci0QiFXKJXAttQnIPXdVWK/3+WHvK6dnZfaY3O443fm9+L34zz2fmzDPnHORt+O/9BS8HJ6mlL2Xys6XJlCVTLbUxepDQJaln9b5ZSXs4J7dsKeZIzB45kvzpRY6XHYLcsiU/Ju+YpOHD8NEdPPDUD8+kL52dwcW9K2kF3cazzqYX8d5Ar9QMQ7qMk/o/JU3WZfnWnx2RVEpWPLSFvJ1FKekVvZIss9v10C9JfXAy0hsswTdu937tx0nepHMgkDCifHPFLLPbn5dQI0k18NpyX05r3ot8nq2sejz+dCVNcwfeDAwq5CW1TzzPZLttNl3CmqA0k0G+or3kd7J7uTRIqqNw7oFJcrwKSbfhvWU2fRfuSw+h1eKxdsjqBeKYT6pz0G4Z7yt0WGbTkys4IFWSPKpwr1rSjzPQbPW+4SYY4U1Dm3V2WyeIHxhOpEpRnoJJnLJ6E3BJ84nwQlS7bTaeHxquwwuLN5XIeRmvVgu1iTJJ09FeB7wys83TNjYXslXR3mg1+Be8XeTe8bt1gbgbga6Msu5wL+lWoG8L62ZkZpt3FeCa/f15VAteLfDJrYkdOFn+NtybS9w9ycw27/tS8A1ZvGXZjTPGGzuYvNfUaM0GX2bVB5mDqgoOFaWkFT+SrLPxVA6VXn5vG+GJl14eG2c99Hrgojz0jhM/4KE3lkK5PPRa4cG/+x/8DdlCsT+3EwaSAAAAAElFTkSuQmCC")
	bitmaps["feed"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAADwAAAAUAQMAAADrzcxqAAAABlBMVEUAAAD3//lCqWtQAAAAAXRSTlMAQObYZgAAAE1JREFUeNqNzbENwCAMRNHfpYxLSo/ACB4pG8SjMkImIAiwRIe46lX3+QtzAcE5wQ1cHeKQHhw10EwFwISK6YAvvCVg7LBamuM5fRGFBk/MFx8u1mbtAAAAAElFTkSuQmCC")
	bitmaps["greensuccess"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAA4AAAALCAYAAABPhbxiAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAhdEVYdENyZWF0aW9uIFRpbWUAMjAyMzowMzowOCAxNToyMzo1N/c+ABwAAAAdSURBVChTY3T+H/6fgQzABKVJBqMa8YDhr5GBAQBwxAKu5PiUjAAAAA5lWElmTU0AKgAAAAgAAAAAAAAA0lOTAAAAAElFTkSuQmCC")
	#Include "%A_ScriptDir%\nm_image_assets\offset\bitmaps.ahk"

	if (MsgBox("BITTERBERRY AUTO FEEDER v0.2 by anniespony#8135``nMake sure BEE SLOT TO MUTATE is always visible``nDO NOT MOVE THE SCREEN OR RESIZE WINDOW FROM NOW ON.``nMAKE SURE BEE IS RADIOACTIVE AT ALL TIMES!", "Bitterberry Auto-Feeder v0.2", 0x40001) = "Cancel")
		ExitApp

	bitterberrynos := InputBox("Enter the amount of bitterberry used each time", "How many bitterberry?", "w320 h180 T60").Value
	if IsInteger(bitterberrynos) {
		if (bitterberrynos > 30)
			if (MsgBox("You have entered " bitterberrynos " which is more than 30.``nAre you sure?", "Bitterberry Auto-Feeder v0.2", 0x40034) = "No")
				ExitApp
	} else {
		MsgBox "You must enter a number for Bitterberries!!``nStopping Feeder!", "Bitterberry Auto-Feeder v0.2", 0x40010
		ExitApp
	}

	if (MsgBox("After dismissing this message,``nleft click ONLY once on BEE SLOT", "Bitterberry Auto-Feeder v0.2", 0x40001) = "Cancel")
		ExitApp

	hwnd := GetRobloxHWND()
	ActivateRoblox()
	GetRobloxClientPos(hwnd)
	offsetY := GetYOffset(hwnd, &offsetfail)
	if (offsetfail = 1) {
		MsgBox "Unable to detect in-game GUI offset!``nStopping Feeder!``n``nThere are a few reasons why this can happen, including:``n - Incorrect graphics settings``n - Your `'Experience Language`' is not set to English``n - Something is covering the top of your Roblox window``n``nJoin our Discord server for support and our Knowledge Base post on this topic (Unable to detect in-game GUI offset)!", "WARNING!!", "0x40030"
		ExitApp
	}

	beeWindow := nm_ClientSnapshot(hwnd)
	if !beeWindow
		ExitApp
	StatusBar := Gui("-Caption +E0x80000 +AlwaysOnTop +ToolWindow -DPIScale")
	StatusBar.Show("NA")
	hbm := CreateDIBSection(windowWidth, windowHeight), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc), Gdip_SetSmoothingMode(G, 2), Gdip_SetInterpolationMode(G, 2)
	Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0x60000000), -1, -1, windowWidth+1, windowHeight+1), Gdip_DeleteBrush(pBrush)
	UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, windowHeight)

	KeyWait "LButton", "D" ; Wait for the left mouse button to be pressed down.
	MouseGetPos &beeX, &beeY
	if !nm_SameClient(beeWindow, nm_ClientSnapshot(hwnd)) || !KeyWait("LButton", "T5")
		ExitApp
	beeX -= beeWindow.x, beeY -= beeWindow.y
	if beeX < 0 || beeY < 0 || beeX >= beeWindow.width || beeY >= beeWindow.height
		ExitApp
	Gdip_GraphicsClear(G), Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0xd0000000), -1, -1, windowWidth+1, 38), Gdip_DeleteBrush(pBrush)
	Gdip_TextToGraphics(G, "Mutating... Right Click or Shift to Stop!", "x0 y0 cffff5f1f Bold Center vCenter s24", "Tahoma", windowWidth, 38)
	UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, 38)
	SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc), Gdip_DeleteGraphics(G)
	try
	{
		Hotkey "Shift", ExitFunc, "On"
		Hotkey "RButton", ExitFunc, "On"
		Hotkey "F11", ExitFunc, "On"
	}
	Sleep 250

	Loop
	{
		if ((pos := nm_InventorySearch("bitterberry", "down", , , , (A_Index = 1) ? 40 : 4)) = 0)
		{
			MsgBox "Could not locate Bitterberries in the readable inventory. Stopping.", "Bitterberry Auto-Feeder v0.2", 0x40010
			break
		}
		if !nm_DragInventoryItem(pos, beeX, beeY, beeWindow) {
			MsgBox "The selected slot or inventory item could not be verified. Stopping before another drag.", "Utility stopped", 0x40030
			break
		}
		Loop 10
		{
			Sleep 100
			pBMScreen := Gdip_BitmapFromScreen(windowX+(54*windowWidth)//100-300 "|" windowY+offsetY+(46*windowHeight)//100-59 "|250|100")
			if (Gdip_ImageSearch(pBMScreen, bitmaps["feed"], &pos, , , , , 2, , 2) = 1)
			{
				Gdip_DisposeImage(pBMScreen)
				SendEvent "{Click " windowX+(54*windowWidth)//100-300+SubStr(pos, 1, InStr(pos, ",")-1)+140 " " windowY+offsetY+(46*windowHeight)//100-59+SubStr(pos, InStr(pos, ",")+1)+5 "}" ; Click Number
				Sleep 100
				Loop StrLen(bitterberrynos)
				{
					SendEvent "{Text}" SubStr(bitterberrynos, A_Index, 1)
					Sleep 100
				}
				SendEvent "{Click " windowX+(54*windowWidth)//100-300+SubStr(pos, 1, InStr(pos, ",")-1) " " windowY+offsetY+(46*windowHeight)//100-59+SubStr(pos, InStr(pos, ",")+1) "}" ; Click Feed
				break
			}
			Gdip_DisposeImage(pBMScreen)
			if (A_Index = 10)
				continue 2
		}
		Sleep 750

		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-295 "|" windowY+offsetY+((4*windowHeight)//10 - 15) "|150|50")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["greensuccess"], , , , , , 20) = 1) {
			if (MsgBox("SUCCESS!!!!``nKeep this?", "Bitterberry Auto-Feeder v0.2", 0x40024) = "Yes")
			{
				Gdip_DisposeImage(pBMScreen)
				break
			}
			else
			{
				ActivateRoblox()
				SendEvent "{Click " windowX + (windowWidth//2 - 132) " " windowY + offsetY + ((4*windowHeight)//10 - 150) "}" ; Close Bee
			}
		}
		Gdip_DisposeImage(pBMScreen)
	}
	ExitApp

	ExitFunc(*)
	{
		nm_InventoryPointer.Cancel()
		try StatusBar.Destroy()
		try Gdip_Shutdown(pToken)
		ExitApp
	}
	'
	)

	return script
}

nm_BuildBasicEggHatcherScript() {
	script :=
	(
	'
	#NoTrayIcon
	#SingleInstance Force

	#Include "%A_ScriptDir%\lib"
	#Include "Gdip_All.ahk"
	#Include "Gdip_ImageSearch.ahk"
	#Include "Roblox.ahk"
	#Include "nm_OpenMenu.ahk"
	#Include "nm_InventorySearch.ahk"

	CoordMode "Mouse", "Screen"
	OnExit(ExitFunc)
	pToken := Gdip_Startup()

	bitmaps := Map()
	bitmaps["itemmenu"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACcAAAAuAQAAAACD1z1QAAAAAnRSTlMAAHaTzTgAAAB4SURBVHjanc2hDcJQGAbAex9NQCCQyA6CqGMswiaM0lGACSoQDWn6I5A4zNnDiY32aCPbuoujA1rNUIsggqZRrgmGdJAd+qwN2YdDdEiPXUCgy3lGQJ6I8VK1ZoT4cQBjVa2tUAH/uTHwvZbcMWfClBduVK2i9/YB0wgl4MlLHxIAAAAASUVORK5CYII=")
	bitmaps["questlog"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACoAAAAnAQAAAABRJucoAAAAAnRSTlMAAHaTzTgAAACASURBVHjajczBCcJAEEbhl42wuSUVmFjJphRL2dLGEuxAxQIiePCw+MswBRgY+OANMxgUoJG1gZj1Bd0lWeIIkKCrgBqjxzcfjxs4/GcKhiBXVyL7M0WEIZiCJVgDoJPPJUGtcV5ksWMHB6jCWQv0dl46ToxqzJZePHnQw9W4/QAf0C04CGYsYgAAAABJRU5ErkJggg==")
	bitmaps["beemenu"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACsAAAAsAQAAAADUI3zVAAAAAnRSTlMAAHaTzTgAAACaSURBVHjadc5BDgIhDAXQT9U4y1m6G24inkyO4lGaOUm9AW7MzMY6HyQxJjaBFwotxdW3UAEjNhCc+/1z+mXGmgCH22Ti/S5bIRoXSMgtmTASBeOFsx6td/lDIgGIJ8Czl6kVRAguGL4mW9NcC8zJUjRvlCXXZH3kxiUYW+sBgewhRPq3exIwEOhYiZHl/nS3HdIBePQBlfvtDUnsNfflK46tAAAAAElFTkSuQmCC")
	bitmaps["item"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAMAAAAUAQMAAAByNRXfAAAAA1BMVEXU3dp/aiCuAAAAC0lEQVR42mMgEgAAACgAAU1752oAAAAASUVORK5CYII=")
	bitmaps["basicegg"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAGIAAAAaCAMAAAB7CnmQAAABuVBMVEUbKjUdLDceLDceLTgfLjkgLzohMDoiMDsjMTwkMj0lND4nNUAoNkApOEIqOEMrOUMsOkQtO0UuPEYvPEYvPUcwPkgxP0kyQEkzQUo0QUs1Qkw2RE03RU44RU85Rk86SFE7SVI8SVNATVZEUVlGUltGU1xKVl9LV19MWWFPW2NQXGRRXWVVYWhWYWlXYmpXY2tdaXBeanFga3JhbHNibXRibnVjbnVkb3ZmcXhncnhoc3ppdHtqdXtsdn1td35ueX9veoBweoFzfYN0foR1f4V2gIZ3gYd4god6hIp+h42Ci5GFjpSGj5SIkZaJkpePl5yQmJ2VnaGWnqKZoaWaoqabo6ecpKidpamfp6qjq66mrbCnr7Kor7Ots7avtrmwt7m1vL63vcC+xMa/xcfAxsjBx8nCyMnDyMrEyszFy8zGzM3HzM7Izc/Jzs/Jz9DN0tPQ1dbR1tfS19jT2NjU2NnV2drV2tvW29zY3N3Z3d7a39/c4OHe4uLg5OTg5eXi5ubj5+fl6ejm6enm6uro7Ovp7ezq7e3r7u7r7+7s8O/t8fDu8fHv8vHw8/Lx9PPx9fTy9fTz9vX09/Y9aLFlAAACKklEQVR42u3Ta1MSUQDG8cfiVmZBUoqmBhVkRtj9JkmoSRGmlbZadiG6mXnpSmG6QWlqCDyfuNlYTu3sMsNM6zufV/9X5zc7Zw+46cMWUTvhg7KdoenNJgDbU1bZa9fxEvXzQt2zWgn4WGVTzs7/JSIkc+eBNGubIKJq1UZwHkiRfHm5xdI8mOW/yySTeTOIWeANmd4GZQdzJJOd9Q1d4wVyBJBJyv0t1v3nZoyJwu1DDncEkDStIZaCsK6QHDgQH+sGhsgndVAWrhDf2qHM8cKQCKM8SbSGUDdIkqt5stiGIHkS/uzHIW+6QtxA3f21lNOaoPa6ZaWfA+GFhR5AEm1A7HhLkp/ONmxvqkeAjMDzuMgSK8Q+nCY5vUQjIgbnL/IrIIk2IOCWyczecvvJd7sAT2K5QqwAd6pf9wl0Uz1WbS0RJbkcA0bIa2ifXf/QoRD8fNEKtM6pRBp4UJ3wo1c9VrSOYN6BAfIwxkge+UOQi3EbAjV9RRdOqceK1hPrdsSVw28JYoPkKPBTcxevFg2JCJqK6rFq64nvUWCK7IcrlbtrU4gJz/gPuQeODe0fZUkYEY+A69nMBUASbXTdvSS/iOuWG8t1U7yLNt27UBciS0G1JdE6wuIdLlAxrrjtR6+GYqQc99ldxyb593X3NVvdZ2ZoRHA13mFtvARIogVh6uaBh5o2nxgG5jRtOvF+N1oLmjabmNwDjGradOIe0Kdp84m1wERJ378B3+p4iisaatgAAAAASUVORK5CYII=")
	bitmaps["royaljelly"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAGwAAAAcCAMAAACzmqo+AAAB+FBMVEUbKjUcKzYdLDceLDceLTgfLjkgLzohMDoiMDsjMTwkMj0kMz0lND4mND8nNUAoNkApN0EpOEIqOEMrOUMsOkQtO0UuPEYvPEYvPUcwPkgyQEkzQUo0QUs1Qkw1Q0w3RU44RU85Rk86SFE7SVI8SVM+S1Q/TFVDUFlEUVlFUVpGUltGU1xIVV1KVl9LV19MWWFPW2NWYWlXYmpXY2tbZm5cZ29daG9daXBga3JibXRibnVlcHdpdHttd35weoFxe4FyfIJzfYN0foR1f4V2gIZ3gYd4god5goh6hIp7hYt8hot+h41/iI6Aio+BipCCi5GFjpSFjpOGj5SHkJWIkZaJkpeKk5iKk5eLlJmMlZqNlpqPl5yQmJ2QmZ2Rmp6Sm5+UnKCVnaGaoqabo6ecpKigp6ujq66kq6+lrLCor7Ots7avtrmwt7mxt7qyuLu1vL62vL+3vcC5wMK6wMO8wsS9w8W/xcfAxsjDyMrDycvEyszGzM3HzM7Jzs/K0NHL0NLN0tPO09TP1NXQ1dbR1tfS19jT2NjV2drV2tvW29zX3NzY3N3a39/b4ODc4OHd4eLe4uLf4+Pg5OTg5eXi5ubj5+fk6Ojm6enm6urn6+vo7Ovp7ezq7e3r7u7r7+7s8O/t8fDu8fHv8vHw8/Lx9fTy9fTz9vX09/a7z3nGAAACf0lEQVR42u3W+VOMcQDH8Y9KVkUUkXQqJEqH0OWokHLlzplyRSgJFZWjnEmOtqhWx77/TbNPzHeenbZtZk3GjPcPO7O73/m8dvZ5fnjEPKb/2L+IpcqTI+sBc6s9d2RuR8xBb0wKaWEuXZe+Y69Beul9ZPrVJ6Z1bvBf7eyYOVI7M7YHGMiROucLo0tqwmdtRfEL4/YN/insmfQC+FyW4EiqGIRT1nvr81LeBk//0c5ZMFd1UujaiiEbZlsx2NBOpQMD8fKU8pX3QaoEqJSeQlni0frt0knf2FSOPKW7bJhtReYGWfwEKFdks6txsY5AtmImYDJWGcDYBEwlKds3Vqfo5pGWKF2yYbYVgwV1A1NLdBo4qFVwU7oF96Q64HXB8pA1S5XpG9ugGqBamXbMrJhr1ig1Ax+kx1jfDeNapm1QqLBh6IuR1Raf2NgCTRdhx8yKwcajVAR0Sr1Ah/QK9iq43+lQMVCu5K4fvSm+sZ4B/W7ChpkVg7Fb4SPwUWoDmqxz7VJNvfQI2KR6IMMbw9kHcE3qH5XOznjrmxWDtUo3wB3965rFA6xXSqbSsJhzM2CTu8K2TgIlWuEmWXnAuB2zrRjMHa9s4LAi7rpuO6Z/5UVJugxQqpUPnVcWeWHsl3b0OOtCVAXHteDqWGtsXpsXZlYMxiEF9YMzTZ7SRwA+hUihXwDezXyDuApktXkURjfKU+Rzb8ysGKxbugAMVyU7Uo+NYpUvFYKlFa92ZJXkHrBjuBuyYxelnrCOD1cmhMYVv8EbMytits5L9wkks+IfS1eimwAyK/6xDukMgWRW/GMlCu4ngMyKf+xbuPIJJLPiH6uT7hBAZuVvPMr9BDBOM9MqS26gAAAAAElFTkSuQmCC")
	bitmaps["giftedstar"] := Gdip_CreateBitmap(8,8), G := Gdip_GraphicsFromImage(bitmaps["giftedstar"]), Gdip_GraphicsClear(G,0xffffac33), Gdip_DeleteGraphics(G)
	bitmaps["yes"] := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAB0AAAAPAQMAAAAiQ1bcAAAABlBMVEUAAAD3//lCqWtQAAAAAXRSTlMAQObYZgAAAFZJREFUeAEBSwC0/wDDAAfAAEIACGAAfgAQMAA8ABAQABgAIAgAGAAgCAAYACAYABgAP/gAGAAgAAAYAAAAABgAIAAAGAAwAAAYADAAABgAGDAAGAAP4FGfB+0KKAbEAAAAAElFTkSuQmCC")
	#Include "%A_ScriptDir%\nm_image_assets\offset\bitmaps.ahk"
	common := Gdip_CreateBitmap(1,4), G := Gdip_GraphicsFromImage(common), Gdip_GraphicsClear(G,0xffae792f), Gdip_DeleteGraphics(G)
	mythic := Gdip_CreateBitmap(2,2), G := Gdip_GraphicsFromImage(mythic), Gdip_GraphicsClear(G,0xffbda4ff), Gdip_DeleteGraphics(G)
	if (MsgBox("WELCOME TO THE BASIC BEE REPLACEMENT PROGRAM!!!!!``nMade by anniespony#8135``n``nMake sure BEE SLOT TO CHANGE is always visible``nDO NOT MOVE THE SCREEN OR RESIZE WINDOW FROM NOW ON.``nMAKE SURE AUTO-JELLY IS DISABLED!!", "Basic Bee Replacement Program", 0x40001) = "Cancel")
		ExitApp

	if (MsgBox("After dismissing this message,``nleft click ONLY once on BEE SLOT", "Basic Bee Replacement Program", 0x40001) = "Cancel")
		ExitApp
	hwnd := GetRobloxHWND()
	ActivateRoblox()
	GetRobloxClientPos(hwnd)
	offsetY := GetYOffset(hwnd, &offsetfail)
	if (offsetfail = 1) {
		MsgBox "Unable to detect in-game GUI offset!``nStopping Hatcher!``n``nThere are a few reasons why this can happen, including:``n - Incorrect graphics settings``n - Your `'Experience Language`' is not set to English``n - Something is covering the top of your Roblox window``n``nJoin our Discord server for support and our Knowledge Base post on this topic (Unable to detect in-game GUI offset)!", "WARNING!!", 0x40030
		ExitApp
	}
	beeWindow := nm_ClientSnapshot(hwnd)
	if !beeWindow
		ExitApp
	StatusBar := Gui("-Caption +E0x80000 +AlwaysOnTop +ToolWindow -DPIScale")
	StatusBar.Show("NA")
	hbm := CreateDIBSection(windowWidth, windowHeight), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
	G := Gdip_GraphicsFromHDC(hdc), Gdip_SetSmoothingMode(G, 2), Gdip_SetInterpolationMode(G, 2)
	Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0x60000000), -1, -1, windowWidth+1, windowHeight+1), Gdip_DeleteBrush(pBrush)
	UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, windowHeight)
	KeyWait "LButton", "D" ; Wait for the left mouse button to be pressed down.
	MouseGetPos &beeX, &beeY
	if !nm_SameClient(beeWindow, nm_ClientSnapshot(hwnd)) || !KeyWait("LButton", "T5")
		ExitApp
	beeX -= beeWindow.x, beeY -= beeWindow.y
	if beeX < 0 || beeY < 0 || beeX >= beeWindow.width || beeY >= beeWindow.height
		ExitApp
	Gdip_GraphicsClear(G), Gdip_FillRectangle(G, pBrush := Gdip_BrushCreateSolid(0xd0000000), -1, -1, windowWidth+1, 38), Gdip_DeleteBrush(pBrush)
	Gdip_TextToGraphics(G, "Hatching... Right Click or Shift to Stop!", "x0 y0 cffff5f1f Bold Center vCenter s24", "Tahoma", windowWidth, 38)
	UpdateLayeredWindow(StatusBar.Hwnd, hdc, windowX, windowY, windowWidth, 38)
	SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc), Gdip_DeleteGraphics(G)
	Hotkey "Shift", ExitFunc, "On"
	Hotkey "RButton", ExitFunc, "On"
	Hotkey "F11", ExitFunc, "On"
	Sleep 250
	rj := 0
	Loop
	{
		if YesButton() {
			sleep 750
			if detect(&rj)
				break
			continue
		}
		if ((pos := (A_Index = 1) ? nm_InventorySearch("basicegg", "up", , , , 70) : (rj = 1) ? nm_InventorySearch("royaljelly", "down", , , 0, 7) : nm_InventorySearch("basicegg", "up", , , 0, 7)) = 0)
		{
			MsgBox "Could not locate " ((rj = 1) ? "Royal Jellies" : "Basic Eggs") ". Stopping.", "Basic Bee Replacement Program", 0x40010
			break
		}
		if !nm_DragInventoryItem(pos, beeX, beeY, beeWindow) {
			MsgBox "The selected slot or inventory item could not be verified. Stopping before another drag.", "Utility stopped", 0x40030
			break
		}
		Loop 10
		{
			Sleep 100
			if YesButton()
				break
			if (A_Index = 10)
			{
				rj := 1
				continue 2
			}
		}
		Sleep 750
		if detect(&rj)=1
			break
		sleep 100
	}
	detect(&rj) {
		rj := 0
		pBMScreen := Gdip_BitmapFromScreen(windowX+(windowWidth//2)-155 "|" windowY+(((4*windowHeight)//10) - 135) "|310|205")
		if (Gdip_ImageSearch(pBMScreen, mythic, , , , , , 2) = 1) { ; Mythic Hatched
			if (MsgBox("MYTHIC!!!!``nKeep this?", "Basic Bee Replacement Program", 0x40024) = "Yes")
			{
				Gdip_DisposeImage(pBMScreen)
				return 1
			}
		}
		else if (Gdip_ImageSearch(pBMScreen, common, , , , , , 2) = 1) { ; check if common
			rj := 1
			if (Gdip_ImageSearch(pBMScreen, bitmaps["giftedstar"], , , , , , 5) = 1) { ; If gifted is hatched, stop
				MsgBox "SUCCESS!!!!", "Basic Bee Replacement Program", 0x40020
				Gdip_DisposeImage(pBMScreen)
				return 1
			}
		}
		else if (Gdip_ImageSearch(pBMScreen, bitmaps["giftedstar"], , , , , , 5) = 1) { ; Non-Basic Gifted Hatched
			if (MsgBox("GIFTED!!!!``nKeep this?", "Basic Bee Replacement Program", 0x40024) = "Yes")
			{
				Gdip_DisposeImage(pBMScreen)
				return 1
			}
		}
		Gdip_DisposeImage(pBMScreen)
		return 0
	}
	YesButton(){
		pBMScreen := Gdip_BitmapFromScreen(windowX+windowWidth//2-250 "|" windowY+windowHeight//2-52 "|500|150")
		if (Gdip_ImageSearch(pBMScreen, bitmaps["yes"], &pos, , , , , 2, , 2) = 1)
		{
			Gdip_DisposeImage(pBMScreen)
			SendEvent "{Click " windowX+windowWidth//2-250+SubStr(pos, 1, InStr(pos, ",")-1) " " windowY+windowHeight//2-52+SubStr(pos, InStr(pos, ",")+1) "}"
			return 1
		}
		Gdip_DisposeImage(pBMScreen)
		return 0
	}
	ExitApp

	ExitFunc(*)
	{
		nm_InventoryPointer.Cancel()
		try Gdip_DisposeImage(common), Gdip_DisposeImage(mythic)
		try StatusBar.Destroy()
		try Gdip_Shutdown(pToken)
		ExitApp
	}
	'
	)

	return script
}

nm_BuildWalkScript(movement, vars, NewWalk, MoveSpeedNum, offset, keyVars, LeftKey, RightKey, FwdKey, BackKey, SC_Space, SC_E) {
	script :=
	(
	'
	#SingleInstance Off
	#NoTrayIcon
	ProcessSetPriority("AboveNormal")
	KeyHistory 0
	ListLines 0
	OnExit(ExitFunc)

	#Include "%A_ScriptDir%\lib"
	#Include "Gdip_All.ahk"
	#Include "Gdip_ImageSearch.ahk"
	#Include "HyperSleep.ahk"
	#Include "Roblox.ahk"
	'
	)

	; #Include Walk.ahk performs most of the initialisation, i.e. creating bitmaps and storing the necessary functions
	; MoveSpeedNum must contain the exact in-game movespeed without buffs so the script can calculate the true base movespeed

	. (NewWalk ?
	(
	'
	#Include "Walk.ahk"

	movespeed := ' MoveSpeedNum '
	both            := (Mod(movespeed*1000, 1265) = 0) || (Mod(Round((movespeed+0.005)*1000), 1265) = 0)
	hasty_guard     := (both || Mod(movespeed*1000, 1100) < 0.00001)
	gifted_hasty    := (both || Mod(movespeed*1000, 1150) < 0.00001)
	base_movespeed  := round(movespeed / (both ? 1.265 : (hasty_guard ? 1.1 : (gifted_hasty ? 1.15 : 1))), 0)
	'
	) :
	(
	'
	(bitmaps := Map()).CaseSense := 0
	pToken := Gdip_Startup()
	Walk(param, *) => HyperSleep(4000/' MoveSpeedNum '*param)
	'
	))

	. (
	(
	'
	offsetY := ' offset '

	' keyVars '
	' vars '

	start()
	return

	nm_Walk(tiles, MoveKey1, MoveKey2:=0)
	{
		Send "{" MoveKey1 " down}" (MoveKey2 ? "{" MoveKey2 " down}" : "")
		' (NewWalk ? 'Walk(tiles)' : ('HyperSleep(4000/' MoveSpeedNum '*tiles)')) '
		Send "{" MoveKey1 " up}" (MoveKey2 ? "{" MoveKey2 " up}" : "")
	}

	F13::
		start(hk?)
		{
			Send "{F14 down}"
			' movement '
			Send "{F14 up}"
		}

	F16::
	{
		static key_states := Map(LeftKey,0, RightKey,0, FwdKey,0, BackKey,0, "LButton",0, "RButton",0, SC_E,0)
		if A_IsPaused
		{
			for k,v in key_states
				if (v = 1)
					Send "{" k " down}"
		}
		else
		{
			for k,v in key_states
			{
				key_states[k] := GetKeyState(k)
				Send "{" k " up}"
			}
		}
		Pause -1
	}

	ExitFunc(*)
	{
		Send "{' LeftKey ' up}{' RightKey ' up}{' FwdKey ' up}{' BackKey ' up}{' SC_Space ' up}{F14 up}{' SC_E ' up}"
		try Gdip_Shutdown(pToken)
	}
	'
	)) ; this is just ahk code, it will be executed as a new script

	return script
}
