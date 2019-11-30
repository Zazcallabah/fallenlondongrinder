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
		public void TestLoadItems()
		{

			var c = new CardAction{action="aoeu",name="aoeu"};

			foreach( var r in c.require )
			{

			Assert.AreEqual("aoeu",r);
			}



		}

	}

}