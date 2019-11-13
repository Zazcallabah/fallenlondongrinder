using NUnit.Framework;
using System.Threading.Tasks;
namespace test
{
    public class Tests
    {
        [SetUp]
        public void Setup()
        {
        }

        [Test]
        public async Task CanGetMapCache()
        {
			var s = new fl.Session("automaton@prefect.se","aoeu1234");
			var l = await s.GetMap();
            Assert.IsNotNull(l);
        }
    }
}