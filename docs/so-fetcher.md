# StackOverflow

This crawler retrieves questions and other data related to the given project (gem).

## Fetched data

The fetcher has completely separated ways of gathering data for quarter-based and all-time statistic.
For the explanation of features see [this discussion](https://github.com/ossert/ossert/issues/7).

### For quarters

  - median of questioner reputations
  - sum of question views
  - average number of answers
  - sum of question scores
  - number of unique questioners
  - number of questions
  - number of resolved questions

### For all time

  - total number of questions
  - total number of resolved questions
  - date of the last question

## Known issues

  - Currently there is no any absolutely reliable way to find all questions related to the current gem. This is especially a problem in case of ambiguous names like "concurrency", "fusion", "aws-s3". Another thing is questions which contain a full content of `Gemfile` - in this case it is likely that API will return the hit for the popular gems (like "rails", "rake", "activerecord"), but in fact it is not related at all. The current way is to use an exact match in the whole question + restriction by tag "ruby". I would add several tags for restriction, but unfortunately API combine them with AND relation, not OR.
  - It is impossible to get quarter-based information for all quarters, because old and popular gems (like "rails") will require too much requests to fetch all the questions. As a temporal solution the fetcher retrieves only 4 last completed quarters + the current one, but no more than 5000 questions.
  - Questioner reputation should be tightly coupled with a questioner as it represents different features of the same thing. To date it is impossible to store such values in a hash, due to the way it eliminates duplicates during the unification of quarters data into one year stat. The preliminary check for owner existence allowed to avoid reputation duplicity here, but it's not the case for years-from-quarters. So, right now it's possible that in year stats there could be several    reputations of the same person if he asked the questions in different quarters. I consider it as a minor issue.

## Typical response

```json
{
  "items": [
    {
      "tags": [
        "ruby-on-rails",
        "ruby",
        "ruby-on-rails-4"
      ],
      "owner": {
        "reputation": 17,
        "user_id": 7108144,
        "user_type": "registered",
        "accept_rate": 100,
        "profile_image": "https://www.gravatar.com/avatar/2b4643c1233afae2aa2b60039ad04f32?s=128&d=identicon&r=PG&f=1",
        "display_name": "Wali Chaudhary",
        "link": "http://stackoverflow.com/users/7108144/wali-chaudhary"
      },
      "is_answered": false,
      "view_count": 6,
      "answer_count": 0,
      "score": 0,
      "last_activity_date": 1482232493,
      "creation_date": 1482232193,
      "last_edit_date": 1482232493,
      "question_id": 41240930,
      "link": "http://stackoverflow.com/questions/41240930/i-cant-associate-2-objects-in-the-rails-console-manually-without-getting-a-nome",
      "title": "I can&#39;t associate 2 objects in the Rails console manually without getting a NoMethod error"
    },
    ...
  ],
  "has_more": true,
  "quota_max": 10000,
  "quota_remaining": 9995
}
```