class TestUploadFailure extends discord {
	static SendMessageAPI(*) {
		throw Error("Fixture delivery failure")
	}
}

class TestUploadEncodingFailure extends discord {
	static CreateFormData(*) {
		throw Error("Fixture encoding failure")
	}
}

TestUploadOwnership() {
	DirCreate "submacros"
	DirCreate "lib"
	FileCopy A_ScriptDir "\..\submacros\upload-archive.ps1", "submacros\upload-archive.ps1", true
	FileCopy A_ScriptDir "\..\lib\PowerShellJob.ps1", "lib\PowerShellJob.ps1", true
	; The whole suite's working directory is under A_Temp. The old sender
	; deleted these caller-owned files merely because of that location.
	path := A_WorkingDir "\owned-by-caller.txt", content := "caller data`nΩ🐝"
	FileAppend content, path, "UTF-8-RAW"
	TestDiscordReplies.Sent := []
	TestDiscordReplies.SendFile(path, "123")
	Assert(FileExist(path) && FileRead(path, "UTF-8") = content, "Successful upload preserves the original temp-directory file")
	AssertDeliveryError(() => TestUploadFailure.SendFile(path, "123"), "Delivery failure propagates")
	AssertEqual(FileRead(path, "UTF-8"), content, "Failed upload preserves the source")
	AssertDeliveryError(() => TestUploadEncodingFailure.SendFile(path, "123"), "Encoding failure propagates")
	AssertEqual(FileRead(path, "UTF-8"), content, "Failed encoding preserves the source")
	large := A_WorkingDir "\too-large.bin", stream := FileOpen(large, "w")
	stream.Length := 10485761, stream.Close()
	AssertEqual(TestDiscordReplies.SendFile(large, "123"), -1, "Oversized file is rejected")
	AssertEqual(FileGetSize(large), 10485761, "Oversized source is not deleted")

	name := "archive-" DllCall("GetCurrentProcessId") " [Ω] ' " Chr(59) " $(throw 7)"
	directory := A_WorkingDir "\" name, collision := A_Temp "\" name ".zip"
	DirCreate directory
	FileAppend "folder contents", directory "\entry.txt", "UTF-8-RAW"
	Assert(!FileExist(collision), "Collision fixture path starts unused")
	FileAppend "pre-existing zip sentinel", collision
	before := nm_UploadArchive.Active.Count
	try {
		; Exercise the actual PowerShell LiteralPath/shared-memory path. No remote
		; folder capability is enabled: only this local library test calls it.
		archive := nm_UploadArchive(directory)
		ownedDirectory := archive.Directory
		try {
			Assert(FileExist(archive.Path) && FileGetSize(archive.Path) > 0, "Real archive created for a literal Unicode/metacharacter path")
			zip := FileOpen(archive.Path, "r")
			AssertEqual(zip.ReadUShort(), 0x4b50, "Archive begins with the ZIP signature")
			zip.Close()
		} finally archive.Close()
		Assert(!DirExist(ownedDirectory), "Successful archive cleanup removes only its owned directory")
		AssertEqual(nm_UploadArchive.Active.Count, before, "Archive ownership released")
		AssertEqual(FileRead(collision), "pre-existing zip sentinel", "Predictable legacy ZIP path was never overwritten")
		AssertEqual(FileRead(directory "\entry.txt"), "folder contents", "Archive creation preserves source folder")
		TestDiscordReplies.SendFile(directory, "123")
		AssertEqual(nm_UploadArchive.Active.Count, before, "Directory send cleans up its generated archive")
		AssertDeliveryError(() => TestUploadFailure.SendFile(directory, "123"), "Archive delivery failure propagates")
		AssertEqual(nm_UploadArchive.Active.Count, before, "Failed directory delivery cleans up generated archive")
		AssertEqual(FileRead(collision), "pre-existing zip sentinel", "Cleanup does not delete caller's colliding ZIP")
		AssertDeliveryError(() => nm_UploadArchive(directory "\missing"), "Archive creation failure propagates")
		AssertEqual(nm_UploadArchive.Active.Count, before, "Failed archive creation releases owned directory")
	} finally {
		FileDelete collision
		DirDelete directory, true
	}
}
