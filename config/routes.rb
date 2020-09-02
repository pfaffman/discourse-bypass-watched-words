require_dependency "bypass_watched_words_constraint"

BypassWatchedWord::Engine.routes.draw do
  get "/" => "bypass_watched_words#index", constraints: BypassWatchedWordConstraint.new
  get "/actions" => "actions#index", constraints: BypassWatchedWordConstraint.new
  get "/actions/:id" => "actions#show", constraints: BypassWatchedWordConstraint.new
end
