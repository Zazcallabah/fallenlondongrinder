using Newtonsoft.Json;
using NUnit.Framework;
using System.Linq;
using System;
using System.Threading.Tasks;
using fl;

namespace test
{
	public class AcqTests
	{
		[Test]
		public void TestLoadAcqs()
		{
			var e = new AcquisitionEngine();
			e.MergeFolder("acquisitions");

			Assert.IsNotEmpty( e.Acquisitions );
		}

		[Test]
		public void TestLoadItems()
		{

			var l = AcquisitionEngine.load();
			var s = new []{"Economy","Level","Item","Cost","Action","Gain","BoughtItem"};
			Assert.AreEqual(s,l[0]);

		}

	}

}