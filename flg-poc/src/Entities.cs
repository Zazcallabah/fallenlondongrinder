namespace fl
{

	public class MapEntry
	{
		public string name;
		public string description;
		public bool showOps;
		public bool hideName;
		public bool premiumSubRequired;
		public int id;
	}

	public class Map
	{
		public MapEntry[] areas;
	}


	public class UserSetting
	{
		public string name;
		public bool canTravel;

		public int id;

		public bool itemsUsableHere;
	}

	public class UserArea
	{
		public int id;
		public string name;
		public string description;
		public string image;
		public bool hideName;
		public bool showOps;
		public bool premiumSubRequired;
	}

	public class User
	{
		public UserArea area;
		public UserSetting setting;
		public bool hasCharacter;
		public string privilegeLevel;
		public UserData user;

	}

	public class ShopItem
	{
		public ShopAvailability availability;
	}

	public class ShopAvailability
	{
		public ShopItemQuality quality;
		public string id;
	}

	public class ShopItemQuality
	{
		public int id;
		public string name;
	}

	public class SuccessResult
	{
		public bool isSuccess;
	}

	public class Plans
	{
		public Plan[] active;
		public Plan[] complete;
	}

	public class Plan
	{
		public PlanBranch branch;
	}

	public class PlanBranch
	{
		public QualityReq[] qualityRequirements;
		public int id;
		public string planKey;
		public string name;
	}

	public class QualityReq
	{
		public long qualityId;
		public long id;
		public string qualityName;
		public string tooltip;
		public string category;
		public string nature;
		public string status;
		public bool isCost;
		public string image;
		public string availableAtMessage;
	}

	public class Storylet
	{
		public string name;
		public string teaser;
		public string category;
		public QualityReq[] qualityRequirements;
		public string image;
		public long id;

		public bool? isLocked;

		public string frequency;
		public string distribution;
		public string description;
		public string urgency;
		public bool isInEventUseTree;
		public bool? canGoBack;

		public Branch[] childBranches;
	}

	public class Branch
	{
		public string name;
		public string description;
		public string planKey;
		public int currencyCost;
		public int actionCost;
		public string buttonText;
		public Challenge[] challenges;
		public QualityReq[] qualityRequirements;
		public bool actionLocked;
		public bool currencyLocked;
		public bool qualityLocked;
		public int ordering;
		public bool isLocked;
		public string image;
		public long id;
	}

	public class Challenge
	{
		public string name;
		public int targetNumber;
		public string description;
		public string category;
		public string nature;
		public string type;
		public bool canAffordSecondChance;
		public int secondChanceId;
		public int secondChanceLevel;
		public string image;
		public long id;
	}

	public class StoryletList
	{
		public int actions;
		public string phase;
		public Storylet[] storylets;
		public Storylet storylet;
		public bool isSuccess;
	}

	public class Myself
	{
		public Character character;
		public PossessionCategory[] possessions;
	}

	public class Domicile
	{
		public string name;
		public string description;
		public int maxHandSize;
	}

	public class Character
	{
		public string name;
		public string description;
		public string descriptiveText;
		public Domicile currentDomicile;
		public int actions;
		public bool journalIsPrivate;
		public int id;
	}

	public class UserData
	{
		public string name;
		public string emailAddress;
		public int nex;
		public int id;
	}

	public class Move
	{
		public UserArea area;
		public bool isSuccess;
	}

	public class PossessionCategory
	{
		public string[] categories;
		public string name;
		public Possession[] possessions;
		public string appearance;
	}

	public class Opportunity
	{
		public Card[] displayCards;
		public bool isInAStorylet;
	}

	public class Card
	{
		public string name;
		public int eventId;
	}

	public class BranchChoice
	{
		public int actions;
		public string phase;
		public bool isSuccess;

		public EndStorylet endStorylet;
		public Messages messages;

	}

	public class BasicMessage
	{
		public string type;
		public string message;
		public string image;
		public string tooltip;
	}

	public class StandardMessage
	{
		public Possession possession;
		public string category;
		public string nature;
		public string qualityName;
		public int qualityId;
		public int levelBefore;
		public int xpBefore;
		public int levelAfter;
		public int xpAfter;
		public bool usesProgressBars;
		public int leftScore;
		public int rightScore;
		public int startPercentage;
		public int endPercentage;
		public string changeType;
		public bool isSidebar;
		public string type;
		public string message;
		public string image;
		public string tooltip;
	}
	public class Messages
	{

		public BasicMessage[] difficultyMessages;
		public BasicMessage[] defaultMessages;
		public StandardMessage[] standardMessages;
	}

	public class Event
	{
		public string name;
		public string description;
		public bool isInEventUseTree;
		public string frequency;
		public string image;
		public long id;
	}
	public class EndStorylet
	{
		public int rootEventId;
		public int currentActionsRemaining;
		//	public Event event;
		public bool isLinkingEvent;
		public bool isDirectLinkingEvent;
		public int maxActionsAllowed;
		public bool premiumBenefitsApply;
		public string image;
		public bool canGoAgain;
	}

	public class Possession
	{
		public long qualityPossessedId;
		public string name;
		public string nameAndLevel;
		public string description;
		public string nature;
		public string category;
		public int effectiveLevel;
		public int level;
		public int himbleLevel;
		public string availableAt;
		public bool equippable;
		public string bonusOrPenaltyDisplay;
		public int progressAsPercentage;
		public string image;
		public int id;
	}

}