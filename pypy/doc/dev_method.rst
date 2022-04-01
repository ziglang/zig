Distributed and agile development in PyPy
=========================================

.. note::
  This page describes the mode of development that preceeds the current models
  of Open Source development. While people are welcome to join our (now yearly)
  sprints, we encourage engagement via the gitlab repo at
  https://foss.heptapod.net/pypy/pypy. Issues can be filed and discussed in the
  `issue tracker`_ and we welcome `merge requests`_.

.. _`issue tracker`: https://foss.heptapod.net/heptapod/foss.heptapod.net/-/issues
.. _`merge requests`: https://foss.heptapod.net/heptapod/foss.heptapod.net/-/merge_requests

PyPy isn't just about producing code - it's also about how we produce code.
The challenges of coordinating work within a community and making sure it is
fused together with the parts of the project that is EU funded are tricky
indeed. Our aim is of course to make sure that the communities way of working
is disturbed as little as possible and that contributing to PyPy still feels
fun and interesting (;-) but also to try to show to the EU as well as other
funded projects that open source ideas, tools and methods are really good ways
of running development projects. So the way PyPy as a project is being run -
distributed and agile - is something we think might be of use to other open
source development projects and commercial projects.

Main methods for achieving this is:

  * Sprint driven development
  * Sync meetings

Main tools for achieving this is:

  * py.test - automated testing
  * Mercurial - version control
  * Transparent communication and documentation (mailinglists, IRC, tutorials
    etc etc)


Sprint driven development:
--------------------------

What is a sprint and why are we sprinting?

Originally the sprint methodology used in the Python community grew from
practices within Zope3 development. The  definition of a sprint is "two-day or
three-day focused development session, in which developers pair off together
in a room and focus on building a particular subsystem".

Other typical sprint factors:

  * no more than 10 people (although other projects as well as PyPy haven been
    noted to have more than that. This is the recommendation and it is
    probably based on the idea of having a critical mass of people who can
    interact/communicate and work without adding the need for more than just
    the absolute necessary coordination time. The sprints during 2005 and 2006 have
    been having ca 13-14 people per sprint, the highest number of participants
    during a PyPy sprint has been 24 developers)

  * a coach (the coach is the "manager" of the sprint, he/she sets the goals,
    prepares, leads and coordinate the work and track progress and makes this
    visible for the team. Important to note here - PyPy have never had coaches
    in our sprints. Instead we hold short status meetings in the whole group,
    decisions are made in the same way. So far this have worked well and we
    still have been able to achieve tremendous results under stressed
    conditions, releases and such like. What we do have is a local organizer,
    often a developer living in the area and one more developer who prepares
    and organizes sprint. They do not "manage" the sprint when its started -
    their role is more of the logistic nature. This doesn't mean that we wont
    have use for the coach technique or something similar in the future).

  * only coding (this is a tough one. There have been projects who have used
    the sprinting method to just visionalize och gather input. PyPy have had a
    similar brainstorming start up sprint. So far though this is the official
    line although again, if you visit a PyPy sprint we are doing quite a lot
    of other small activities in subgroups as well - planning sprints,
    documentation, coordinating our EU deliverables and evaluation etc. But
    don't worry - our main focus is programming ;-)

  * using XP techniques (mainly pairprogramming and unit testing - PyPy is
    leaning heavily on these aspects). Pairing up core developers with people
    with different levels of knowledge of the codebase have had the results
    that people can quite quickly get started and join in the development.
    Many of our participants (new to the project and the codebase) have
    expressed how pairprogramming in combination with working on the automated
    tests have been a great way of getting started. This is of course also a
    dilemma because our core developers might have to pair up to solve some
    extra hairy problems which affects the structure and effect of the other
    pairs.

It is a method that fits distributed teams well because it gets the team
focused around clear (and challenging) goals while working collaborative
(pairprogramming, status meeting, discussions etc) as well as accelerated
(short increments and tasks, "doing" and testing instead of long start ups of
planning and requirement gathering). This means that most of the time a sprint
is a great way of getting results, but also to get new people acquainted with
the codebase. It is also a great method for dissemination and learning within
the team because of the pairprogramming.

If sprinting is combined with actually moving around and having the sprint
close to the different active developer groups in the community as well as
during conferences like PyCon and EuroPython, the team will have an easier
task of recruiting new talents to the team. It also vitalizes the community
and increases the contact between the different Python implementation
projects.

As always with methodologies you have to adapt them to fit your project (and
not the other way around which is much too common). The PyPy team have been
sprinting since early 2003 and have done 22  sprints so far, 19 in Europe, 2
in the USA and 1 in Asia. Certain practices have proven to be more successful within this
team and those are the one we are summarizing here.


How is it done?
~~~~~~~~~~~~~~~

There are several aspects of a sprint. In the PyPy team we focus on:
1. Content (goal)
2. Venue
3. Information
4. Process

1. Content (goal) is discussed on mailinglists (pypy-dev) and on IRC ca one
   month before the event. Beforehand we have some rough plans called "between
   sprints" and the sprintplan is based on the status of those issues but also
   with a focus on upcoming releases and deliverables. Usually its the core
   developers who does this but the transparency and participation have
   increased since we started with our weekly "pypy-sync meetings" on IRC. The
   sync meetings in combination with a rough in between planning makes it
   easier for other developer to follow the progress and thus participating in
   setting goals for the upcoming sprints.

   The goal needs to be challenging or it won't rally the full effort of the
   team, but it must not be unrealistic as that tends to be very frustrating
   and dissatisfying. It is also very important to take into account the
   participants when you set the goal for the sprint. If the sprint takes place
   connected to a conference (or similar open events) the goals for the actual
   coding progress should be set lower (or handled in another way) and focus
   should shift to dissemination and getting new/interested people to a
   certain understanding of the PyPy codebase. Setting the right goal and
   making sure this is a shared one is important because it helps the
   participants coming in with somewhat similar expectations ;-)

2. Venue - in the PyPy project we have a rough view on where we are sprinting
   a few months ahead. No detailed plans have been made that far in
   advance. Knowing the dates and the venue makes flight bookings easier ;-)
   The venue is much more important than one would think. We need to have a
   somewhat comfortable environment to work in (where up to 15 people can sit
   and work), this means tables and chairs, light and electricity outlets. Is
   it a venue needing access cards so that only one person is allowed to open?
   How long can you stay - 24 hours per day or does the landlord want the team
   evacuated by 23:00? These are important questions that can gravely affect
   the "feel and atmosphere" of the sprint as well as the desired results!

   Also, somewhat close to low cost places to eat and accommodate
   participants. Facilities for making tea/coffee as well as some kind of
   refrigerator for storing food. A permanent Internet connection is a must -
   has the venue were the sprint is planned to be weird rules for access to
   their network etc etc?

   Whiteboards are useful tools and good to have. Beamers (PyPy jargon for a projector)
   are very useful for the status meetings and should be available, at least 1. The
   project also owns one beamer - specifically for sprint purposes.

   The person making sure that the requirements for a good sprint venue is
   being met should therefore have very good local connections or, preferably
   live there.

3. Information - discussions about content and goals (pre announcements) are
   usually carried out on pypy-dev (mailinglist/IRC). All other info is
   distributed via email on pypy-sprint mailinglist and as web pages on
   codespeak. When dates, venue and content is fully decided a sprint
   announcement is being made and sent out to pypy-dev and pypy-sprint as well
   as more general purpose mailing lists like comp.lang.python and updated on
   codespeak - this happens 2-4 weeks before the sprint. It's important that
   the sprint announcements points to information about local transportation
   (to the country and to the city and to the venue), currency issues, food
   and restaurants etc. There are also webpages in which people announce when
   they will arrive and where they are accommodated.

   The planning text for the sprint is updated up till the sprint and is then
   used during the status meetings and between to track work. After the sprint
   (or even better: in between so that the memory is fresh) a sprint report is
   written by one of the developers and updated to codespeak, this is a kind
   of summary of the entire sprint and it tells of the work done and the
   people involved.

   One very important strategy when planning the venue is cost
   efficiency. Keeping accommodation and food/travel costs as low as possible
   makes sure that more people can afford to visit or join the sprint
   fully. The partially EU funded parts of the project do have a so called sprint budget
   which we use to try to help developers to participate in our sprints
   (travel expenses and accommodation) and because most of the funding is so
   called matched funding we pay for most of our expenses in our own
   organizations and companies anyway.


4. Process - a typical PyPy sprint is 7 days with a break day in the
   middle. Usually sprinters show up the day before the sprint starts. The
   first day has a start up meeting, with tutorials if there are participants
   new to the project or if some new tool or feature have been implemented. A
   short presentation of the participants and their background and
   expectations is also good to do. Unfortunately there is always time spent
   the first day, mostly in the morning when people arrive to get the internet
   and server infrastructure up and running. That is why we are, through
   :ref:`documentation <getting-started-index>`, trying to get participants to
   set up the tools and configurations needed before they arrive to the sprint.

   Approximate hours being held are 10-17, but people tend to stay longer to
   code during the evenings. A short status meeting starts up the day and work
   is "paired" out according to need and wishes. The PyPy sprints are
   developer and group driven, because we have no "coach" our status meetings
   are very much group discussion while notes are taken and our planning texts
   are updated. Also - the sprint is done (planned and executed) within the
   developer group together with someone acquainted with the local region
   (often a developer living there). So within the team there is no one
   formally responsible for the sprints.

   Suggestions for off hours activities and social events for the break day is
   a good way of emphasizing how important it is to take breaks - some
   pointers in that direction from the local organizer is good.

   At the end of the sprint we do a technical summary (did we achieve the
   goals/content), what should be a rough focus for the work until the next
   sprint and the sprint wheel starts rolling again ;-) An important aspect is
   also to evaluate the sprint with the participants. Mostly this is done via
   emailed questions after the sprint, it could also be done as a short group
   evaluation as well. The reason for evaluating is of course to get feedback
   and to make sure that we are not missing opportunities to make our sprints
   even more efficient and enjoyable.

    The main challenge of our sprint process is the fact that people show up
    at different dates and leave at different dates. That affects the shared
    introduction (goals/content, tutorials, presentations etc) and also the
    closure - the technical summary etc. Here we are still struggling to find
    some middle ground - thus increases the importance of feedback.


Can I join in?
~~~~~~~~~~~~~~

Of course. Just follow the work on pypy-dev and if you specifically are
interested in information about our sprints - subscribe to
pypy-sprint@codespeak.net and read the news on codespeak for announcements etc.

If you think we should sprint in your town - send us an email - we are very
interested in using sprints as away of making contact with active developers
(Python/compiler design etc)!
