# Development workflow

- Commit each completed change after its relevant checks pass, as requested by
  the user. Keep unrelated edits from other sessions out of your commits.
- Run `bundle exec standardrb` before `bundle exec ruby -Itest test/all_test.rb`.
- Use Minitest and test-driven development for language behavior changes.
- The requested Git identity is Jack Willis <jack@attac.us>. If no repository
  identity is configured, supply it with Git's per-command `-c` options.
