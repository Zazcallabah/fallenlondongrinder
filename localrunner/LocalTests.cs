using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace localrunnertest
{
	public class LocalTests
	{
		[Test]
		public async Task RunMain()
		{
			dynamic credentials = JsonConvert.DeserializeObject(System.IO.File.ReadAllText("secrets.json"));
			string e = credentials.main[0];
			string p = credentials.main[1];

			if( e == null || p == null )
				throw new Exception("missing login");

			var n = new Main(e,p);
			await n.RunMain(true);
			Assert.Fail("Fail test to see output");
		}
		[Test]
		public async Task RunAuto()
		{
			dynamic credentials = JsonConvert.DeserializeObject(System.IO.File.ReadAllText("secrets.json"));
			string e = credentials.auto[0];
			string p = credentials.auto[1];

			if( e == null || p == null )
				throw new Exception("missing login");
			var n = new Main(e,p);
			await n.RunAutomaton(true);
		}
	}
}