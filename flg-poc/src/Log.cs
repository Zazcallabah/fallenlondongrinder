using Microsoft.Extensions.Logging;

namespace fl
{
	public static class Log
	{
		public static ILogger _logObject;

		public static void Debug(string message)
		{
			if( _logObject == null )
				System.Console.WriteLine(message);
		}

		public static void Info(string message)
		{
			if (_logObject != null)
				_logObject.LogInformation(message);
			else
				System.Console.WriteLine($"INFO: {message}");
		}
		public static void Warning(string message)
		{
			if (_logObject != null)
				_logObject.LogWarning(message);
			else
				System.Console.WriteLine($"WARN: {message}");
		}
		public static void Error(string message)
		{
			if (_logObject != null)
				_logObject.LogError(message);
			else
				System.Console.WriteLine($"ERR: {message}");
		}
	}
}