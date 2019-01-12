# FallenLondon Grinder

Azure function set up to run every 10 minutes. Will cycle through a given set of storylets and choices in fallen london, as long as there are actions to spare.


## todo

* fulfill money grinding loop, add intro and exit actions
* grind menaces - suspicion primarily - in their locked locations
* how to bulk lower menaces
* is it viable to lower suspicion through # "ladybones,life,associate,publish" # prereq 50 Silk Scrap 25 clues Subtle 4
* how to avoid recursion loop for carnival tickets
* opportunity cards during heist or other locked storylets

### data on workingon/writing

dont 'require' a circumstance without a named tag
do special handling for circumstance, ignoring it if already "wrong" value?


* finishing a short story at "lodgings,writer,finish,[name]
* leveling progress to 60 is already established, but further:
* 70 compromising document, darkness (tale of terror)
* 80 life-lessons ( hard earned lesson)
* 100 esoteric elements (extraordinary implication)


* empresscourt,complete,
* gothic romance - 6000 moon pearls, fascinating, making waves
* tale of the future - connected benthic, connected summerset,making waves, 6000 brass silver
* patriotic adventure - 6000 moon perals, making waves
* use fascinating to do romance options in empresscourt, which requires fascinating 11? 10?


	function WorkingOn {
		# workingon 31
		# action to start
		# require potential 60
		# action to finish
		# competent or compelling results
		# sell result no matter which
	}

"Penny" = @("Curiosity,Competent Short Story,1"); # workking on not null, writing doesnt currently end? push for which level?

maybe a flag for prerequisites that marks or/and?
sell & inventory should take arbitrary number of items, and try them in order until one is found in inventory

set up the upconvert routes and such
go through areas, enter good actions to take for generic items
start including amount of item/action
	we could automate that through the tree cascade if it has a separate property