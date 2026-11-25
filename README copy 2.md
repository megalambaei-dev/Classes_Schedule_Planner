# Set up your team's Rails project

Choose **one person per team** to create the app and push the first commit. The other teammates clone it afterwards and check that they can run it.

The example uses `team_01` as the Rails app and folder name. Use a short name such as `room_booking` and change that name everywhere it appears, including the two database names. Replace `REPO` with the repository name the lecturer gives you. Run the commands in Ubuntu on WSL2 or in your Linux terminal.

## 1. Get access and check your tools

- **Lecturer.** I will create a private repository and a GitHub Project for each team in the `ci2-ipt` organisation and invite you.
- **Everyone.** Send me your GitHub username. Accept both invitations and open the repository and project board.
- **Everyone.** Check your Linux setup. On Windows, start Docker Desktop and enable WSL integration for your Ubuntu distribution. A native Linux machine can use Docker Engine with the Compose plugin. Run the following in Linux, including the SSH check. [WSL and SSH walkthrough](../02-rails-store/README.md) · [Docker Desktop WSL integration](https://docs.docker.com/desktop/features/wsl/)

```bash
mise --version
mise exec ruby@3.4 -- ruby --version
git --version
docker --version
docker compose version
docker info --format '{{.ServerVersion}}'
ssh -T git@github.com
```

`docker --version` checks the client. The `docker info` command should also print a server version. If it cannot connect, check that Docker is running and your distribution is enabled. The SSH response should say `Hi YOUR_USERNAME!` and mention that GitHub provides no shell access. If you need a key, create it **inside WSL** and add its public half to GitHub. The invitation gives that account access to the repository. [Test your GitHub SSH connection](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)

The setup owner follows steps 2–8. Everyone else can go to step 9 after the first push.

## 2. Generate the app once

In WSL Bash, start in a parent directory in your Linux home. Ruby 3.4 and Rails 8.1 are the course release lines. mise selects installed patches for Ruby 3.4, Bun 1.4 and Node 24. With a fresh tool cache it installs versions that match those requests. [mise version files](https://mise.jdx.dev/dev-tools/versions.html)

```bash
mkdir -p ~/src
cd ~/src

mise install ruby@3.4 bun@1.4 node@24
mise exec ruby@3.4 -- gem install rails --version '~> 8.1.0' --no-document
rails_version=$(mise exec ruby@3.4 -- ruby -e 'print Gem::Specification.find_by_name("rails", "~> 8.1.0").version')

mise exec ruby@3.4 bun@1.4 node@24 -- \
  rails "_${rails_version}_" new team_01 -d postgresql -j bun --css bootstrap --skip-system-test
cd team_01
```

- `-d postgresql` sets up the PostgreSQL adapter. If installing the `pg` gem fails when compiling on Ubuntu, install `libpq-dev` and the build tools from the Rails setup lesson, then run `bundle install`.
- `-j bun` selects Bun for building JavaScript. Keep Node available for the generated asset tools.
- `--css bootstrap` gives you ready-made forms, menus and buttons. You can use `--css tailwind` if the team is comfortable building those pieces. With a short sprint, choose the one that gets your first screen working sooner.
- `--skip-system-test` keeps the starting test suite free of browser setup. You can add browser tests when the project has an interaction worth checking that way. [Rails JavaScript options](https://guides.rubyonrails.org/working_with_javascript_in_rails.html) · [Rails testing guide](https://guides.rubyonrails.org/testing.html)

Record the versions you just used in `.tool-versions`. This gives a teammate and CI the same tools even if another patch comes out next week. Keep the generated `.ruby-version`, `Gemfile.lock` and `bun.lock`.

```bash
printf 'ruby %s\nbun %s\nnode %s\n' \
  "$(sed 's/^ruby-//' .ruby-version)" \
  "$(mise exec bun@1.4 -- bun --version)" \
  "$(mise exec node@24 -- node -p process.versions.node)" > .tool-versions

mise install
cat .tool-versions
ruby --version
bin/rails --version
```

Use an activated mise shell for the rest of the guide. If plain `ruby --version` shows a different version from the file, enable mise in Bash or prefix project commands with `mise exec --`. [Rails setup lesson](../02-rails-store/README.md)

## 3. Connect Rails to PostgreSQL

Open the new project folder in VS Code with `code .`. Create `compose.yml` in the project root, next to `Gemfile`. Use the [Compose example](starter/compose.yml).

- The `db` service runs PostgreSQL 17 in a container. Rails runs in your Linux terminal.
- PostgreSQL listens on port `5432` inside the container. Compose publishes it on `127.0.0.1:5432` for Rails. The volume keeps your data when you stop the service.
- `POSTGRES_USER` and `POSTGRES_PASSWORD` must match `username` and `password` in Rails. The sample values are for local development and the disposable CI database. GitHub Actions also uses these values.

In `config/database.yml`, keep the generated `default` and `production` sections. Put this `local` block before `development` and replace the generated `development` and `test` sections. Give them different names so tests have their own data.

```yaml
local: &local
  <<: *default
  host: 127.0.0.1
  port: <%= ENV.fetch("COURSE_DB_PORT", "5432") %>
  username: course
  password: course_local

development:
  <<: *local
  database: team_01_development

test:
  <<: *local
  database: team_01_test
```

From the app root in WSL Bash, start PostgreSQL, prepare the databases and write the schema file for your first commit.

```bash
docker compose up -d --wait db
docker compose ps
bin/rails db:prepare
bin/rails db:migrate
bin/rails runner 'puts ActiveRecord::Base.connection.select_value("SELECT current_database()")'
```

Look for a healthy `db` service and the development database name in the final line. Check that `db/schema.rb` exists after `db:migrate`. That file lets another checkout set up the same database structure.

- If Compose says the port is in use, follow the next section.
- If Rails cannot connect, check `docker compose logs db` and compare the port, username and password in both files.
- An existing PostgreSQL volume keeps the login created when it was first started. Use a fresh Compose project if you are experimenting with initial credentials.

[Compose startup and readiness](https://docs.docker.com/reference/cli/docker/compose/up/) · [PostgreSQL Docker image](https://hub.docker.com/_/postgres)

### Change the port if 5432 is busy

Save the [example environment file](starter/.env.example) as `.env.example` in your app. Keep the Rails ignore rules and add these lines at the end of `.gitignore` so the example can be committed.

```gitignore
/.env
!/.env.example
```

For a local override, copy your `.env.example` to `.env`, set `COURSE_DB_PORT=55433`, and run the following from the app root in **each Bash terminal** before starting Compose, Rails or tests.

```bash
set -a
source ./.env
set +a
```

Compose reads `.env` for the port mapping. The commands above export its values so Rails can read the same port. If you keep port 5432, you can run the guide without a local `.env`. Commit example settings in `.env.example` and keep private values in your local setup. [Compose environment variables](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)

## 4. Start Rails with `bin/dev`

`bin/dev` runs the commands in `Procfile.dev`. Keep the generated `bin/dev`. Replace only the `web:` line in `Procfile.dev`. Leave the JavaScript and CSS lines below it.

```procfile
web: docker compose up -d --wait db && exec env RUBY_DEBUG_OPEN=true bin/rails server
```

The web process waits for a healthy database. If Compose fails, the `&&` stops it before Rails starts. A separate `db: docker compose up db` entry can keep the database in the foreground. Foreman starts entries together, so Rails would still need a readiness check. A separate `db:` entry with `-d` exits straight away, which tells Foreman to stop the group. Keeping the wait on `web:` avoids both problems.

Run `bin/dev` from the app root. A first run may install Foreman. Open the app and look for the Rails welcome page. If port 3000 is busy, run `PORT=3001 bin/dev` and open port 3001 instead. Press Ctrl+C to stop Rails and the asset watchers. The database stays up. Run `docker compose stop db` when you want to stop it too. [Open the app on port 3000](http://localhost:3000)

If your team prefers to start PostgreSQL in a separate terminal, keep the generated `web:` line and run `docker compose up -d --wait db` before `bin/dev`. For database commands or tests with the web server stopped, use the same Compose command.

### Optional home page

Use this if you want a small page the next teammate can recognise. Copy the [controller](starter/app/controllers/home_controller.rb) to `app/controllers/home_controller.rb`. Create `app/views/home/show.html.erb` with `<h1>Project home</h1>`. In `config/routes.rb`, add `root "home#show"` inside `Rails.application.routes.draw do` and keep the existing `/up` route. Refresh `http://localhost:3000` to see the heading. For the version shown in class, use the [Bootstrap view](starter/app/views/home/show.html.erb) and put the [SVG wordmark](starter/app/assets/images/univpt-colour.svg) in `app/assets/images/`.

## 5. Add your first test and check the code

Save the [health test](starter/test/integration/health_test.rb) as `test/integration/health_test.rb`. Open it and read the two lines inside the test. Rails sends a request to its built-in `/up` route and checks for HTTP 200. This gives the team a check that the app can answer a request before you have a first model. The database query in step 3 verifies the connection separately.

From the app root in a second WSL terminal, with PostgreSQL running, run the test. If you changed the port, load your `.env` in this terminal first.

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

Look for at least one test, one assertion and zero failures. `assert true` can show that a test file runs, but will always pass. Use the request test as your starting point. Add a test for your team's first business rule once you agree on it.

Open `Gemfile` and check for the following gems in the existing `group :development, :test do` block. Add only missing lines inside the block. The direct `rubocop` entry lets Ruby LSP find the formatter in the bundle.

```ruby
gem "rubocop-rails-omakase", require: false
gem "rubocop", require: false
gem "brakeman", require: false
gem "bundler-audit", require: false
```

Run `bundle install` and check `.rubocop.yml`. Keep the generated configuration if it already inherits Omakase. If the file is missing, create it with `inherit_gem: { rubocop-rails-omakase: rubocop.yml }`.

| Tool | Run from the app root | What it checks |
|---|---|---|
| [RuboCop with Rails Omakase](https://github.com/rails/rubocop-rails-omakase) | `bundle exec rubocop` | Ruby style using the Rails rule set. Try `bundle exec rubocop -a path/to/file.rb` for safe automatic corrections and read the diff. |
| [Brakeman](https://brakemanscanner.org/docs/quickstart/) | `bundle exec brakeman --no-pager` | Possible security problems in Rails source code. |
| [Bundler Audit](https://github.com/rubysec/bundler-audit) | `bundle exec bundler-audit check --update` | Known advisories that affect versions in `Gemfile.lock`. |

## 6. Set up VS Code in WSL

Save the [extension list](starter/.vscode/extensions.json) and [workspace settings](starter/.vscode/settings.json) as `.vscode/extensions.json` and `.vscode/settings.json` in the app. Open the app with `code .` from WSL. In Extensions, install the recommendations **in WSL** when prompted. A language server gives the editor completions, navigation and feedback about the file you're editing.

- **Ruby LSP** handles Ruby files. The settings use RuboCop when you save a `.rb` file. Open one and try **Format Document**, then save. If Ruby LSP selects the wrong runtime, choose **Change version manager → mise** in the Ruby language status and reload VS Code. Check `ruby --version` in its terminal. [Ruby LSP setup](https://shopify.github.io/ruby-lsp/vscode-extension.html)
- **Herb** checks HTML and ERB templates. Open `app/views/layouts/application.html.erb` and check that the editor shows the ERB language. Herb's formatter is a separate preview option. If you enable it, choose Herb for ERB and review the first formatted diff. [Herb setup and ERB formatting](https://herb-tools.dev/integrations/editors/vscode)
- **Stimulus LSP** helps with controller, action and target names in `data-*` attributes. It is useful once you use Stimulus in a template. [Stimulus LSP](https://marketplace.visualstudio.com/items?itemName=marcoroth.stimulus-lsp)

## 7. Add the GitHub templates, team instructions and CI

Create the folders and save each example at the path shown, relative to the Rails app root.

| File in your app | What it does |
|---|---|
| [`.github/ISSUE_TEMPLATE/work-item.md`](starter/.github/ISSUE_TEMPLATE/work-item.md) | Gives a new issue space for the outcome and the checks that show it works. |
| [`.github/pull_request_template.md`](starter/.github/pull_request_template.md) | Gives a PR space for the linked issue, the change and how it was checked. |
| [`AGENTS.md`](starter/AGENTS.md) | Tells a coding assistant where to find setup steps and which conventions and tests your team uses. Read it together before using it. |
| [`README.md`](starter/README.md) | Gives the next teammate the commands to run. Add your project name and sprint goal. |
| [`.github/workflows/ci.yml`](starter/.github/workflows/ci.yml) | Runs the **Rails tests** job on pushes to `main` and pull requests targeting `main`. Save it over the generated `ci.yml`. |

GitHub reads the issue and PR templates from the default branch. Once the first push is on `main`, look for **Work item** under **Issues → New issue**. Try the PR template on your first team change. [Issue templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository) · [PR templates](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/creating-a-pull-request-template-for-your-repository) · [AGENTS.md](https://agents.md/)

CI gives each run a fresh PostgreSQL service and uses the committed versions and lockfiles. It prepares the test database and runs the same tests you ran in step 5. [PostgreSQL services in GitHub Actions](https://docs.github.com/en/actions/tutorials/use-containerized-services/create-postgresql-service-containers)

## 8. Push the first commit

Use the SSH URL from your assigned repository. Check that `git ls-remote` succeeds and prints no refs. If you see refs, start from the existing history with the lecturer. The commands assume the generator created a local Git repository. If `git status` says there is none, run `git init` in the app root first.

Git records a name and email on each commit. If Git asks for them, set them for this repo with `git config user.name "Your Name"` and `git config user.email "YOUR_EMAIL"`. Use your own details. SSH still controls access to GitHub.

```bash
git ls-remote git@github.com:ci2-ipt/REPO.git
git check-ignore config/master.key .env

git add .
git diff --cached --stat
git ls-files -- config/master.key .env
```

The last command should print nothing. Before committing, check that the staged files include `.tool-versions`, `.ruby-version`, `Gemfile.lock`, `bun.lock`, `db/schema.rb` and the workflow. If a teammate needs to decrypt the shared Rails credentials, send the development `config/master.key` through the team's approved private channel. They save it at the same path. Keep the key and local `.env` out of commits, issues and assistant prompts.

```bash
git commit -m "Bootstrap the Rails project"
git branch -M main
git remote add origin git@github.com:ci2-ipt/REPO.git
git push -u origin main
```

Open **Actions → CI** in GitHub. Select the run for that commit, then **Rails tests**. If it fails, open the first failed step and read its output. After the first passing run, the lecturer can require this check and one teammate's approval before merging into `main`. If the organisation's plan cannot enforce the rule on the private repository, record the same checks and approval in the PR. [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)

## 9. Everyone else clones and runs the app

Start in your Linux home folder. Use the same SSH URL the setup owner used.

```bash
mkdir -p ~/src
cd ~/src
git clone git@github.com:ci2-ipt/REPO.git
cd REPO
mise install
bundle install
bun install --frozen-lockfile
```

If you need a custom port, set up and load `.env` as in step 3. Ask the setup owner for a development key only if you need the shared encrypted credentials. From the app root, run the following and open [http://localhost:3000](http://localhost:3000).

```bash
docker compose up -d --wait db
bin/rails db:prepare
bin/dev
```

In another WSL terminal, open the same app folder, load the port setting if you changed it, and run `bin/rails test`. If something fails, tell the setup owner the command and the first error so you can fix the team README. Once a second teammate can run the app and tests, pick an issue from the board and start the first change on a branch.

## If your team already pushed its starter

Use the existing app and apply any changes you need on a branch. If you move the Compose command into `Procfile.dev`, remove the old Compose command from `bin/dev`. If you switch the workflow to `Rails tests`, ask the lecturer to update any required check that still uses an old job name.
