using Newtonsoft.Json;

namespace fl
{
	// bool?
	// true -> has remaining actions, this prereq is fulfilled, keep doing this chain of actions
	// false -> we have consumed our action for this run, stop
	// null -> this chain of actions has failed in some fashion. abort and start working on the next chain
	// mismatch ->
	// specific case where you have multiple paths to a prereq
	// like if you need foxfire candles, you can buy them in bulk, but if you are posi, you should do the unfinished business storylet
	// so there is a prereq for the unfinishedbuisiness acquisition that is tagged with a different acq that buys the candles
	// but if that prereq returns true (because buying doesnt consume an action) the engine will assume you actually have posi,
	// and proceed doing an invalid action
	// {
	// 	"Name": "Foxfire Candle Stub",
	// 	"Result": "Foxfire Candle Stub",
	// 	"Prerequisites": [
	// 		"Accomplishments,A Person of Some Importance,1,BuyCandles"
	// 	],
	// 	"Action": "veilgarden,unfinished business,An admirer among the clergy"
	// },
	// {
	// 	"Name": "BuyCandles",
	// 	"Result": "Foxfire Candle Stub",
	// 	"Prerequisites": [
	// 		"Currency,Penny,6000,SellHints"
	// 	],
	// 	"Action": "buy,Merrigans,Foxfire Candle Stub,2000"
	// }
	// to prevent this, "mismatch" means this requirement has already been acquired through alternate means
	// NOTE maybe you actually bought the stuff you needed for this requirement though? how to distinguish this??

	//

	public enum HasActionsLeft
	{
		Available,
		Consumed,
		Faulty,
		Mismatch,
	}

	public class Acquisition
	{
		public string Name;
		public string Result;
		public string[] Prerequisites;
		public string Action;
		public int? Reward;
		public CardAction[] Cards;
	}
	public class ActionList
	{
		public string[] automaton;
		public string[] main;
	}
	public class BasicMessage
	{
		public string type;
		public string message;
		public string image;
		public string tooltip;
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
	public class Card
	{
		public string name;
		public long eventId;
		public string category;
		public string unlockedWithDescription;
		public string teaser;
		public bool isAutofire;
		public string stickiness;
		public QualityReq[] qualityRequirements;
	}
	public class CardAction
	{
		public string name;
		public string[] require;
		public string action;
		public long? eventId;
	}
	public class Challenge
	{
		public string name;
		public long id;
		public int targetNumber;
		public string description;
		public string category;
		public string nature;
		public string type;
		public bool canAffordSecondChance;
		public string image;
		public int secondChanceId;
		public int secondChanceLevel;
	}
	public class Character
	{
		public string name;
		public string description;
		public string descriptiveText;
		public Domicile currentDomicile;
		public Outfit[] outfits;
		public int actions;
		public bool journalIsPrivate;
		public UserData user;
		public int id;
	}
	public class Content
	{
		public string type;
		public string image;
		public long relatedId;
		public string description;
		public string date;
		public string ago;
	}
	public class ContentMessage
	{
		public int actions;
		public Content content;
		public string message;
		public bool isSuccess;
	}
	public class Domicile
	{
		public string name;
		public string description;
		public int maxHandSize;
	}
	public class EndStorylet
	{
		public int rootEventId;
		public int currentActionsRemaining;
		[JsonProperty(PropertyName = "event")]
		public Event eventValue;
		public bool isLinkingEvent;
		public bool isDirectLinkingEvent;
		public int maxActionsAllowed;
		public bool premiumBenefitsApply;
		public string image;
		public bool canGoAgain;
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
	public class Exchange
	{
		public string name;
		public string title;
		public string description;
		public Shop[] shops;
		public string image;
		public int id;
	}
	public class ExchangeResponse
	{
		public Exchange exchange;
		public bool isSuccess;
	}
	public class ForcedAction
	{
		public string[] Conditions;
		public string Action;
	}
	public class Friend
	{
		public long userId;
		public long id;
		public string name;
		public string userName;
	}
	public class Interaction
	{
		public string type;
		public string image;
		public long relatedId;
		public string description;
		public string date;
		public string ago;
	}
	public class InviteeData
	{
		public long branchId;
		public string actQReqText;
		public string actInviterQReqText;
		public int addedFriendId;
		public Friend[] eligibleFriends;
	}
	public class LockedAreaData
	{
		public string name;
		public string[] require;
		public bool? forced;
		public string action;
	}
	public class Map
	{
		public MapEntry[] areas;
	}
	public class MapEntry
	{
		public string name;
		public string description;
		public bool showOps;
		public bool hideName;
		public bool premiumSubRequired;
		public int id;
	}
	public class Messages
	{
		public BasicMessage[] difficultyMessages;
		public BasicMessage[] defaultMessages;
		public StandardMessage[] standardMessages;
	}
	public class Move
	{
		public UserArea area;
		public bool isSuccess;
	}
	public class Myself
	{
		public Character character;
		public PossessionCategory[] possessions;
	}
	public class Opportunity
	{
		public Card[] displayCards;
		public bool isInAStorylet;
		public int eligibleForCardsCount;
		public int maxHandSize;
		public int maxDeckSize;
	}
	public class Outfit
	{
		public string name;
		public bool selected;
		public long id;
	}
	public class OutfitSlot
	{
		public string name;
		public long? qualityId;
	}
	public class Plan
	{
		public PlanBranch branch;
		public string areaName;
		public long id;
	}
	public class PlanBranch
	{
		public QualityReq[] qualityRequirements;
		public int id;
		public string planKey;
		public string name;
		public string description;
		public int currencyCost;
		public int actionCost;
		public string buttonText;
		public string image;
		public bool isLocked;
		public int ordering;
		public bool actionLocked;
		public bool currencyLocked;
		public bool qualityLocked;
		public Challenge[] challenges;
	}
	public class PlanQuery
	{
		public string name;
		public string planKey;
		public int? id;
	}
	public class PlanResult
	{
		public Plan plan;
		public string message;
		public bool isSuccess;
	}
	public class Plans
	{
		public Plan[] active;
		public Plan[] complete;
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
		public long id;
		public long? useEventId;
	}
	public class PossessionCategory
	{
		public string[] categories;
		public string name;
		public Possession[] possessions;
		public string appearance;
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
	public class Shop
	{
		public string name;
		public string image;
		public string description;
		public int ordering;
		public int id;
	}
	public class ShopAvailability
	{
		public ShopItemQuality quality;
		public int cost;
		public int sellPrice;
		public long id;
	}
	public class ShopItem
	{
		public ShopAvailability availability;
		public bool forSale;
	}
	public class ShopItemQuality
	{
		public long id;
		public string name;
		public string description;
		public long useEventId;
		public string category;
		public string image;
	}
	public class SocialAct
	{
		public InviteeData inviteeData;
		public Branch branch;
		public bool uniqueActPending;
		public string actMessagePreview;
		public string urgency;
		public bool isSocialEvent;
	}
	public class StandardMessage
	{
		public Possession possession;
		public string category;
		public string nature;
		public string qualityName;
		public int qualityId;
		public int levelBefore;
		public string xpBefore;
		public int levelAfter;
		public string xpAfter;
		public bool usesProgressBars;
		public int leftScore;
		public int rightScore;
		public string startPercentage;
		public string endPercentage;
		public string changeType;
		public bool isSidebar;
		public string type;
		public string message;
		public string image;
		public string tooltip;
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
	public class StoryletList
	{
		public int actions;
		public string phase;
		public Storylet[] storylets;
		public Storylet storylet;
		public EndStorylet endStorylet;
		public SocialAct socialAct;
		public Messages messages;
		public bool isSuccess;
	}
	public class SuccessMessage
	{
		public bool? isSuccess;
		public string message;
	}
	public class SuccessResult
	{
		public bool isSuccess;
	}
	public class TransactionResult
	{
		public Possession[] possessionsChanged;
		public string message;
		public bool isSuccess;
	}
	public class User
	{
		public UserArea area;
		public UserSetting setting;
		public bool hasCharacter;
		public string privilegeLevel;
		public UserData user;
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
	public class UserData
	{
		public string name;
		public string emailAddress;
		public int nex;
		public int id;
	}
	public class UserSetting
	{
		public string name;
		public bool canTravel;
		public int id;
		public bool itemsUsableHere;
	}

}