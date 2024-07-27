# halfhazard
## on names
i suck at names. halfhazard is an inside joke with me and Laura because I thought haphazard was pronounced with a 'fff' sound, since p and h together often do!

Also its funny to think of your finances as haphazard.

## to do
1. [X] Make a User() a required object on an expense
    - this means i need to figure out how to instantiate a user, i guess?
    - is this even possible, or do I just, imply this somehow?
2. [X] Fix account management .sheet initial size
3. [X] Change all .sheet view modifications to Papa's, better, view size settings
4. [X] Start using `query` more - that's the right way to reference anything in the db
    - i think current user can and maybe even should be in appstorage, but everything else we should be persisting to db
5. [X] Specifically, use a `Query` to make it so the only expenses you see by default have your name on them
6. [X] Create "Manage Groups View" and an add group button
    - also add a thing to show the group per expense, maybe?
    - maybe just make groups a required thing?

- [X] Computed property on expense that auto splits based on group memberhsip count

- [X] move every swiftdata thing to cloudkit
- [X] move all buttons to a ctrl click menu to clean up UI
- [X] Add a navigation menu for each  group?
- [X] fix some of the UI in iOS
    - [X] Certain user input bars have a gray box over them, which don't allow users to add input
    - [X] The UI in general is Too Large, and should be shrunk a bit.
    - [X] I should use a different input mechanism than labelled buttons on IOS. Maybe swipe to reveal?
        - ended up with context menu stuff. i think i still want diff behaviors on macos vs ios but, for now i'm good.
- [X] get rid of sheets.
    - might mean moving to a NavPath based navigation system, which I think requires a navstack at your root view, rather than the splitview i've just set up
- [X] add fields to configure username in login screen
    - use that instead of userID in ExpenseView
    - Figure out how to actually sync this data between devices, its being dumb.
- [X] Figure out why I can't tint some of my buttons appropriately:
    - See the createCategory view
    - Seems to be platform differences - works every time on iOS, can't make it work on macOS mostly. Moving on.
- [ ] Implement an alternative to my old "need to apply defaults" thing; papa had something that seemed good?
- [X] I think many of my base views are fucked up - review them, especially after we get rid of sheets
- [X] Add details to group view:
    - "you owe: total"
    - "Mark all as paid"
- [X] Fix Nav Menu confusion. Works on macOS but not on iOS and I have no idea why
    - also, how do i do things like, arch specific views? the #if os macro doesn't really seem to work with Views and multi-line configuration
- [ ] Add configurable split % at the expense level
    - not sure how to do this. maybe best done as an optional property that stores a dict or something?
- [ ] Add import/export capability. 
    - i don't know that i care in general about either csv or json
    - csv is most common in finance apps though, so worth considering
    - maybe just do both?
    - this might be my last breaking feature before I start using this myself.
- [ ] Groups should have public / private settings
    - hard to reason about until i get a better understanding of how multi user works right now
- [ ] build out some reporting functionality; pie charts?
- [ ] make groups view sorted, sortable.
