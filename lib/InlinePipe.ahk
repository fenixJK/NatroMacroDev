; Blocking pipe operations run only in the contained supervisor, never in main.
; The generated AHK child inherits that job. Only its pipe ends are inherited.
class nm_InlinePipe {
	static Run(request, channel) {
		if !(request is Map) || !request.Has("source") || !(request["source"] is String)
			|| !request.Has("executable") || !(request["executable"] is String) || !request.Has("validate")
			throw ValueError("Invalid generated script request")
		executable := request["executable"]
		if InStr(executable, '"') || !FileExist(executable)
			throw ValueError("Invalid generated script runtime")
		inputRead := inputWrite := outputRead := outputWrite := processHandle := 0
		attributesReady := false
		try {
			security := Buffer(A_PtrSize = 8 ? 24 : 12, 0)
			NumPut("UInt", security.Size, security), NumPut("Int", true, security, A_PtrSize = 8 ? 16 : 8)
			if !DllCall("CreatePipe", "PtrP", &inputRead, "PtrP", &inputWrite, "Ptr", security, "UInt", 0)
				|| !DllCall("CreatePipe", "PtrP", &outputRead, "PtrP", &outputWrite, "Ptr", security, "UInt", 0)
				|| !DllCall("SetHandleInformation", "Ptr", inputWrite, "UInt", 1, "UInt", 0)
				|| !DllCall("SetHandleInformation", "Ptr", outputRead, "UInt", 1, "UInt", 0)
				throw OSError()
			DllCall("InitializeProcThreadAttributeList", "Ptr", 0, "UInt", 1, "UInt", 0, "UPtrP", &attributeBytes := 0)
			if !attributeBytes || attributeBytes > 65536
				throw Error("Invalid pipe worker attribute allocation")
			attributes := Buffer(attributeBytes)
			if !DllCall("InitializeProcThreadAttributeList", "Ptr", attributes, "UInt", 1, "UInt", 0, "UPtrP", &attributeBytes)
				throw OSError()
			attributesReady := true, inherited := Buffer(2 * A_PtrSize)
			NumPut("Ptr", inputRead, "Ptr", outputWrite, inherited)
			if !DllCall("UpdateProcThreadAttribute", "Ptr", attributes, "UInt", 0, "UPtr", 0x20002,
				"Ptr", inherited, "UPtr", inherited.Size, "Ptr", 0, "Ptr", 0)
				throw OSError()
			startup := Buffer(A_PtrSize = 8 ? 112 : 72, 0), info := Buffer(A_PtrSize * 2 + 8, 0)
			NumPut("UInt", startup.Size, startup), NumPut("UInt", 0x101, startup, A_PtrSize = 8 ? 60 : 44)
			NumPut("Ptr", inputRead, "Ptr", outputWrite, "Ptr", outputWrite, startup, A_PtrSize = 8 ? 80 : 56)
			NumPut("Ptr", attributes.Ptr, startup, A_PtrSize = 8 ? 104 : 68)
			command := '"' executable '" /script /CP65001 /ErrorStdOut=UTF-8 ' (request["validate"] ? "/Validate" : "/force") ' *'
			mutable := Buffer((StrLen(command) + 1) * 2), StrPut(command, mutable, "UTF-16")
			if !DllCall("CreateProcessW", "Str", executable, "Ptr", mutable, "Ptr", 0, "Ptr", 0, "Int", true,
				"UInt", 0x08080000, "Ptr", 0, "Str", A_WorkingDir, "Ptr", startup, "Ptr", info)
				throw OSError()
			processHandle := NumGet(info, 0, "Ptr"), childPid := NumGet(info, A_PtrSize * 2, "UInt")
			DllCall("CloseHandle", "Ptr", NumGet(info, A_PtrSize, "Ptr"))
			DllCall("CloseHandle", "Ptr", inputRead), inputRead := 0
			DllCall("CloseHandle", "Ptr", outputWrite), outputWrite := 0
			NumPut("UInt", childPid, channel.View, 12)
			encoded := Buffer(StrPut(request["source"], "UTF-8"))
			StrPut(request["source"], encoded, "UTF-8")
			offset := 0
			while offset < encoded.Size - 1 {
				if !DllCall("WriteFile", "Ptr", inputWrite, "Ptr", encoded.Ptr + offset, "UInt", encoded.Size - 1 - offset, "UIntP", &written := 0, "Ptr", 0) || !written
					throw Error("Could not write generated script")
				offset += written
			}
			DllCall("CloseHandle", "Ptr", inputWrite), inputWrite := 0
			NumPut("Int", 3, channel.View, 8)
			response := channel.View + nm_InlineProtocol.Response, chunk := Buffer(4096), length := 0, overflow := false
			Loop {
				if !DllCall("ReadFile", "Ptr", outputRead, "Ptr", chunk, "UInt", chunk.Size, "UIntP", &read := 0, "Ptr", 0) {
					if A_LastError = 109
						break
					throw Error("Could not read generated script output")
				}
				if !read
					break
				if length + read > nm_InlineProtocol.OutputBytes {
					overflow := true
					DllCall("TerminateProcess", "Ptr", processHandle, "UInt", 1)
					break
				}
				DllCall("RtlMoveMemory", "Ptr", response + 16 + length, "Ptr", chunk, "UPtr", read)
				length += read
			}
			if DllCall("WaitForSingleObject", "Ptr", processHandle, "UInt", 2000) != 0
				throw Error("Generated worker output ended before process completion")
			if !DllCall("GetExitCodeProcess", "Ptr", processHandle, "UIntP", &code := 0)
				throw OSError()
			NumPut("UInt", code, "UInt", length, "UInt", overflow, response)
			NumPut("Int", 1, channel.View, 8)
		} finally {
			if processHandle {
				if DllCall("WaitForSingleObject", "Ptr", processHandle, "UInt", 0) = 258 {
					DllCall("TerminateProcess", "Ptr", processHandle, "UInt", 1)
					DllCall("WaitForSingleObject", "Ptr", processHandle, "UInt", 2000)
				}
				DllCall("CloseHandle", "Ptr", processHandle)
			}
			for handle in [inputRead, inputWrite, outputRead, outputWrite]
				if handle
					DllCall("CloseHandle", "Ptr", handle)
			if attributesReady
				DllCall("DeleteProcThreadAttributeList", "Ptr", attributes)
		}
	}
}
