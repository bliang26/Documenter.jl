abstract type DeployConfig end

struct Travis <: DeployConfig
    documenter_key::String
    travis_branch::String
    travis_pull_request::String
    travis_repo_slug::String
    travis_tag::String
    travis_event_type::String
    repo::String
    devbranch::String
end
function Travis(; repo, devbranch)
    documenter_key      = get(ENV, "DOCUMENTER_KEY",       "")
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_event_type   = get(ENV, "TRAVIS_EVENT_TYPE",    "")
    return Travis(documenter_key, travis_branch, travis_pull_request,
        travis_repo_slug, travis_tag, travis_event_type, repo, devbranch)
end

# Check criteria for deployment
function should_deploy(cfg::Travis)
    ## The deploydocs' repo should match TRAVIS_REPO_SLUG
    repo_ok = occursin(cfg.travis_repo_slug, cfg.repo)
    ## Do not deploy for PRs
    pr_ok = cfg.travis_pull_request == "false"
    ## If a tag exist it should be a valid VersionNumber
    tag_ok = isempty(cfg.travis_tag) || occursin(Base.VERSION_REGEX, cfg.travis_tag)
    ## If no tag exists deploydocs' devbranch should match TRAVIS_BRANCH
    branch_ok = !isempty(cfg.travis_tag) || cfg.travis_branch == cfg.devbranch
    ## DOCUMENTER_KEY should exist
    key_ok = !isempty(cfg.documenter_key)
    ## Cron jobs should not deploy
    type_ok = cfg.travis_event_type != "cron"
    all_ok = repo_ok && pr_ok && tag_ok && branch_ok && key_ok && type_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with Travis:
    - $(marker(repo_ok)) ENV["TRAVIS_REPO_SLUG"]="$(cfg.travis_repo_slug)" occurs in repo="$(cfg.repo)"
    - $(marker(pr_ok)) ENV["TRAVIS_PULL_REQUEST"]="$(cfg.travis_pull_request)" is "false"
    - $(marker(tag_ok)) ENV["TRAVIS_TAG"]="$(cfg.travis_tag)" is (i) empty or (ii) a valid VersionNumber
    - $(marker(branch_ok)) ENV["TRAVIS_BRANCH"]="$(cfg.travis_branch)" matches devbranch="$(cfg.devbranch)" (if tag is empty)
    - $(marker(key_ok)) ENV["DOCUMENTER_KEY"] exists
    - $(marker(type_ok)) ENV["TRAVIS_EVENT_TYPE"]="$(cfg.travis_event_type)" is not "cron"
    Deploying: $(marker(all_ok))
    """
    return all_ok
end

struct GitHubActions <: DeployConfig
    documenter_key::String
    github_repository::String
    github_event_name::String
    github_ref::String
    repo::String
    devbranch::String
end
function GitHubActions(; repo, devbranch)
    documenter_key    = get(ENV, "DOCUMENTER_KEY",    "")
    github_repository = get(ENV, "GITHUB_REPOSITORY", "") # "JuliaDocs/Documenter.jl"
    github_event_name = get(ENV, "GITHUB_EVENT_NAME", "") # "push", "pull_request" or "cron" (?)
    github_ref        = get(ENV, "GITHUB_REF",        "") # "refs/heads/$(branchname)" for branch, "refs/tags/$(tagname)" for tags
    return GitHubActions(documenter_key, github_repository, github_event_name, github_ref, repo, devbranch)
end

# Check criteria for deployment
function should_deploy(cfg::GitHubActions)
    ## The deploydocs' repo should match GITHUB_REPOSITORY
    repo_ok = occursin(cfg.github_repository, cfg.repo)
    ## Do not deploy for PRs
    pr_ok = cfg.github_event_name == "push"
    ## If a tag exist it should be a valid VersionNumber
    mt = match(r"^refs/tags/(.*)$", cfg.github_ref)
    tag_ok = mt === nothing || occursin(Base.VERSION_REGEX, String(mt.captures[1]))
    ## If no tag exists deploydocs' devbranch should match the current branch
    mb = match(r"^refs/heads/(.*)$", cfg.github_ref)
    branch_ok = mt !== nothing || String(mb.captures[1]) == cfg.devbranch
    ## DOCUMENTER_KEY should exist
    key_ok = !isempty(cfg.documenter_key)
    # ## Cron jobs should not deploy
    # type_ok = cfg.travis_event_type != "cron"
    all_ok = repo_ok && pr_ok && tag_ok && branch_ok && key_ok # && type_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with GitHub Actions:
    - $(marker(repo_ok)) ENV["GITHUB_REPOSITORY"]="$(cfg.github_repository)" occurs in repo="$(cfg.repo)"
    - $(marker(pr_ok)) ENV["GITHUB_EVENT_NAME"]="$(cfg.github_event_name)" is "push"
    - $(marker(tag_ok)) ENV["GITHUB_REF"]="$(cfg.github_ref)" corresponds to a tag or matches devbranch="$(cfg.devbranch)"
    - $(marker(key_ok)) ENV["DOCUMENTER_KEY"] exists
    Deploying: $(marker(all_ok))
    """
    return false
end
