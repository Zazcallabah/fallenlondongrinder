using System;
using System.IO;

namespace fl{
	public static class FileHandler
	{
		static string GetWorkingDirectory()
		{
			var assembly = new System.IO.FileInfo(System.Reflection.Assembly.GetExecutingAssembly().Location);
			return assembly.Directory.FullName;
		}
		static DirectoryInfo GetDir(string name)
		{
			var target = System.IO.Path.Combine(GetWorkingDirectory(), name);
			return new System.IO.DirectoryInfo(target);
		}
		public static FileInfo GetFile(string name)
		{
			var target = System.IO.Path.Combine(GetWorkingDirectory(), name);
			return new System.IO.FileInfo(target);
		}

		public static void ForEachFile(string foldername, Action<string, string> callback)
		{
			var files = GetDir(foldername).GetFiles("*.json");
			foreach (var file in files)
			{
				callback(file.Name, ReadFile(file));
			}
		}

		public static string ReadFile(string filename)
		{
			return ReadFile(GetFile(filename));
		}

		static string ReadFile(FileInfo file)
		{
			return File.ReadAllText(file.FullName, System.Text.Encoding.UTF8);
		}
	}
}