using Documenter
using NetLogo

Documenter.DocMeta.setdocmeta!(NetLogo, :DocTestSetup, :(using NetLogo); recursive=true)

const REPO_URL = "https://github.com/ecorecipes/NetLogo.jl"
const REPO = Documenter.Remotes.GitHub("ecorecipes", "NetLogo.jl")

makedocs(
    sitename = "NetLogo.jl",
    modules = [NetLogo],
    repo = REPO,
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        edit_link = "main",
        repolink = REPO_URL,
    ),
    remotes = nothing,
    checkdocs = :exports,
    doctest = true,
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "GUI Backends" => "gui.md",
        "Language and Runtime" => "language.md",
        "Extensions" => "extensions.md",
        "Evaluation and Benchmarking" => "evaluation.md",
        "Development" => "development.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/ecorecipes/NetLogo.jl.git",
    devbranch = "main",
)
