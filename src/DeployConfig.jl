abstract type DeployConfig end

function documenter_key(::DeployConfig)
    return ENV["DOCUMENTER_KEY"]
end

#############
# Travis CI #
#############

struct Travis <: DeployConfig
    travis_branch::String
    travis_pull_request::String
    travis_repo_slug::String
    travis_tag::String
    travis_event_type::String
end
function Travis()
    travis_branch       = get(ENV, "TRAVIS_BRANCH",        "")
    travis_pull_request = get(ENV, "TRAVIS_PULL_REQUEST",  "")
    travis_repo_slug    = get(ENV, "TRAVIS_REPO_SLUG",     "")
    travis_tag          = get(ENV, "TRAVIS_TAG",           "")
    travis_event_type   = get(ENV, "TRAVIS_EVENT_TYPE",    "")
    return Travis(travis_branch, travis_pull_request,
        travis_repo_slug, travis_tag, travis_event_type)
end

# Check criteria for deployment
function should_deploy(cfg::Travis; repo, devbranch, kwargs...)
    ## The deploydocs' repo should match TRAVIS_REPO_SLUG
    repo_ok = occursin(cfg.travis_repo_slug, repo)
    ## Do not deploy for PRs
    pr_ok = cfg.travis_pull_request == "false"
    ## If a tag exist it should be a valid VersionNumber
    tag_ok = isempty(cfg.travis_tag) || occursin(Base.VERSION_REGEX, cfg.travis_tag)
    ## If no tag exists deploydocs' devbranch should match TRAVIS_BRANCH
    branch_ok = !isempty(cfg.travis_tag) || cfg.travis_branch == devbranch
    ## DOCUMENTER_KEY should exist (just check here and extract the value later)
    key_ok = haskey(ENV, "DOCUMENTER_KEY")
    ## Cron jobs should not deploy
    type_ok = cfg.travis_event_type != "cron"
    all_ok = repo_ok && pr_ok && tag_ok && branch_ok && key_ok && type_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with Travis:
    - $(marker(repo_ok)) ENV["TRAVIS_REPO_SLUG"]="$(cfg.travis_repo_slug)" occurs in repo="$(repo)"
    - $(marker(pr_ok)) ENV["TRAVIS_PULL_REQUEST"]="$(cfg.travis_pull_request)" is "false"
    - $(marker(tag_ok)) ENV["TRAVIS_TAG"]="$(cfg.travis_tag)" is (i) empty or (ii) a valid VersionNumber
    - $(marker(branch_ok)) ENV["TRAVIS_BRANCH"]="$(cfg.travis_branch)" matches devbranch="$(devbranch)" (if tag is empty)
    - $(marker(key_ok)) ENV["DOCUMENTER_KEY"] exists
    - $(marker(type_ok)) ENV["TRAVIS_EVENT_TYPE"]="$(cfg.travis_event_type)" is not "cron"
    Deploying: $(marker(all_ok))
    """
    return all_ok
end

# Obtain git tag for the build
function git_tag(cfg::Travis)
    isempty(cfg.travis_tag) ? nothing : cfg.travis_tag
end

##################
# GitHub Actions #
##################

struct GitHubActions <: DeployConfig
    github_repository::String
    github_event_name::String
    github_ref::String
end
function GitHubActions()
    github_repository = get(ENV, "GITHUB_REPOSITORY", "") # "JuliaDocs/Documenter.jl"
    github_event_name = get(ENV, "GITHUB_EVENT_NAME", "") # "push", "pull_request" or "cron" (?)
    github_ref        = get(ENV, "GITHUB_REF",        "") # "refs/heads/$(branchname)" for branch, "refs/tags/$(tagname)" for tags
    return GitHubActions(github_repository, github_event_name, github_ref)
end

# Check criteria for deployment
function should_deploy(cfg::GitHubActions; repo, devbranch, kwargs...)
    ## The deploydocs' repo should match GITHUB_REPOSITORY
    repo_ok = occursin(cfg.github_repository, repo)
    ## Do not deploy for PRs
    pr_ok = cfg.github_event_name == "push"
    ## If a tag exist it should be a valid VersionNumber
    m = match(r"^refs/tags/(.*)$", cfg.github_ref)
    tag_ok = m === nothing ? false : occursin(Base.VERSION_REGEX, String(m.captures[1]))
    ## If no tag exists deploydocs' devbranch should match the current branch
    m = match(r"^refs/heads/(.*)$", cfg.github_ref)
    branch_ok = m === nothing ? false : String(m.captures[1]) == devbranch
    ## DOCUMENTER_KEY should exist (just check here and extract the value later)
    key_ok = haskey(ENV, "DOCUMENTER_KEY")
    # ## Cron jobs should not deploy
    # type_ok = cfg.travis_event_type != "cron"
    all_ok = repo_ok && pr_ok && (tag_ok || branch_ok) && key_ok # && type_ok
    marker(x) = x ? "✔" : "✘"
    @info """Deployment criteria for deploying with GitHub Actions:
    - $(marker(repo_ok)) ENV["GITHUB_REPOSITORY"]="$(cfg.github_repository)" occurs in repo="$(repo)"
    - $(marker(pr_ok)) ENV["GITHUB_EVENT_NAME"]="$(cfg.github_event_name)" is "push"
    - $(marker(tag_ok || branch_ok)) ENV["GITHUB_REF"]="$(cfg.github_ref)" corresponds to a tag or matches devbranch="$(devbranch)"
    - $(marker(key_ok)) ENV["DOCUMENTER_KEY"] exists
    Deploying: $(marker(all_ok))
    """
    return all_ok
end

# Obtain git tag for the build
function git_tag(cfg::GitHubActions)
    m = match(r"^refs/tags/(.*)$", cfg.github_ref)
    return m === nothing ? nothing : String(m.captures[1])
end
