class BypassWatchedWordConstraint
  def matches?(request)
    SiteSetting.bypass_watched_words_enabled
  end
end
