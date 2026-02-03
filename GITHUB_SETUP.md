# Push ralph-ollama to a private GitHub repo

The repo is initialized locally with an initial commit. GitHub CLI (`gh`) is not installed, so create the repo on GitHub first, then run the commands below.

## 1. Create the repository on GitHub

1. Go to **https://github.com/new**
2. **Repository name:** `ralph-ollama`
3. **Visibility:** Private
4. Do **not** add a README, .gitignore, or license (we already have them)
5. Click **Create repository**

## 2. Add remote and push

From the project root, run (replace `YOUR_USERNAME` with your GitHub username):

```bash
cd /home/patcseed/projects/ralph-ollama

git remote add origin https://github.com/YOUR_USERNAME/ralph-ollama.git
git push -u origin main
```

If you use SSH:

```bash
git remote add origin git@github.com:YOUR_USERNAME/ralph-ollama.git
git push -u origin main
```

## Optional: install GitHub CLI for next time

```bash
sudo apt install gh
gh auth login
# Then you can: gh repo create ralph-ollama --private --source=. --remote=origin --push
```
