using Microsoft.Extensions.Logging;

namespace fl
{
	public static class Log
	{
		public static ILogger _logObject;
		public static void Info(string message)
		{
			if( _logObject != null)
				_logObject.LogInformation(message);
		}
		public static void Warning(string message)
		{
			if( _logObject != null)
			_logObject.LogWarning(message);
		}
		public static void Error(string message)
		{
			if( _logObject != null)
			_logObject.LogError(message);
		}
	}
}