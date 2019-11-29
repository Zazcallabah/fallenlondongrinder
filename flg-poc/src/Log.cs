using Microsoft.Extensions.Logging;

namespace fl
{
		public static class Log {
		public static ILogger _logObject;
		public static void Info(string message) {
			_logObject.LogInformation(message);
		}
		public static void Warning(string message) {
			_logObject.LogWarning(message);
		}
		public static void Error(string message) {
			_logObject.LogError(message);
		}
	}
}