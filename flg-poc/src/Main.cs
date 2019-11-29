using System.Net;
using System.Linq;
using System.Threading.Tasks;
using System.Net.Http;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;
using System.IO;

namespace fl
{
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

		public static void ForEachFile(string foldername, Action<string,string> callback )
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

	public class Main
	{		public static async Task Run(TimerInfo timer, ILogger log)
		{
			Log._logObject = log;

			log.LogInformation(Environment.GetEnvironmentVariable("CustomSetting", EnvironmentVariableTarget.Process));
		}
	}

	public class Handler2
	{
		Session _main;
		Session _automaton;

		public Handler2(string email, string password, string autoEmail, string autoPass)
		{
			// if( string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password) )
			// 	throw new Exception("missing login information");
			_main = new Session(email,password);

// 			var cardhandler = new CardHandler();


// 			_main.HasActionsToSpare()

// // 			$script:LockedAreas = gc -Raw $PSScriptRoot/lockedareas.json | ConvertFrom-Json
// // $automaton = gc $PSScriptRoot/automaton.csv


// //$result = FilterCards

// //	if( HasActionsToSpare )
// 	{
// 		$hasActionsLeft = HandleLockedArea
// 		if( !$hasActionsLeft )
// 		{
// 			return
// 		}

// 		$hasActionsLeft = EarnestPayment
// 		if( !$hasActionsLeft )
// 		{
// 			return
// 		}

// 		$hasActionsLeft = CheckMenaces
// 		if( !$hasActionsLeft )
// 		{
// 			return
// 		}

// 		$hasActionsLeft = HandleRenown
// 		if( !$hasActionsLeft )
// 		{
// 			return
// 		}

// 		$hasActionsLeft = TryOpportunity
// 		if( !$hasActionsLeft )
// 		{
// 			return
// 		}

// 		$actionsOrder = CycleArray $actions $startIndex
// 		ForEach( $action in $actionsOrder )
// 		{
// 			$hasActionsLeft = DoAction $action
// 			write-host "has actions left: $hasactionsleft"
// 			if( !$hasActionsLeft )
// 			{
// 				return
// 			}
		}


	}


}