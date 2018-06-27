Contributing
------------

You are more than welcome to submit issues and merge requests to this project.

### Tests / Credo

Your commits must not break any tests or credo rules.

### Commits format

Your commits must pass `git log --check` and messages should be formatted
like this (read
[post](http://karma-runner.github.io/1.0/dev/git-commit-msg.html)
for details):

```
type(scope): subject, all in 50 characters or less

body: Provide more detail after the first line. Leave one blank line
below the summary and wrap all lines at 72 characters or less.

Uses the imperative, present tense: “change” not “changed” nor
"changes". Includes motivation for the change and contrasts with
previous behavior.

If the change fixes an issue, leave another blank line after the final
paragraph and indicate which issue is fixed in the specific format
below.

Fix #42
```

Allowed <type> values:

- feat (new feature for the user, not a new feature for build script)
- fix (bug fix for the user, not a fix to a build script)
- doc (changes to the documentation)
- style (formatting, missing semi colons, etc; no production code change)
- refactor (refactoring production code, eg. renaming a variable)
- test (adding missing tests, refactoring tests; no production code change)
- chore (updating grunt tasks etc; no production code change)

Example <scope> values:

- recipe name (like config, install, etc.)
- rubocop, foodcritic, kitchen (when dealing with specific tool)
- etc.

The <scope> can be empty (e.g. if the change is a global or difficult to assign
to a single component), in which case the parentheses are omitted.

Also do your best to factor commits appropriately, ie not too large with
unrelated things in the same commit, and not too small with the same small
change applied N times in N different commits. If there was some accidental
reformatting or whitespace changes during the course of your commits, please
rebase them away before submitting the MR.

### Files

All files must be 80 columns width formatted (actually 79), exception only
when it is really not possible.
