using System.Threading.Tasks;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;

namespace fl
{

	public class Main
	{
		public static async Task Run(TimerInfo timer, ILogger log)
		{
			Log._logObject = log;

			var e = Environment.GetEnvironmentVariable("LoginEmail", EnvironmentVariableTarget.Process);
			var p = Environment.GetEnvironmentVariable("LoginPass", EnvironmentVariableTarget.Process);

			var h = new Handler2(e, p);
			await h.RunMain();
		}

		public class Handler2
		{
			Handler _handler;

			public Handler2(string email, string password)
			{
				// if( string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password) )
				// 	throw new Exception("missing login information");
				Session session = new Session(email, password);
				GameState state = new GameState(session);
				AcquisitionEngine engine = new AcquisitionEngine(session, state);

				_handler = new Handler(session, state, engine);
			}

			public async Task RunMain()
			{
				await _handler.RunActions(ActionHandler.Main());
			}
		}
	}
}