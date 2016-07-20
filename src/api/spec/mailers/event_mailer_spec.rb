require 'rails_helper'

RSpec.describe EventMailer do
  # Needed for X-OBS-URL
  before { Configuration.any_instance.stubs(:obs_url).returns('https://build.example.com') }

  context 'comment mail' do
    let!(:receiver) { create(:confirmed_user) }
    let!(:subscription) { create(:event_subscription_comment_for_project, user: receiver) }
    let!(:comment) { create(:comment_project, body: "Hey @#{receiver.login} how are things?") }
    let(:mail) { EventMailer.event(Event::CommentForProject.last.subscribers, Event::CommentForProject.last).deliver_now }

    it 'gets delivered' do
      expect(ActionMailer::Base.deliveries).to include(mail)
    end
    it 'has subscribers' do
      expect(mail.to).to eq Event::CommentForProject.last.subscribers.map(&:email)
    end
    it 'has a subject' do
      expect(mail.subject).to eq "New comment in project #{comment.project.name} by #{comment.user.login}"
    end
  end
end
