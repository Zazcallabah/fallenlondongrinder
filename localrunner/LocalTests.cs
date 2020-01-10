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
			await Do((string)credentials.auto[0],(string)credentials.auto[1]);
		}
		[Test]
		public async Task RunAuto2()
		{
			dynamic credentials = JsonConvert.DeserializeObject(System.IO.File.ReadAllText("secrets.json"));
			await Do((string)credentials.auto2[0],(string)credentials.auto2[1]);
		}
		[Test]
		public async Task RunAuto3()
		{
			dynamic credentials = JsonConvert.DeserializeObject(System.IO.File.ReadAllText("secrets.json"));
			await Do((string)credentials.auto3[0],(string)credentials.auto3[1]);
		}
	[Test]
		public async Task RunAuto4()
		{
			dynamic credentials = JsonConvert.DeserializeObject(System.IO.File.ReadAllText("secrets.json"));
			await Do((string)credentials.auto4[0],(string)credentials.auto4[1]);
		}
		public async Task Do(string e, string p){
			if( e == null || p == null )
				throw new Exception("missing login");
			var n = new Main(e,p);
			await n.RunAutomaton(true);
			Assert.Fail("Fail test to see output");

		}
	}
}