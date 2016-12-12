Code quality? Checked by [RuboCop](https://github.com/bbatsov/rubocop/) (crowdsourced code quality metrics)
What about library support?
Introducing **Ossert**! Crowdsourced project support and availablity metrics.

# ossert (OSS cERTificate) [![Build Status](https://travis-ci.org/ossert/ossert.svg?branch=master)](https://travis-ci.org/ossert/ossert) [![Inline docs](http://inch-ci.org/github/ossert/ossert.svg)](http://inch-ci.org/github/ossert/ossert)  [![Code Climate](https://codeclimate.com/github/ossert/ossert/badges/gpa.svg)](https://codeclimate.com/github/ossert/ossert)

[![Join the chat at https://gitter.im/ossert_app/Lobby](https://badges.gitter.im/ossert_app/Lobby.svg)](https://gitter.im/ossert_app/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

The main goal of project is to provide "certificate" for open-source software with different validity check, just to be more
formal in estimation of projects' risks, value and ability to use in an enterprise.
Also system is designed as open one, so any new checks and validations from community are appreciated.

The simple structure is:
- "Project" has set of raw attributes gathered from different data sources and metrics built upon them.
- "Fetch" classes gathers data from sources like Rubygems, Bestgems, GitHub.
- "Reference" class chooses reference projects from different popularity groups (from most to the least popular).
- "Classifiers::Growing::Classifier" class prepares classification  by sections (Maintenance, Popularity, Maturity) using reference projects.
  Each classifier section performs calculation upon its own metrics and weights.
- "Classifiers::Growing::Check" running checks against classifier and prepares marks for particular project.

Project tries to answer simple question: "Is this gem ready for production? Will it be available and consistent in a year?"
Ossert marks projects with grades A, B, C, D, E. Highest grade means you possibly can trust that open-source project because it is
used widely and supported in efficient way. Less grades means higher risks for production.

Also you can check several alternatives against same checks to select most stable and mature from them.

Long term milestone is to provide not only marks and metrics but also give a context of classification (trends, metadata, discussions, docs, users and so on).
This tool should help you dive into any open-source library on any level of detalization, from overall marks to a particular change in time.

## Metrics

I choose to start with following basic validity checks

### Project Community Metrics

#### Stats, total for all time
- Users count writing issues
- Users count sent PR
- Contributors count
- Watchers, Stargazers, Forks
- Owners... (link Rubygems and Github by email)

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
- Stale Branches Count

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
$ export REDIS_URL redis://localhost/
$ export DATABASE_URL postrgres://localhost/ossert
$ export TEST_DATABASE_URL postrgres://localhost/ossert_test
```

Then you can run:

```
bundle exec rake db:setup
```

Or if you have previous dumps of data:

```
bundle exec rake db:restore:last
```


## Usage

For interactive experiments run:

```
bin/console
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ossert/ossert.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

