require 'rails_helper'

describe BypassWatchedWords::ActionsController do
  bypass_group_name = "BypassGroup"

  before do
    Jobs.run_immediately!
  end

  fab!(:category) { Fabricate(:category) }
  fab!(:moderator) { Fabricate(:moderator) }
  SiteSetting.bypass_watched_words_enabled=true


  context "creating a post" do
    let!(:topic) { Fabricate(:topic, category: category) }
    let(:reviewable) { Fabricate(:reviewable_queued_post, topic: topic) }
    b_group = Group.find_or_create_by!(name: bypass_group_name)
    g=Group.find_by(name: b_group.name)
    SiteSetting.bypass_watched_words_group = b_group.name

    context "create" do
      it "triggers queued_post_created" do
        event = DiscourseEvent.track(:queued_post_created) { reviewable.save! }
        expect(event).to be_present
        expect(event[:params][0]).to eq(reviewable)
      end

      it "approves post created by group member" do
        member = Fabricate(:user)
        GroupUser.create!(group_id: b_group.id, user_id: member.id)
    
        event = DiscourseEvent.track(:queued_post_created) { reviewable.save! }
        expect(event).to be_present
        expect(event[:params][0]).to eq(reviewable)
      end

      it "returns the appropriate create options" do
        create_options = reviewable.create_options

        expect(create_options[:topic_id]).to eq(topic.id)
        expect(create_options[:raw]).to eq('hello world post contents.')
        expect(create_options[:reply_to_post_number]).to eq(1)
        expect(create_options[:via_email]).to eq(true)
        expect(create_options[:raw_email]).to eq('store_me')
        expect(create_options[:auto_track]).to eq(true)
        expect(create_options[:custom_fields]).to eq('hello' => 'world')
        expect(create_options[:cooking_options]).to eq(cat: 'hat')
        expect(create_options[:cook_method]).to eq(Post.cook_methods[:raw_html])
        expect(create_options[:not_create_option]).to eq(nil)
        expect(create_options[:image_sizes]).to eq("http://foo.bar/image.png" => { "width" => 0, "height" => 222 })
      end
    end

    context "actions" do

      context "approve_post" do
        it 'triggers an extensibility event' do
          event = DiscourseEvent.track(:approved_post) { reviewable.perform(moderator, :approve_post) }
          expect(event).to be_present
          expect(event[:params].first).to eq(reviewable)
        end

        it "creates a post" do
          topic_count, post_count = Topic.count, Post.count
          result = nil

          Jobs.run_immediately!
          event = DiscourseEvent.track(:before_create_notifications_for_users) do
            result = reviewable.perform(moderator, :approve_post)
          end

          expect(result.success?).to eq(true)
          expect(result.created_post).to be_present
          expect(event).to be_present
          expect(result.created_post).to be_valid
          expect(result.created_post.topic).to eq(topic)
          expect(result.created_post.custom_fields['hello']).to eq('world')
          expect(result.created_post_topic).to eq(topic)
          expect(result.created_post.user).to eq(reviewable.created_by)
          expect(reviewable.payload['created_post_id']).to eq(result.created_post.id)

          expect(Topic.count).to eq(topic_count)
          expect(Post.count).to eq(post_count + 1)

          notifications = Notification.where(
            user: reviewable.created_by,
            notification_type: Notification.types[:post_approved]
          )
          expect(notifications).to be_present

          # We can't approve twice
          expect(-> { reviewable.perform(moderator, :approve_post) }).to raise_error(Reviewable::InvalidAction)
        end

        it "skips validations" do
          reviewable.payload['raw'] = 'x'
          result = reviewable.perform(moderator, :approve_post)
          expect(result.created_post).to be_present
        end

        it "Allows autosilenced users to post" do
          newuser = reviewable.created_by
          newuser.update!(trust_level: 0)
          post = Fabricate(:post, user: newuser)
          PostActionCreator.spam(moderator, post)
          Reviewable.set_priorities(high: 1.0)
          SiteSetting.silence_new_user_sensitivity = Reviewable.sensitivity[:low]
          SiteSetting.num_users_to_silence_new_user = 1
          expect(Guardian.new(newuser).can_create_post?(topic)).to eq(false)

          result = reviewable.perform(moderator, :approve_post)
          expect(result.success?).to eq(true)
        end

      end

      context "reject_post" do
        it 'triggers an extensibility event' do
          event = DiscourseEvent.track(:rejected_post) { reviewable.perform(moderator, :reject_post) }
          expect(event).to be_present
          expect(event[:params].first).to eq(reviewable)
        end

        it "doesn't create a post" do
          post_count = Post.count
          result = reviewable.perform(moderator, :reject_post)
          expect(result.success?).to eq(true)
          expect(result.created_post).to be_nil
          expect(Post.count).to eq(post_count)

          # We can't reject twice
          expect(-> { reviewable.perform(moderator, :reject_post) }).to raise_error(Reviewable::InvalidAction)
        end
      end

    end
  end

  context "creating a topic" do
    let(:reviewable) { Fabricate(:reviewable_queued_post_topic, category: category) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_to_create_tag = 0
      SiteSetting.min_trust_level_to_tag_topics = 0
    end

    context "editing" do

      it "is editable and returns the fields" do
        fields = reviewable.editable_for(Guardian.new(moderator))
        expect(fields.has?('category_id')).to eq(true)
        expect(fields.has?('payload.raw')).to eq(true)
        expect(fields.has?('payload.title')).to eq(true)
        expect(fields.has?('payload.tags')).to eq(true)
      end

      it "is editable by a category group reviewer" do
        fields = reviewable.editable_for(Guardian.new(Fabricate(:user)))
        expect(fields.has?('category_id')).to eq(false)
        expect(fields.has?('payload.raw')).to eq(true)
        expect(fields.has?('payload.title')).to eq(true)
        expect(fields.has?('payload.tags')).to eq(true)
      end
    end

    it "returns the appropriate create options for a topic" do
      create_options = reviewable.create_options
      expect(create_options[:category]).to eq(reviewable.category.id)
      expect(create_options[:archetype]).to eq('regular')
    end

    it "creates the post and topic when approved" do
      topic_count, post_count = Topic.count, Post.count
      result = reviewable.perform(moderator, :approve_post)

      expect(result.success?).to eq(true)
      expect(result.created_post).to be_present
      expect(result.created_post).to be_valid
      expect(result.created_post_topic).to be_present
      expect(result.created_post_topic).to be_valid
      expect(reviewable.payload['created_post_id']).to eq(result.created_post.id)
      expect(reviewable.payload['created_topic_id']).to eq(result.created_post_topic.id)

      expect(Topic.count).to eq(topic_count + 1)
      expect(Post.count).to eq(post_count + 1)
    end

    it "creates the post and topic when rejected" do
      topic_count, post_count = Topic.count, Post.count
      result = reviewable.perform(moderator, :reject_post)

      expect(result.success?).to eq(true)
      expect(result.created_post).to be_blank
      expect(result.created_post_topic).to be_blank

      expect(Topic.count).to eq(topic_count)
      expect(Post.count).to eq(post_count)
    end
  end
end
