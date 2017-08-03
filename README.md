# Ossert (OSS cERTificate) [![Build Status](https://travis-ci.org/ossert/ossert.svg?branch=master)](https://travis-ci.org/ossert/ossert) [![Inline docs](http://inch-ci.org/github/ossert/ossert.svg)](http://inch-ci.org/github/ossert/ossert)  [![Code Climate](https://codeclimate.com/github/ossert/ossert/badges/gpa.svg)](https://codeclimate.com/github/ossert/ossert) [![Code Coverage](https://codecov.io/gh/ossert/ossert/coverage.svg?branch=master)](https://codecov.io/gh/ossert/ossert)

[![Join the chat at https://gitter.im/ossert_app/Lobby](https://badges.gitter.im/ossert_app/Lobby.svg)](https://gitter.im/ossert_app/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Introducing **Ossert**—an Open-Source Maturity Maintenance Certification service.

The goal of the project is to provide a "certificate" for open-source software, a formal way to calculate and estimate all the risks of using a certain project as a dependency for the product you are building, its value and the ability to use it in an enterprise environment.

Ossert is free and open-source. Any new checks and validations from the community are appreciated.

Ossert tries to answer a simple question:

> "Is this gem ready for production? Will it still be available, supported and consistent in a year?"

Ossert marks projects with grades (A, B, C, D, E). The highest grade means that you possibly can trust that open-source project because it is used widely and well-supported. Lesser grades mean higher risks for production usage. Also, you can check several alternatives around the same checks to select the most stable and mature alternative.

Ossert should help you dive into any open-source library on any level of detail, from overall marks to a particular change during the project's timespan. The long term milestone is to provide not only marks and metrics—but also give a context of classification (trends, metadata, discussions, docs, users and so on).

**Be sure to check this blog post to understand the motivation behind Ossert and its methodology: https://evilmartians.com/chronicles/open-source-software-whats-in-a-poke**

<a href="https://evilmartians.com/?utm_source=ossert">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54">
</a>

## Ossert architecture

- `Project` has a set of raw attributes gathered from different data sources—and metrics built upon them.
- `Fetch` classes gather data from sources like RubyGems, Bestgems, GitHub.
- `Reference` class chooses reference projects from various popularity groups (from most to the least popular).
- `Classifiers::Growing::Classifier` class provides classification by sections (Maintenance, Popularity, Maturity) using reference projects.
  Each classifier section performs calculation upon its own metrics and weights.
- Running `Classifiers::Growing::Check` checks against the classifier and prepares marks for a particular project.

## Metrics

I chose to start with the following basic validity checks:

### Project Community Metrics

#### Stats, total for all time
- Users writing issues count
- Users sent a PR count
- Contributors count
- Watchers, Stargazers, Forks
- Owners (link RubyGems and Github by email)

#### Pulse, for last year/quarter/month (amount + delta from total)
- Users writing issues count
- Users sent PR count
- Contributors count
- Watchers, Stargazers, Forks

### Project Agility Metrics

#### Stats, total for all time
- Open and Closed Issues
- Open, Merged and Closed PRs
- Open non-author Issues, "with author comments" and total count
- Time since first/last PR and Issue
- Releases Count
- Last Release Date
- Commits count since the last release
- Amount of changes each quarter
- Stale and Total branches count

#### Pulse, for last year/quarter/month (amount + delta from total)
- Open and Closed Issues
- Open and Merged PRs
- Releases Count
- Downloads divergence
- Downloads degradation per release (will come later)
- Stale Branches Count

## Existing alternatives

### RecordNotFound.com

Interesting overview by commits and pull requests activity; not very detailed.

### GitHub Archive (https://www.githubarchive.org/#bigquery)

### RubyToolbox has:
- Popularity Rating (https://www.ruby-toolbox.com/projects/delayed_job/popularity)
- Links, from gemspec
  - Website
  - RDoc
  - Wiki
  - Source Code
  - Bug Tracker
- from RubyGems
  - Total Downloads + increased for month
  - Total Releases Count
  - Current Version
  - When Released
  - First Release Date
  - Depends on following gems
  - Depending Gems (reverse dependencies)
  - Popular gems depending on this... (list)
- from GitHub
  - Watchers
  - Forks
  - Development activity (N commits within last year)
  - Last commit date
  - First commit date
  - Top contributors
  - Contributors Count
  - Issues Count
  - Wiki pages link

### RubyGems has:
- Total Downloads
- Total Releases Count
- Current version and when was it released
- First release date
- Dependencies
- Depending Gems (reverse dependencies)

### GitHub has:
- Open and Closed PRs
- Open and Closed Issues
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
```
"Excluding merges, 29 authors have pushed 76 commits to master and 87 commits to all branches.
 On master, 128 files have changed and there have been 5,342 additions and 5,554 deletions."
```
- Active PRs Count and List (sent, merged)
- Active Issues Count and List (new, closed)
- Unresolved conversations
  "Sometimes conversations happen on old items that aren’t yet closed.
  Here is a list of all the Issues and Pull Requests with unresolved conversations."

#### Graphs, all time or selected period
- Top contributors (by commits/additions/deletions)
- Commits timeline
- Code frequency (Additions/Deletions amount on timeline)
- Punch card (Days and Hours of most activity)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ossert'
```

And then execute:

```
$ bundle
```

Alternatively, install it manually as:

```
$ gem install ossert
```

After that you should set `ENV` variables:

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

Or, if you have previous dumps of data:

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
