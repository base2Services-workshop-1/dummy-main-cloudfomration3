# Main Cloudformation Sync Repo

## Inital Repo Setup Tasks

### Rename master branch to main

Due to current limitations of the AWS CodeStar Github Cloudformation resource when it creates a repo it creates a master branch to rename running the following command

```bash
git branch -m master main
git push origin main -u
```

Then goto to github and change to main in the repo settings

### Enabling GitHub Actions

To enable github actions for this repo run

```bash
git checkout -b enable-gh-actions
mv github-actions .github
git add .github/
git add github-actions/
git commit -m 'enables github actions'
git push origin enable-gh-actions -u
```

Then create a Pull-Request from the `enable-gh-actions` to `main` and merge