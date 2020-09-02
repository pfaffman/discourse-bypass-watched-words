module BypassWatchedWords
  class BypassWatchedWordsController < ::ApplicationController
    requires_plugin BypassWatchedWords

    before_action :ensure_logged_in

    def index
    end
  end
end
