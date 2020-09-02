module BypassWatchedWord
  class Engine < ::Rails::Engine
    engine_name "BypassWatchedWord".freeze
    isolate_namespace BypassWatchedWord

    config.after_initialize do
      Discourse::Application.routes.append do
        mount ::BypassWatchedWord::Engine, at: "/bypass-watched-words"
      end
    end
  end
end
