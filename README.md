# bugsnag-error-event-downloader

**This repository is still in development.**

`bugsnag-error-event-downloader` is a tool to download [Bugsnag](https://www.bugsnag.com) error events using the [Bugsnag Data Access API(v2)](https://bugsnagapiv2.docs.apiary.io) and output them as CSV.

The following tools and settings are required to use it.

- Install [bugsnag-api-ruby](https://github.com/bugsnag/bugsnag-api-ruby)

```
$ gem install bugsnag-api
```

- Install [jsonpath](https://github.com/joshbuddy/jsonpath)

```
$ gem install jsonpath
```

- Install [fzf](https://github.com/junegunn/fzf)

```
$ brew install fzf
```

- [Get Bugsnag Personal Auth Tokens](<https://bugsnagapiv2.docs.apiary.io/#introduction/authentication/personal-auth-tokens-(recommended)>), and set to `BUGSNAG_PERSONAL_AUTH_TOKEN` environment variable

```
$ export BUGSNAG_PERSONAL_AUTH_TOKEN=xxxxx
```

- Run

```
$ ruby main.rb
```
