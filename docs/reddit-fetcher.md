# Reddit

This crawler retrieves questions and other data related to the given project (gem).

## Fetched data

  - number of posts
  - sum of post scores
  - average number of comments
  - number of unique authors

## Known issues

  - Search is limited to most Ruby-related subreddits. Still, there are a lot of false positives for commonplace gem titles. Also API does not consider underscore symbol so it searches for multiple words here, albeit in same sequence.
  
## Typical response

```json
{
  "after": nil,
  "whitelist_status": "all_ads",
  "facets": {},
  "modhash": "",
  "children": [
    {
      "kind": "t3",
      "data": {
        "domain": "self.rails",
        "approved_at_utc": nil,
        "banned_by": nil,
        "media_embed": {},
        "thumbnail_width": nil,
        "subreddit": "rails",
        "selftext_html": "&lt;!-- SC_OFF --&gt;&lt;div class=\"md\"&gt;&lt;p&gt;I have a bunch of things that I&amp;#39;m looking to make background jobs for using Sidekiq.  The tutorials I&amp;#39;ve read seem to always have one worker file per background job, such as &lt;a href=\"https://ryanboland.com/blog/writing-your-first-background-worker/\"&gt;this tutorial&lt;/a&gt;.  &lt;/p&gt;\n\n&lt;p&gt;Is that generally the case?  Or do people generally put all of their background jobs in a single file, like Mailer?&lt;/p&gt;\n\n&lt;p&gt;My background jobs span methods in different models, in case that matters for how worker files are generally organized.&lt;/p&gt;\n&lt;/div&gt;&lt;!-- SC_ON --&gt;",
        "selftext": "I have a bunch of things that I'm looking to make background jobs for using Sidekiq.  The tutorials I've read seem to always have one worker file per background job, such as [this tutorial](https://ryanboland.com/blog/writing-your-first-background-worker/).  \n\nIs that generally the case?  Or do people generally put all of their background jobs in a single file, like Mailer?\n\nMy background jobs span methods in different models, in case that matters for how worker files are generally organized.",
        "likes": nil,
        "suggested_sort": nil,
        "user_reports": [],
        "secure_media": nil,
        "is_reddit_media_domain": false,
        "link_flair_text": nil,
        "id": "6p6ml2",
        "banned_at_utc": nil,
        "view_count": nil,
        "archived": false,
        "clicked": false,
        "report_reasons": nil,
        "title": Workers for Sidekiq",
        "num_crossposts: 0,
        "saved": false,
        "mod_reports": [],
        "can_mod_post": false,
        "is_crosspostable": false,
        "pinned": false,
        "score": 3,
        "approved_by": nil,
        "over_18": false,
        "hidden": false,
        "preview": {
          "images": [
            {
              "source": {
                "url": "https://i.redditmedia.com/kIcpaNj0b20ReaSasJI1-P3o5LmiuNfTAwumIO5Ds7I.jpg?s=3c98137a357f2b0a5d2bb3d60f7a6d4a",
                "width": 914,
                "height": 538
              },
              "resolutions": [
                {
                  "url": "https://i.redditmedia.com/kIcpaNj0b20ReaSasJI1-P3o5LmiuNfTAwumIO5Ds7I.jpg?fit=crop&amp;crop=faces%2Centropy&amp;arh=2&amp;w=108&amp;s=e13cf929ff2d592b15d99409d2f0b385",
                  "width": 108,
                  "height": 63
                },
                ...
              ],
              "variants": {},
              "id": "kq6diRVjDDkOCitlQdpvaan0A865gybJSeZDU3hl4iM"
            },
            ...
          ],
          "enabled": false
        },
        "thumbnail": "self",
        "subreddit_id": "t5_2qhjn",
        "edited": false,
        "link_flair_css_class": nil,
        "author_flair_css_class": nil,
        "contest_mode": false,
        "gilded": 0,
        "downs": 0,
        "brand_safe": true,
        "secure_media_embed": {},
        "removal_reason": nil,
        "post_hint": "self",
        "author_flair_text": nil,
        "stickied": false,
        "can_gild": false,
        "thumbnail_height": nil,
        "parent_whitelist_status": "all_ads",
        "name": "t3_6p6ml2",
        "spoiler": false,
        "permalink": "/r/rails/comments/6p6ml2/workers_for_sidekiq/",
        "subreddit_type": "public",
        "locked": false,
        "hide_score": false,
        "created": 1500906066.0,
        "url": "https://www.reddit.com/r/rails/comments/6p6ml2/workers_for_sidekiq/",
        "whitelist_status": "all_ads",
        "quarantine": false,
        "author": "yellowreign",
        "created_utc": 1500877266.0,
        "subreddit_name_prefixed": "r/rails",
        "ups": 3,
        "media": nil,
        "num_comments": 7,
        "is_self": true,
        "visited": false,
        "num_reports": nil,
        "is_video": false,
        "distinguished": nil
      }
    }
    ...
  ],
  "before": nil
}
```