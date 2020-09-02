# frozen_string_literal: true

# name: BypassWatchedWords
# about: Allow members to bypass watched words
# version: 0.1
# authors: pfaffman
# url: https://github.com/pfaffman

register_asset 'stylesheets/common/bypass-watched-words.scss'
register_asset 'stylesheets/desktop/bypass-watched-words.scss', :desktop
register_asset 'stylesheets/mobile/bypass-watched-words.scss', :mobile

enabled_site_setting :bypass_watched_words_enabled

PLUGIN_NAME ||= 'BypassWatchedWord'

load File.expand_path('lib/bypass-watched-words/engine.rb', __dir__)

after_initialize do
  class ::ReviewableQueuedPost
  
    def auto_approve_for_group
      group = Group.find_by_name(SiteSetting.bypass_watched_words_group)
      ok = GroupUser.find_by(user_id: self.created_by_id, group_id: group.id)
      approver = User.find(-1)
      if ok
        self.perform_approve_post(approver, {})
        self.status=1
        self.save
      end
    end

    after_create do
      if SiteSetting.bypass_watched_words_enabled && SiteSetting.bypass_watched_words_group
        self.auto_approve_for_group
      end
    end
  end
end
