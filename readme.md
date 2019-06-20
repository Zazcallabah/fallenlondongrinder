# FallenLondon Grinder

Azure function set up to run every 10 minutes. Will cycle through a given set of storylets and choices in fallen london, as long as there are actions to spare.

## how

An `action` is a sequence of navigational clicks in fallen london. They are simple strings, divided into different parts by commas.

`run.ps1` contains a list of actions. Each time the script runs, one of those actions are performed. Which action is chosen based on the date. Each day that passes progresses one step further in the list of actions. When the list is done, it restarts from the beginning.

### types of actions

#### normal, boring action

The string is divided into location, name of storylet, then an optional number of branch navigations, then at the end a choice.

The location is the area you wish to move to. The full name of an area will always work as long as you know the route. Some care has been taken to accept shorthand names, look for `$script:locations` in `apicalls.ps1`. If location is carnival then tickets will be automatically acquired. If location is shuttered palace, an action will be spent to gain access. Other locations may have other custom handling applied.

Storylet and branch name lookup is done using the `-match` operator. You can also supply an index number (starting at 1), or a question mark for a random selection. Multiple options can be given, separated by forward-slashes. In that case they will be tried one after another, left-to-right, until one works.

#### require

Most of the time you don't want to do a specific action, rather you want to gain and grind inventory items and stats. Fortunately we have the aquisitions engine to take care of more complicated actions. In it you can specify that an action has prerequisite inventory or stats, and in turn give instructions on how to fulfill those before proceeding. The prerequisites can in turn have their own prerequisites and so on.

For legacy reasons, the `require` action is reserved for internal use, since it doesn't define what to do in case the requirement is fullfilled.

In the actions list, it is instead suggested that you use the almost identical action `cascade`.

#### cascade

Cascade is like require, except when the requirement is fullfilled, the script will just try the next action in the action list.

The format is `cascade,<possession category>,<possession name>,<amount>[,<named action>]`. Remember that even stats are possessions in this game, so you could for example require "Accomplishments,A Person of Some Importance,1" if you need PoSI for something.

The named action is optional, but helpful if you need to specify exactly which acquisition to use to grind something. There may, for example, be different actions to raise and lower specific qualities. If no action is named, the acquisitions engine will make a best effort to find the shortest grind to your requested items, based on your existing inventory.

The amount when given as a regular number will grind until that number or greater is reached. You can also prefix the amount with an equals sign, in which case the grind will continue until the exact value is reached - very useful for story requirements but fragile if you do not also give a named action. Example `cascade,Circumstance,An Expedition,=11,Silk adventure` will only progress when your chosen expedition is 11, which is the value for Tomb of the Silken Thread. The acquisition "Silk adventure" tries to select that adventure, but has its own prerequisites that quits existing expeditions and makes sure you're stocked up on supply.

If you prefix a less-than sign to the amount, the grind will continue as long as the amount is less than the given limit. A "cascade,Menaces,Nightmares,<5" action will keep grinding until your nightmares are 4 or lower.

#### others

`buy`, `sell`, `grind_money`, `inventory`. Self explanatory, or check the details in the code.

## code overview

![](overview.png)


## todo

* Add handling of more interesting locked locations like boat stuff or prison or death etc.
* opportunity cards during heist or other locked storylets
* find your way into more locations. like a newspaper or a boat or something.
* finish flit heists grind, and handle that locked area

* Velocipede squad stuff
* mahogani Master-Classes in Etiquette loop
* affair of the box grind loop, after mahogany hall done to sunday)
* flit chicanery progression
* stealing painting for flit king
* grind for favors?

* is it viable to lower suspicion through # "ladybones,life,associate,publish" # prereq 50 Silk Scrap 25 clues Subtle 4
* Add opportunity cards for favours etc?
* how to get rubbery?

* four different making your name stories
* newspaper progress https://fallenlondon.fandom.com/wiki/An_Editor_of_Newspapers
* add acq for favour in high places, comprehensive bribe, personal reccommendation
* https://fallenlondon.fandom.com/wiki/Attending_a_Party_(Guide)
* bizarre, dreaded, ?

* ambition, hearts desire, go to ... hunters keep? by boat, get stone key


A Name in Seven Secret Alphabets
-> progress in the university

A Name Scrawled in Blood
-> fix a hunt is on, starts in wolfstack https://fallenlondon.fandom.com/wiki/The_Hunt_is_On!_(Guide)

A Name Signed with a Flourish https://fallenlondon.fandom.com/wiki/Shaping_a_Masterpiece_for_the_Empress
-> empress court make  Inspired... 24, Working on... an Opera, Carving out a Reputation at Court exactly 6

A Name Whispered in Darkness
-> something about bats and cats in flit, embroiled in wars of illusion
