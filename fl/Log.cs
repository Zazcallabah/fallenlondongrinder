using Microsoft.Extensions.Logging;

namespace fl
{
	public static class Log
	{
		public static ILogger _logObject;

		public static void Debug(string message)
		{
			if( _logObject == null )
				System.Console.WriteLine($"DEBUG: {System.DateTime.Now.ToString("HH:mm:ss.fffff")} {message}");
		}

		public static void Info(string message)
		{
			if (_logObject != null)
				_logObject.LogInformation(message);
			else
				System.Console.WriteLine($"INFO: {System.DateTime.Now.ToString("HH:mm:ss.fffff")} {message}");
		}
		public static void Warning(string message)
		{
			if (_logObject != null)
				_logObject.LogWarning(message);
			else
				System.Console.WriteLine($"WARN: {System.DateTime.Now.ToString("HH:mm:ss.fffff")} {message}");
		}
		public static void Error(string message)
		{
			if (_logObject != null)
				_logObject.LogError(message);
			else
				System.Console.WriteLine($"ERR: {System.DateTime.Now.ToString("HH:mm:ss.fffff")} {message}");
		}
	}
}