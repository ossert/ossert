Code quality? Checked by [RuboCop](https://github.com/bbatsov/rubocop/) (crowdsourced code quality metrics)

What about library support?

Introducing **Ossert**! Crowdsourced project support metrics.

# ossert (OSS cERTificate)

The main goal of project is to provide "certificate" for open-source software with different validity check, just to be more
formal in estimation of projects' risks, value and ability to use. Also system is designed as open one, so any new checks and validations from
community are appreciated.

The simple structure is:
- Checks DataSources (such as Github, BitBucket, Rubygems and so on) each provides a set of "attributes"
- Validity Checks based on "attributes", they provide just values which can be compared to other projects.
  Their goal is not to say "Bad" or "Good" something is, but to provide some more detailed info about projects' legacy
- We have "profile" page for each project, which shows values for Selected Validity Checks, as they were previously calculated
  and could be refreshed on demand.
- Also we have feature to compare several projects on same Selected Validity Checks and see any deviations from relatively best or
  worst of them

Any subset of Validity Checks could be marked by Tag, if you want to reuse those checks later. Btw, there are configured
Community Certificates, those are same subset of checks but they are defined and approved by community as best in some cases.
For example for some technologies stack or for language.

Checks DataSources (CDS) could be Remote or Local. Remote are accesses by some remote API and Local are try to use projects' code (e.g. run some tool on code and gather results).
CDS should provide simple unified JSON API to make extending more simple, and also to separate development of DataSources from Validity Checks.
CDS API:
```JSON
POST <Checks DateSources>/api/v1/prepare_attributes:
{
  "data_sources": [
    {"name": "Github", "project_name": "someone/project_best", "attributes": ["stars", "forks", "watch"]},
    {"name": "Rubygems", "project_name": "project-best", "attributes": ["total_downloads", "downloads_for_current_version"]}
  ]
}

GET <Checks DateSources>/api/v1/attributes/<CDS name>/<project name> e.g. /api/v1/attributes/Github/someone/project_best:
{
  "actual_time": 1234154353,
  "attributes": {
    "stars": "123",
    "forks": "1023"
  },
  "not_collected": ["watch"]
}

```
Validity Check (VC) is identified by meaningful name and should be stored along with CDS and their attributes used in formula.

## Metrics

I choose to start with following Basic Validity Checks

### Community Metrics

#### Stats, total for all time
- Users count writing issues
- Users count sent PR
- Contributors count
- Watchers, Stargazers, Forks
- Owners... (link Rubygems and Github by email)
- Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)

#### Pulse, for last year/quarter/month (amount + delta from total)
- Users count writing issues
- Users count sent PR
- Contributors count
- Watchers, Stargazers, Forks

### Project Metrics

#### Stats, total for all time
- Opened and Closed Issues
- Opened, Merged and Closed PRs
- Opened non-author Issues, "with author comments" and total count
- Issues no:assignee no:milestone to Total Count
- Time since first/last PR and Issue
- Releases Count
- Last Release Date
- Commits count since last release
- Amount of changes each quarter (Graph? -> Later)
- Stale and Total branches count

#### Pulse, for last year/quarter/month (amount + delta from total)
- Opened and Closed Issues
- Opened and Merged PRs
- Releases Count
- Downloads divergence
- Downloads degradation per release ??
- Branches Count

## OSSert Project Profile
Somewhat like that https://gemnasium.com/razum2um/lurker, but about support quality.
OSSert-profile for project contains:
- Links from gemspec
  - Website
  - RDoc
  - Wiki
  - Source Code
  - Bug Tracker
- Projects' Community metrics described above
- Project metrics described above

## Existining alternatives

### Github Archive (https://www.githubarchive.org/#bigquery)

### RubyToolbox has:
- Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)
- Links, from gemspec
  - Website
  - RDoc
  - Wiki
  - Source Code
  - Bug Tracker
- from Rubygems
  - Total Downloads + increased for month
  - Total Releases Count
  - Current Version
  - When Released
  - First Release Date
  - Depends on following gems
  - Depending Gems (reverse dependencies)
  - Popular gems depending on this... (list)
- from Github
  - Watchers
  - Forks
  - Development activity (N commits within last year)
  - Last commit date
  - First commit date
  - Top contributors
  - Contributors Count
  - Issues Count
  - Wiki pages link

### Rubygems has:
- Total Downloads
- Total Releases Count
- current version and when it was released
- first release date
- Dependencies
- Depending Gems (reverse dependencies)

### Github has:
- Opened and Closed PRs
- Opened and Closed Issues
- Labels list
- Milestones list
- Watchers Count & Links
- Stargazers Count & Links
- Forks Count & Links
- Commits Count
- Branches Count
- Releases Count
- Contributors Count
- Latest commit date

#### Pulse, for month/week/3 days/24 hours period
"Excluding merges, 29 authors have pushed 76 commits to master and 87 commits to all branches.
 On master, 128 files have changed and there have been 5,342 additions and 5,554 deletions."
- Active PRs Count and List (sent, merged)
- Active Issues Count and List (new, closed)
- Unresolved conversations
  "Sometimes conversations happen on old items that aren’t yet closed.
  Here is a list of all the Issues and Pull Requests with unresolved conversations."

#### Graphs, all time or selected period
- Top contributors (by commits/additoins/deletions)
- Commits timeline
- Code frequency (Additions/Deletions amount on timeline)
- Punch card (Days and Hours of most activity)

### What metrics to use. Place for "think about it":
- Releases Count for life time (Rubygems, Git, Github)
- Downloads divergence
- Regular releases
- Time since last release
- Time since first release
- "AVG" distince in time btw releases
- Branches Stale Count / Total Count Stale branches percent
- Downloads degradation per release
- Pull Requests: (GH)
  - Open comments-author count
  - Open without labels/assignee/milestone
  - Open / Total
  - How often opened/closed
  - Time since first/last
- Issues: (GH)
  - no:assignee no:milestone
  - Open comments-author count
  - Open without labels
  - Open / Total
  - How often opened/closed
  - Time since first/last
- Lifetime contributors count ???
- Contributors Count
- Non-contributor Issues open/closed
- Non-contributor Pull Requests open/closed
- Date of latest Issue
- Date of latest PR
- Commits / Lifetime
- Readme, License, Changelog existance
- Watch, Stars, Forks from best (RubyToolbox Popularity)
- Time since last release
- Releases whithin 2 years since last release
- Milestones Exists, Milestones Open, Milestones Closed
- Rubygems reverse_dependencies
- Rubygems versions???? created_at -> downloads_count...
- Rubygems, owners ?
- [Later] Lines of Code
- Small contributions better
- More Issues is better. Even better then PRs!
- https://github.com/pengwynn/flint

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ossert'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ossert

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ossert.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

