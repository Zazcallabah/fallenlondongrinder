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
			Log.Error("What if we log error, will it show up in the graph?");
			Log._logObject = log;

			var e = Environment.GetEnvironmentVariable("LOGIN_EMAIL", EnvironmentVariableTarget.Process);
			var p = Environment.GetEnvironmentVariable("LOGIN_PASS", EnvironmentVariableTarget.Process);

			var h = new Main(e, p);
			try
			{
				Log.Info("Main account");
				await h.RunMain();
			}
			catch (Exception ex)
			{
				Log.Error(ex.Message);
			}

			var ae = Environment.GetEnvironmentVariable("SECOND_EMAIL", EnvironmentVariableTarget.Process);
			var ap = Environment.GetEnvironmentVariable("SECOND_PASS", EnvironmentVariableTarget.Process);

			if (ae != null && ap != null)
			{
				try
				{
					Log.Info($"Current automaton: {ae}");
					var ah = new Main(ae, ap);
					await ah.RunAutomaton();
				}
				catch (Exception ex)
				{
					Log.Error(ex.Message);
				}
			}
		}

		Handler _handler;

		public Main(string email, string password)
		{
			// if( string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password) )
			// 	throw new Exception("missing login information");
			Session session = new Session(email, password);
			GameState state = new GameState(session);
			AcquisitionEngine engine = new AcquisitionEngine(state);

			_handler = new Handler(session, state, engine);
		}

		public async Task RunMain(bool force = false)
		{
			await _handler.RunActions(ActionHandler.Main(), force);
		}

		public async Task RunAutomaton(bool force = false)
		{
			await _handler.RunActions(ActionHandler.Automaton(), force);
		}
	}

}