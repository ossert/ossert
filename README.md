Code style? Checked by [RuboCop](https://github.com/bbatsov/rubocop/) (crowdsourced code style metrics)
What about library support?
Introducing **Ossert**! Crowdsourced project support and availablity metrics.

# ossert (OSS cERTificate) [![Build Status](https://travis-ci.org/ossert/ossert.svg?branch=master)](https://travis-ci.org/ossert/ossert) [![Inline docs](http://inch-ci.org/github/ossert/ossert.svg)](http://inch-ci.org/github/ossert/ossert)  [![Code Climate](https://codeclimate.com/github/ossert/ossert/badges/gpa.svg)](https://codeclimate.com/github/ossert/ossert)

The main goal of project is to provide "certificate" for open-source software with different validity check, just to be more
formal in estimation of projects' risks, value and ability to use. Also system is designed as open one, so any new checks and validations from
community are appreciated.

The simple structure is:
- Checks DataSources (such as Github, Bestgems, Rubygems and so on) each provides a set of "attributes"
- Validity checks based on "attributes", they provide just values which can be compared to other projects.
  Their goal is not to say "Bad" or "Good" something is, but to provide some more detailed info about projects' legacy
- We have "profile" page for each project, which shows values for some set of validity checks, as they were previously calculated
  and could be refreshed on demand.
- Also we have feature to compare several projects on same validity checks and see any deviations from relatively best or
  worst of them

## Metrics

I choose to start with following basic validity checks

### Project Community Metrics

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

### Project Agility Metrics

#### Stats, total for all time
- Opened and Closed Issues
- Opened, Merged and Closed PRs
- Opened non-author Issues, "with author comments" and total count
- Time since first/last PR and Issue
- Releases Count
- Last Release Date
- Commits count since last release
- Amount of changes each quarter
- Stale and Total branches count

#### Pulse, for last year/quarter/month (amount + delta from total)
- Opened and Closed Issues
- Opened and Merged PRs
- Releases Count
- Downloads divergence
- Downloads degradation per release (Comes later)
- Branches Count

## OSSert Project Profile
Somewhat like that https://gemnasium.com/razum2um/lurker, but about support quality.
OsSert-profile for project contains:
- Links from gemspec
  - Website
  - RDoc
  - Wiki
  - Source Code
  - Bug Tracker
- Project Community metrics described above
- Project Agility metrics described above

## Existining alternatives

### RecordNotFound.com
Interesting overview by commits and pull requests activity, not very detailed

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

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ossert'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ossert

After that you should set ENV variables:

```
$ export GITHUB_TOKEN xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
$ export DATABASE_URL postrgres://localhost/ossert
$ export TEST_DATABASE_URL postrgres://localhost/ossert_test
```

Then you can run:

```ruby
bundle exec rake db:setup
```

Or if you have previous dumps of data:

```ruby
bundle exec rake db:restore:last
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ossert/ossert.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

