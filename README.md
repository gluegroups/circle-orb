# Glue Orb  [![CircleCI Build Status](https://circleci.com/gh/gluegroups/circle-orb.svg?style=shield "CircleCI Build Status")](https://circleci.com/gh/gluegroups/circle-orb) [![CircleCI Orb Version](https://badges.circleci.com/orbs/gluegroups/glue.svg)](https://circleci.com/orbs/registry/orb/gluegroups/glue) [![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/gluegroups/circle-orb/master/LICENSE) [![CircleCI Community](https://img.shields.io/badge/community-CircleCI%20Discuss-343434.svg)](https://discuss.circleci.com/c/ecosystem/orbs)

Send Glue notifications from your CircleCI pipelines even easier with Glue Orb.

[What are Orbs?](https://circleci.com/orbs/)

## Usage

### Setup

In order to use the Glue Orb on CircleCI you will need to create a Glue App and provide an OAuth token. Find the guide in the wiki: [How to setup Glue orb](https://github.com/gluegroups/circle-orb/wiki/Setup)

### Use In Config

For full usage guidelines, see the [Orb Registry listing](http://circleci.com/orbs/registry/orb/gluegroups/glue).

## Templates

The Glue Orb comes with a number of included templates to get you started with minimal setup. Feel free to use an included template or create your own.

| Template Preview  | Template  | Description |
| ------------- | ------------- | ------------- |
| ![basic_success_1](./.github/img/basic_success_1.png)  | basic_success_1   | Should be used with the "pass" event. |
| ![basic_fail_1](./.github/img/basic_fail_1.png)  | basic_fail_1   | Should be used with the "fail" event. |
| ![success_tagged_deploy_1](./.github/img/success_tagged_deploy_1.png)  | success_tagged_deploy_1   | To be used in the event of a successful deployment job. _see orb [usage examples](https://circleci.com/developer/orbs/orb/gluegroups/glue#usage-examples)_ |
| ![basic_on_hold_1](./.github/img/basic_on_hold_1.png)  | basic_on_hold_1   | To be used in the on-hold job. _see orb [usage examples](https://circleci.com/developer/orbs/orb/gluegroups/glue#usage-examples)_  |

## Custom Message Template

  1. Create your desired notification message using Markdown.
  2. Replace any placeholder values with $ENV environment variable strings.
  3. Set the resulting code as the value for your `custom` parameter.

  ```yaml
- glue/notify:
      event: always
      custom: |
        **This is a text notification**
  ```

## Branch or Tag Filtering

Limit Glue notifications to particular branches with the "branch_pattern" or "tag_pattern" parameter.

```
A comma separated list of regex matchable branch or tag names. Notifications will only be sent if sent from a job from these branches/tags. By default ".+" will be used to match all branches/tags. Pattern must match the full string, no partial matches. Keep in mind that "branch_pattern" and "tag_pattern" are mutually exclusive.
```

See [usage examples](https://circleci.com/developer/orbs/orb/gluegroups/glue#usage-examples).

## Thread Messages

Post replies in threads with a special parameter `thread_id`. Including this parameter in the `notify` command reference stores the id of the message in a small portion of bytes in cache. Any subsequent invocation of the command with the same value for `thread_id` will post a reply to the initial message in a thread. Example:

```yaml
- glue/notify:
      event: always
      target: grp_engineering
      thread_id: testing
      custom: |
        **Tests started.**
- glue/notify:
      event: always
      target: grp_engineering
      thread_id: testing
      custom: |
        **Tests finished.**
```

---

## FAQ

View the [FAQ in the wiki](https://github.com/gluegroups/circle-orb/wiki/FAQ)

## Contributing

We welcome [issues](https://github.com/gluegroups/circle-orb/issues) and [pull requests](https://github.com/gluegroups/circle-orb/pulls) against this repository!

For further questions/comments about this or other orbs, visit [CircleCI's orbs discussion forum](https://discuss.circleci.com/c/orbs).